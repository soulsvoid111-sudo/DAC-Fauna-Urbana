"""Testes da API sem precisar do PostgreSQL: o banco é trocado por uma versão em memória.

Rodar dentro de backend/:  python -m pytest
"""
from datetime import datetime, timezone

import psycopg
import pytest
from fastapi.testclient import TestClient

import auth
import main

SENHA_TESTE = "senha-de-teste-123"


class RepositorioEmMemoria:
    def __init__(self):
        self.itens: dict[int, dict] = {}
        self.proximo_id = 1
        self.fotos: dict[int, dict] = {}

    def criar(self, dados):
        item = {
            **dados,
            "id": self.proximo_id,
            "status": "aberta",
            "foto_url": None,
            "data_registro": datetime.now(timezone.utc),
        }
        self.itens[item["id"]] = item
        self.proximo_id += 1
        return item

    def listar(self, tipo=None, status=None, limite=200):
        itens = [i for i in self.itens.values() if (not tipo or i["tipo"] == tipo) and (not status or i["status"] == status)]
        return sorted(itens, key=lambda i: i["data_registro"], reverse=True)[:limite]

    def buscar(self, id):
        item = self.itens.get(id)
        return {k: v for k, v in item.items() if k != "chave_hash"} if item else None

    def chave_hash(self, id):
        return self.itens[id]["chave_hash"] if id in self.itens else None

    def buscar_com_chaves(self, ids):
        return [dict(self.itens[i]) for i in ids if i in self.itens]

    def atualizar(self, id, campo, valor):
        if id not in self.itens:
            return None
        self.itens[id][campo] = valor
        return self.itens[id]

    def salvar_foto(self, id, conteudo, tipo, foto_url):
        self.fotos[id] = {"conteudo": conteudo, "tipo": tipo}
        return self.atualizar(id, "foto_url", foto_url)

    def buscar_foto(self, id):
        return self.fotos.get(id)

    def apagar(self, id):
        self.fotos.pop(id, None)
        return self.itens.pop(id, None) is not None

    def estatisticas(self, dias=30):
        dados = self.resumo()
        urgentes = {"ferido", "em_risco", "em_imovel"}
        dados["urgentes_abertas"] = sum(1 for i in self.itens.values() if i["tipo"] in urgentes and i["status"] == "aberta")
        dados["com_foto"] = sum(1 for i in self.itens.values() if i["foto_url"])
        dados["por_dia"] = [{"dia": "2026-10-30", "total": len(self.itens)}] if self.itens else []
        especies = {}
        for i in self.itens.values():
            if i.get("especie"):
                especies[i["especie"]] = especies.get(i["especie"], 0) + 1
        dados["top_especies"] = [{"especie": e, "total": t} for e, t in sorted(especies.items(), key=lambda x: -x[1])]
        return dados

    def resumo(self):
        por_tipo, por_status = {}, {}
        for i in self.itens.values():
            por_tipo[i["tipo"]] = por_tipo.get(i["tipo"], 0) + 1
            por_status[i["status"]] = por_status.get(i["status"], 0) + 1
        return {"total": len(self.itens), "por_tipo": por_tipo, "por_status": por_status}


@pytest.fixture(autouse=True)
def admin_configurado(monkeypatch):
    monkeypatch.setenv("FAUNA_ADMIN_USUARIO", "DAC@FAUNA")
    monkeypatch.setenv("FAUNA_ADMIN_SENHA_HASH", auth.gerar_hash(SENHA_TESTE))
    monkeypatch.setenv("FAUNA_SECRET_KEY", "chave-secreta-so-para-os-testes")
    auth._falhas.clear()


def login(client, usuario="DAC@FAUNA", senha=SENHA_TESTE):
    return client.post("/admin/login", json={"usuario": usuario, "senha": senha})


def cabecalho_admin(client):
    return {"Authorization": f"Bearer {login(client).json()['token']}"}


@pytest.fixture
def client():
    repo = RepositorioEmMemoria()
    main.app.dependency_overrides[main.get_repository] = lambda: repo
    yield TestClient(main.app)
    main.app.dependency_overrides.clear()


VALIDA = {"latitude": -20.4697, "longitude": -54.6201, "situacao": "Capivara perto do lago", "tipo": "avistamento"}


def test_cria_e_admin_consulta(client):
    resposta = client.post("/ocorrencias", json={**VALIDA, "especie": "  Capivara "})
    assert resposta.status_code == 201
    criada = resposta.json()
    assert criada["especie"] == "Capivara"
    assert criada["status"] == "aberta"
    assert len(criada["chave"]) >= 20, "quem registra recebe a chave de acompanhamento"
    assert "chave_hash" not in criada

    h = cabecalho_admin(client)
    assert client.get(f"/ocorrencias/{criada['id']}", headers=h).json()["situacao"] == "Capivara perto do lago"


