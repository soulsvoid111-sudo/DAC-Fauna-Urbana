import hashlib
import hmac
import logging
import os
import secrets
import uuid
from contextlib import asynccontextmanager
from datetime import datetime
from enum import Enum
from typing import Annotated

import psycopg
from fastapi import BackgroundTasks, Depends, FastAPI, File, Form, HTTPException, Query, Request, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel, Field, field_validator

import push
from auth import Admin, criar_token, ler_token, verificar_login
from database.connection import aplicar_schema, get_connection
from repository import OcorrenciaRepository

log = logging.getLogger("fauna")
TAMANHO_MAXIMO_FOTO = 8 * 1024 * 1024  # 8 MB
TIPOS_FOTO = {"image/jpeg", "image/png", "image/webp"}


@asynccontextmanager
async def ciclo_de_vida(_: FastAPI):
    # Cria/atualiza as tabelas ao iniciar. Desligue com FAUNA_AUTO_SCHEMA=0.
    if os.getenv("FAUNA_AUTO_SCHEMA", "1") != "0":
        try:
            aplicar_schema()
            log.warning("Tabelas do banco verificadas.")
        except Exception as erro:  # a API sobe mesmo sem banco; as rotas respondem 503
            log.error("Não foi possível preparar o banco: %s", erro)
    yield


app = FastAPI(
    title="Fauna Urbana API",
    description="Registro e acompanhamento de ocorrências de fauna urbana.",
    version="0.3.0",
    lifespan=ciclo_de_vida,
)

# Origens liberadas separadas por vírgula. Ex.: FAUNA_CORS_ORIGINS=http://localhost:5000
origens = [o.strip() for o in os.getenv("FAUNA_CORS_ORIGINS", "*").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origens,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["*"],
)


# ---------- Modelos ----------

class TipoOcorrencia(str, Enum):
    avistamento = "avistamento"
    ferido = "ferido"
    atropelado = "atropelado"
    em_risco = "em_risco"
    em_imovel = "em_imovel"


class StatusOcorrencia(str, Enum):
    aberta = "aberta"
    em_analise = "em_analise"
    resolvida = "resolvida"
    descartada = "descartada"


class OcorrenciaCreate(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    situacao: str = Field(min_length=3, max_length=500)
    tipo: TipoOcorrencia = TipoOcorrencia.avistamento
    especie: str | None = Field(default=None, max_length=100)

    @field_validator("situacao")
    @classmethod
    def limpar_situacao(cls, valor: str) -> str:
        valor = valor.strip()
        if len(valor) < 3:
            raise ValueError("Descreva a ocorrência com pelo menos 3 caracteres.")
        return valor

    @field_validator("especie")
    @classmethod
    def limpar_especie(cls, valor: str | None) -> str | None:
        valor = (valor or "").strip()
        return valor or None


class Ocorrencia(BaseModel):
    id: int
    latitude: float
    longitude: float
    situacao: str
    tipo: TipoOcorrencia
    especie: str | None
    status: StatusOcorrencia
    foto_url: str | None
    data_registro: datetime


class OcorrenciaCriada(Ocorrencia):
    # Entregue uma única vez, para o celular de quem registrou. O servidor guarda só o hash.
    chave: str


class ItemAcompanhamento(BaseModel):
    id: int
    chave: str = Field(min_length=10, max_length=100)


class Acompanhamento(BaseModel):
    itens: list[ItemAcompanhamento] = Field(max_length=200)


class ChavesPush(BaseModel):
    p256dh: str = Field(min_length=10, max_length=200)
    auth: str = Field(min_length=10, max_length=100)


class InscricaoPush(BaseModel):
    endpoint: str = Field(min_length=10, max_length=1000)
    keys: ChavesPush


class PedidoAviso(BaseModel):
    chave: str = Field(min_length=10, max_length=100)
    inscricao: InscricaoPush


class StatusUpdate(BaseModel):
    status: StatusOcorrencia


class Resumo(BaseModel):
    total: int
    por_tipo: dict[str, int]
    por_status: dict[str, int]


class ContagemDia(BaseModel):
    dia: str
    total: int


class ContagemEspecie(BaseModel):
    especie: str
    total: int


class Estatisticas(Resumo):
    urgentes_abertas: int
    com_foto: int
    por_dia: list[ContagemDia]
    top_especies: list[ContagemEspecie]


class LoginEntrada(BaseModel):
    usuario: str = Field(min_length=1, max_length=100)
    senha: str = Field(min_length=1, max_length=200)


class LoginSaida(BaseModel):
    token: str
    usuario: str


# ---------- Dependências e erros ----------

def get_repository():
    connection = get_connection()
    try:
        yield OcorrenciaRepository(connection)
    finally:
        connection.close()


Repo = Annotated[OcorrenciaRepository, Depends(get_repository)]


@app.exception_handler(psycopg.OperationalError)
def banco_indisponivel(_: Request, __: psycopg.OperationalError):
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"detail": "Banco de dados indisponível. Tente novamente em instantes."},
    )


