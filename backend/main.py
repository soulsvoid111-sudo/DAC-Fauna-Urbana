import logging
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime
from enum import Enum
from typing import Annotated

import psycopg
from fastapi import Depends, FastAPI, File, HTTPException, Query, Request, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel, Field, field_validator

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
    allow_methods=["GET", "POST", "PATCH"],
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


class StatusUpdate(BaseModel):
    status: StatusOcorrencia


class Resumo(BaseModel):
    total: int
    por_tipo: dict[str, int]
    por_status: dict[str, int]


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

@app.get("/")
def root():
    return {"message": "Fauna Urbana API funcionando!"}


@app.get("/db-test")
def db_test():
    with get_connection() as connection, connection.cursor() as cursor:
        cursor.execute("SELECT 1 AS resultado")
        return {"database": "conectado", "resultado": cursor.fetchone()["resultado"]}


@app.post("/ocorrencias", response_model=Ocorrencia, status_code=status.HTTP_201_CREATED)
def criar_ocorrencia(ocorrencia: OcorrenciaCreate, repo: Repo):
    return repo.criar(ocorrencia.model_dump(mode="json"))


@app.get("/ocorrencias", response_model=list[Ocorrencia])
def listar_ocorrencias(
    repo: Repo,
    tipo: TipoOcorrencia | None = None,
    status_filtro: Annotated[StatusOcorrencia | None, Query(alias="status")] = None,
    limite: Annotated[int, Query(ge=1, le=1000)] = 200,
):
    return repo.listar(
        tipo=tipo.value if tipo else None,
        status=status_filtro.value if status_filtro else None,
        limite=limite,
    )


@app.get("/ocorrencias/resumo", response_model=Resumo)
def resumo_ocorrencias(repo: Repo):
    return repo.resumo()


@app.get("/ocorrencias/{id}", response_model=Ocorrencia)
def buscar_ocorrencia(id: int, repo: Repo):
    return _ou_404(repo.buscar(id))


@app.patch("/ocorrencias/{id}/status", response_model=Ocorrencia)
def atualizar_status(id: int, dados: StatusUpdate, repo: Repo):
    return _ou_404(repo.atualizar(id, "status", dados.status.value))


@app.post("/ocorrencias/{id}/foto", response_model=Ocorrencia)
async def enviar_foto(id: int, repo: Repo, foto: UploadFile = File(...)):
    _ou_404(repo.buscar(id))

    if foto.content_type not in TIPOS_FOTO:
        raise HTTPException(status_code=415, detail="Envie uma imagem JPG, PNG ou WEBP.")

    conteudo = await foto.read(TAMANHO_MAXIMO_FOTO + 1)
    if len(conteudo) > TAMANHO_MAXIMO_FOTO:
        raise HTTPException(status_code=413, detail="A foto deve ter no máximo 8 MB.")

    # O "v" muda a cada envio para o app não mostrar a foto antiga do cache.
    foto_url = f"/ocorrencias/{id}/foto?v={uuid.uuid4().hex[:8]}"
    return repo.salvar_foto(id, conteudo, foto.content_type, foto_url)


@app.get("/ocorrencias/{id}/foto")
def baixar_foto(id: int, repo: Repo):
    foto = repo.buscar_foto(id)
    if foto is None:
        raise HTTPException(status_code=404, detail="Esta ocorrência não tem foto")
    return Response(
        content=bytes(foto["conteudo"]),
        media_type=foto["tipo"],
        headers={"Cache-Control": "public, max-age=86400"},
    )