def test_tipo_padrao_e_avistamento(client):
    dados = {k: v for k, v in VALIDA.items() if k != "tipo"}
    assert client.post("/ocorrencias", json=dados).json()["tipo"] == "avistamento"


@pytest.mark.parametrize(
    "alteracao",
    [
        {"latitude": 95},
        {"longitude": -200},
        {"situacao": "   "},
        {"situacao": "x" * 501},
        {"tipo": "dinossauro"},
    ],
)
def test_rejeita_dados_invalidos(client, alteracao):
    assert client.post("/ocorrencias", json={**VALIDA, **alteracao}).status_code == 422


def test_ocorrencia_inexistente_retorna_404(client):
    assert client.get("/ocorrencias/999", headers=cabecalho_admin(client)).status_code == 404
    assert (
        client.patch("/ocorrencias/999/status", json={"status": "resolvida"}, headers=cabecalho_admin(client)).status_code
        == 404
    )


def test_filtra_por_tipo_e_status(client):
    h = cabecalho_admin(client)
    client.post("/ocorrencias", json=VALIDA)
    ferido = client.post("/ocorrencias", json={**VALIDA, "tipo": "ferido"}).json()
    client.patch(f"/ocorrencias/{ferido['id']}/status", json={"status": "em_analise"}, headers=h)

    assert [o["id"] for o in client.get("/ocorrencias?tipo=ferido", headers=h).json()] == [ferido["id"]]
    assert [o["id"] for o in client.get("/ocorrencias?status=em_analise", headers=h).json()] == [ferido["id"]]
    assert client.get("/ocorrencias/resumo", headers=h).json()["por_tipo"] == {"avistamento": 1, "ferido": 1}


def test_envia_e_baixa_foto(client):
    criada = client.post("/ocorrencias", json=VALIDA).json()
    chave = criada["chave"]
    assert client.get(f"/ocorrencias/{criada['id']}/foto", params={"chave": chave}).status_code == 404

    jpeg = b"\xff\xd8\xff fake jpeg"
    resposta = client.post(
        f"/ocorrencias/{criada['id']}/foto",
        files={"foto": ("bicho.jpg", jpeg, "image/jpeg")},
        data={"chave": chave},
    )
    assert resposta.status_code == 200
    foto_url = resposta.json()["foto_url"]
    assert foto_url.startswith(f"/ocorrencias/{criada['id']}/foto?v=")

    baixada = client.get(foto_url, params={"chave": chave})
    assert baixada.status_code == 200
    assert baixada.headers["content-type"] == "image/jpeg"
    assert baixada.content == jpeg

    token = login(client).json()["token"]
    assert client.get(foto_url, params={"token": token}).content == jpeg, "a equipe também vê a foto"


def test_recusa_arquivo_que_nao_e_imagem(client):
    criada = client.post("/ocorrencias", json=VALIDA).json()
    resposta = client.post(
        f"/ocorrencias/{criada['id']}/foto",
        files={"foto": ("virus.exe", b"MZ...", "application/octet-stream")},
        data={"chave": criada["chave"]},
    )
    assert resposta.status_code == 415


def test_banco_fora_do_ar_retorna_503(client):
    def quebra():
        raise psycopg.OperationalError("sem conexão")

    main.app.dependency_overrides[main.get_repository] = quebra
    resposta = client.post("/ocorrencias", json=VALIDA)
    assert resposta.status_code == 503
    assert "indisponível" in resposta.json()["detail"]


# ---------- Painel administrativo ----------


def test_login_certo_devolve_token(client):
    resposta = login(client, usuario="dac@fauna")  # usuário não diferencia maiúsculas
    assert resposta.status_code == 200
    assert resposta.json()["usuario"] == "DAC@FAUNA"
    assert client.get("/admin/me", headers={"Authorization": f"Bearer {resposta.json()['token']}"}).status_code == 200


@pytest.mark.parametrize("usuario,senha", [("DAC@FAUNA", "errada"), ("outro", SENHA_TESTE), ("DAC@FAUNA", "")])
def test_login_errado_e_recusado(client, usuario, senha):
    assert login(client, usuario, senha).status_code in (401, 422)


def test_bloqueia_apos_muitas_tentativas(client):
    for _ in range(auth.MAX_TENTATIVAS):
        assert login(client, senha="errada").status_code == 401
    assert login(client).status_code == 429  # nem a senha certa entra durante o bloqueio