def _ou_404(ocorrencia: dict | None) -> dict:
    if ocorrencia is None:
        raise HTTPException(status_code=404, detail="Ocorrência não encontrada")
    return ocorrencia


# ---------- Rotas ----------
# Quem registra só envia e acompanha os PRÓPRIOS registros (com a chave guardada no celular).
# Ver todas as ocorrências, mudar status e apagar é só para a equipe (login do painel).


def _hash(chave: str) -> str:
    return hashlib.sha256(chave.encode()).hexdigest()


def _chave_confere(chave: str | None, chave_hash: str | None) -> bool:
    return bool(chave and chave_hash) and hmac.compare_digest(_hash(chave), chave_hash)


@app.get("/")
def root():
    return {"message": "SOFUR API funcionando!"}


@app.get("/db-test")
def db_test():
    with get_connection() as connection, connection.cursor() as cursor:
        cursor.execute("SELECT 1 AS resultado")
        return {"database": "conectado", "resultado": cursor.fetchone()["resultado"]}


@app.post("/ocorrencias", response_model=OcorrenciaCriada, status_code=status.HTTP_201_CREATED)
def criar_ocorrencia(ocorrencia: OcorrenciaCreate, repo: Repo):
    chave = secrets.token_urlsafe(24)
    criada = repo.criar({**ocorrencia.model_dump(mode="json"), "chave_hash": _hash(chave)})
    return {**criada, "chave": chave}


@app.post("/ocorrencias/acompanhar", response_model=list[Ocorrencia])
def acompanhar(dados: Acompanhamento, repo: Repo):
    """Situação atual dos registros de quem tem as chaves (tela "Meus registros")."""
    chaves = {item.id: item.chave for item in dados.itens}
    return [o for o in repo.buscar_com_chaves(list(chaves)) if _chave_confere(chaves.get(o["id"]), o["chave_hash"])]


@app.get("/ocorrencias", response_model=list[Ocorrencia])
def listar_ocorrencias(
    repo: Repo,
    _: Admin,
    tipo: TipoOcorrencia | None = None,
    status_filtro: Annotated[StatusOcorrencia | None, Query(alias="status")] = None,
    limite: Annotated[int, Query(ge=1, le=1000)] = 500,
):
    return repo.listar(
        tipo=tipo.value if tipo else None,
        status=status_filtro.value if status_filtro else None,
        limite=limite,
    )


@app.get("/ocorrencias/resumo", response_model=Resumo)
def resumo_ocorrencias(repo: Repo, _: Admin):
    return repo.resumo()


@app.get("/ocorrencias/{id}", response_model=Ocorrencia)
def buscar_ocorrencia(id: int, repo: Repo, _: Admin):
    return _ou_404(repo.buscar(id))


@app.patch("/ocorrencias/{id}/status", response_model=Ocorrencia)
def atualizar_status(id: int, dados: StatusUpdate, repo: Repo, _: Admin, tarefas: BackgroundTasks):
    anterior = _ou_404(repo.buscar(id))
    atualizada = _ou_404(repo.atualizar(id, "status", dados.status.value))
    if anterior["status"] != atualizada["status"]:
        tarefas.add_task(_avisar_celulares, repo, atualizada)
    return atualizada


