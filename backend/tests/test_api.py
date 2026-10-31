"""Testes da API sem precisar do PostgreSQL: o banco é trocado por uma versão em memória.

Rodar dentro de backend/:  python -m pytest
"""
from datetime import datetime, timezone

import psycopg
import pytest
from fastapi.testclient import TestClient

import main


class RepositorioEmMemoria:
    def __init__(self):
        self.itens: dict[int, dict] = {}
        self.proximo_id = 1

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
        return self.itens.get(id)

    def atualizar(self, id, campo, valor):
        if id not in self.itens:
            return None
        self.itens[id][campo] = valor
        return self.itens[id]

    def resumo(self):
        por_tipo, por_status = {}, {}
        for i in self.itens.values():
            por_tipo[i["tipo"]] = por_tipo.get(i["tipo"], 0) + 1
            por_status[i["status"]] = por_status.get(i["status"], 0) + 1
        return {"total": len(self.itens), "por_tipo": por_tipo, "por_status": por_status}


@pytest.fixture
def client(tmp_path, monkeypatch):
    repo = RepositorioEmMemoria()
    monkeypatch.setattr(main, "PASTA_UPLOADS", tmp_path)
    main.app.dependency_overrides[main.get_repository] = lambda: repo
    yield TestClient(main.app)
    main.app.dependency_overrides.clear()


VALIDA = {"latitude": -20.4697, "longitude": -54.6201, "situacao": "Capivara perto do lago", "tipo": "avistamento"}


def test_cria_e_busca_ocorrencia(client):
    resposta = client.post("/ocorrencias", json={**VALIDA, "especie": "  Capivara "})
    assert resposta.status_code == 201
    criada = resposta.json()
    assert criada["especie"] == "Capivara"
    assert criada["status"] == "aberta"

    assert client.get(f"/ocorrencias/{criada['id']}").json()["situacao"] == "Capivara perto do lago"


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
    assert client.get("/ocorrencias/999").status_code == 404
    assert client.patch("/ocorrencias/999/status", json={"status": "resolvida"}).status_code == 404


def test_filtra_por_tipo_e_status(client):
    client.post("/ocorrencias", json=VALIDA)
    ferido = client.post("/ocorrencias", json={**VALIDA, "tipo": "ferido"}).json()
    client.patch(f"/ocorrencias/{ferido['id']}/status", json={"status": "em_analise"})

    assert [o["id"] for o in client.get("/ocorrencias?tipo=ferido").json()] == [ferido["id"]]
    assert [o["id"] for o in client.get("/ocorrencias?status=em_analise").json()] == [ferido["id"]]
    assert client.get("/ocorrencias/resumo").json()["por_tipo"] == {"avistamento": 1, "ferido": 1}


def test_envia_foto(client, tmp_path):
    criada = client.post("/ocorrencias", json=VALIDA).json()
    resposta = client.post(
        f"/ocorrencias/{criada['id']}/foto",
        files={"foto": ("bicho.jpg", b"\xff\xd8\xff fake jpeg", "image/jpeg")},
    )
    assert resposta.status_code == 200
    assert resposta.json()["foto_url"].startswith(f"/uploads/{criada['id']}_")
    assert len(list(tmp_path.iterdir())) == 1


def test_recusa_arquivo_que_nao_e_imagem(client):
    criada = client.post("/ocorrencias", json=VALIDA).json()
    resposta = client.post(
        f"/ocorrencias/{criada['id']}/foto",
        files={"foto": ("virus.exe", b"MZ...", "application/octet-stream")},
    )
    assert resposta.status_code == 415


def test_banco_fora_do_ar_retorna_503(client):
    def quebra():
        raise psycopg.OperationalError("sem conexão")

    main.app.dependency_overrides[main.get_repository] = quebra
    resposta = client.get("/ocorrencias")
    assert resposta.status_code == 503
    assert "indisponível" in resposta.json()["detail"]