def test_rotas_de_admin_exigem_login(client):
    criada = client.post("/ocorrencias", json=VALIDA).json()
    assert client.patch(f"/ocorrencias/{criada['id']}/status", json={"status": "resolvida"}).status_code == 401
    assert client.delete(f"/ocorrencias/{criada['id']}").status_code == 401
    assert client.get("/admin/estatisticas").status_code == 401
    falso = {"Authorization": "Bearer abc.def"}
    assert client.get("/admin/estatisticas", headers=falso).status_code == 401


def test_token_expirado_e_recusado(client, monkeypatch):
    token = login(client).json()["token"]
    monkeypatch.setattr(auth.time, "time", lambda: 10**12)
    assert client.get("/admin/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_admin_muda_status_apaga_e_ve_estatisticas(client):
    h = cabecalho_admin(client)
    a = client.post("/ocorrencias", json={**VALIDA, "tipo": "ferido", "especie": "Quati"}).json()
    b = client.post("/ocorrencias", json=VALIDA).json()

    assert client.patch(f"/ocorrencias/{a['id']}/status", json={"status": "resolvida"}, headers=h).json()["status"] == "resolvida"
    est = client.get("/admin/estatisticas", headers=h).json()
    assert est["total"] == 2 and est["urgentes_abertas"] == 0
    assert est["top_especies"] == [{"especie": "Quati", "total": 1}]

    assert client.delete(f"/ocorrencias/{b['id']}", headers=h).status_code == 204
    assert client.get(f"/ocorrencias/{b['id']}", headers=h).status_code == 404
    assert client.delete(f"/ocorrencias/{b['id']}", headers=h).status_code == 404


def test_sem_configuracao_o_painel_fica_desligado(client, monkeypatch):
    monkeypatch.delenv("FAUNA_ADMIN_SENHA_HASH")
    assert login(client).status_code == 503


def test_hash_de_senha():
    h = auth.gerar_hash("abc")
    assert auth.senha_confere("abc", h)
    assert not auth.senha_confere("abd", h)
    assert not auth.senha_confere("abc", "lixo")


# ---------- Privacidade: cada pessoa só vê o que registrou ----------


def test_visitante_nao_ve_ocorrencias_de_ninguem(client):
    client.post("/ocorrencias", json=VALIDA)
    assert client.get("/ocorrencias").status_code == 401
    assert client.get("/ocorrencias/1").status_code == 401
    assert client.get("/ocorrencias/resumo").status_code == 401


def test_acompanha_so_os_proprios_registros(client):
    minha = client.post("/ocorrencias", json=VALIDA).json()
    de_outra_pessoa = client.post("/ocorrencias", json={**VALIDA, "situacao": "Registro de outra pessoa"}).json()

    resposta = client.post(
        "/ocorrencias/acompanhar",
        json={"itens": [
            {"id": minha["id"], "chave": minha["chave"]},
            {"id": de_outra_pessoa["id"], "chave": "chave-chutada-errada-123"},
            {"id": 999, "chave": "nao-existe-1234567"},
        ]},
    )
    assert resposta.status_code == 200
    assert [o["id"] for o in resposta.json()] == [minha["id"]]
    assert "chave_hash" not in resposta.json()[0]


def test_acompanhamento_mostra_status_atualizado_pela_equipe(client):
    minha = client.post("/ocorrencias", json={**VALIDA, "tipo": "ferido"}).json()
    client.patch(f"/ocorrencias/{minha['id']}/status", json={"status": "resolvida"}, headers=cabecalho_admin(client))
    itens = client.post("/ocorrencias/acompanhar", json={"itens": [{"id": minha["id"], "chave": minha["chave"]}]}).json()
    assert itens[0]["status"] == "resolvida"


def test_foto_de_outra_pessoa_e_bloqueada(client):
    a = client.post("/ocorrencias", json=VALIDA).json()
    b = client.post("/ocorrencias", json=VALIDA).json()
    jpeg = b"\xff\xd8\xff"
    # B não consegue colocar foto no registro de A
    assert client.post(f"/ocorrencias/{a['id']}/foto", files={"foto": ("x.jpg", jpeg, "image/jpeg")},
                       data={"chave": b["chave"]}).status_code == 403
    client.post(f"/ocorrencias/{a['id']}/foto", files={"foto": ("x.jpg", jpeg, "image/jpeg")}, data={"chave": a["chave"]})
    # ...nem ver a foto de A
    assert client.get(f"/ocorrencias/{a['id']}/foto", params={"chave": b["chave"]}).status_code == 403
    assert client.get(f"/ocorrencias/{a['id']}/foto").status_code == 403
    assert client.get(f"/ocorrencias/{a['id']}/foto", params={"token": "falso.falso"}).status_code == 403