def _avisar_celulares(repo: OcorrenciaRepository, ocorrencia: dict):
    """Manda a notificação para os celulares inscritos nesta ocorrência (depois de responder ao painel)."""
    dados = push.mensagem_status(ocorrencia)
    if dados is None or not push.configurado():
        return
    for inscricao in repo.inscricoes(ocorrencia["id"]):
        if not push.enviar(inscricao, dados):
            repo.remover_inscricao(inscricao["endpoint"])


@app.get("/push/chave-publica")
def chave_publica_push():
    """O app precisa desta chave para inscrever o celular nas notificações."""
    chave = push.chave_publica()
    if chave is None:
        raise HTTPException(status_code=503, detail="Notificações ainda não configuradas no servidor.")
    return {"chave": chave}


@app.post("/ocorrencias/{id}/avisar", status_code=status.HTTP_204_NO_CONTENT)
def pedir_aviso(id: int, dados: PedidoAviso, repo: Repo):
    """Quem registrou pede para ser avisado no celular quando a situação mudar."""
    _ou_404(repo.buscar(id))
    if not _chave_confere(dados.chave, repo.chave_hash(id)):
        raise HTTPException(status_code=403, detail="Só quem registrou pode pedir aviso desta ocorrência.")
    if not dados.inscricao.endpoint.startswith("https://"):
        raise HTTPException(status_code=422, detail="Endereço de notificação inválido.")
    repo.salvar_inscricao(id, dados.inscricao.endpoint, dados.inscricao.keys.p256dh, dados.inscricao.keys.auth)


@app.delete("/ocorrencias/{id}", status_code=status.HTTP_204_NO_CONTENT)
def apagar_ocorrencia(id: int, repo: Repo, _: Admin):
    if not repo.apagar(id):
        raise HTTPException(status_code=404, detail="Ocorrência não encontrada")


# ---------- Painel administrativo ----------

@app.post("/admin/login", response_model=LoginSaida)
def login(dados: LoginEntrada, request: Request):
    usuario = verificar_login(request, dados.usuario, dados.senha)
    return {"token": criar_token(usuario), "usuario": usuario}


@app.get("/admin/me")
def quem_sou(usuario: Admin):
    return {"usuario": usuario}


@app.get("/admin/estatisticas", response_model=Estatisticas)
def estatisticas(repo: Repo, _: Admin, dias: Annotated[int, Query(ge=1, le=365)] = 30):
    return repo.estatisticas(dias)


# ---------- Fotos ----------

@app.post("/ocorrencias/{id}/foto", response_model=Ocorrencia)
async def enviar_foto(id: int, repo: Repo, foto: UploadFile = File(...), chave: str = Form(...)):
    _ou_404(repo.buscar(id))
    if not _chave_confere(chave, repo.chave_hash(id)):
        raise HTTPException(status_code=403, detail="Só quem registrou a ocorrência pode enviar a foto.")

    if foto.content_type not in TIPOS_FOTO:
        raise HTTPException(status_code=415, detail="Envie uma imagem JPG, PNG ou WEBP.")

    conteudo = await foto.read(TAMANHO_MAXIMO_FOTO + 1)
    if len(conteudo) > TAMANHO_MAXIMO_FOTO:
        raise HTTPException(status_code=413, detail="A foto deve ter no máximo 8 MB.")

    # O "v" muda a cada envio para o app não mostrar a foto antiga do cache.
    foto_url = f"/ocorrencias/{id}/foto?v={uuid.uuid4().hex[:8]}"
    return repo.salvar_foto(id, conteudo, foto.content_type, foto_url)


@app.get("/ocorrencias/{id}/foto")
def baixar_foto(id: int, repo: Repo, chave: str | None = None, token: str | None = None):
    """A foto só abre para quem registrou (chave) ou para a equipe (token do painel)."""
    admin = bool(token) and ler_token(token) is not None
    if not admin and not _chave_confere(chave, repo.chave_hash(id)):
        raise HTTPException(status_code=403, detail="Sem permissão para ver esta foto.")
    foto = repo.buscar_foto(id)
    if foto is None:
        raise HTTPException(status_code=404, detail="Esta ocorrência não tem foto")
    return Response(
        content=bytes(foto["conteudo"]),
        media_type=foto["tipo"],
        headers={"Cache-Control": "private, max-age=86400"},
    )
