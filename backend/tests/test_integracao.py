"""Teste de ponta a ponta contra um PostgreSQL de verdade.

Só roda quando DATABASE_URL (ou FAUNA_DB_PASSWORD) está definida:
    DATABASE_URL=postgresql://... python -m pytest tests/test_integracao.py
Os registros criados aqui são apagados no final.
"""
import os

import pytest
from fastapi.testclient import TestClient

import auth
import main
from database.connection import get_connection

pytestmark = pytest.mark.skipif(
    not (os.getenv("DATABASE_URL") or os.getenv("FAUNA_DB_PASSWORD")),
    reason="sem banco configurado",
)


@pytest.fixture
def client():
    main.app.dependency_overrides.clear()
    criados: list[int] = []
    with TestClient(main.app) as c:  # "with" roda a criação das tabelas
        c.criados = criados
        yield c
    if criados:
        with get_connection() as conn:
            conn.execute("DELETE FROM ocorrencias WHERE id = ANY(%s)", (criados,))


def test_fluxo_completo_no_banco(client, monkeypatch):
    monkeypatch.setenv("FAUNA_ADMIN_USUARIO", "teste")
    monkeypatch.setenv("FAUNA_ADMIN_SENHA_HASH", auth.gerar_hash("teste-senha"))
    monkeypatch.setenv("FAUNA_SECRET_KEY", "chave-de-teste-integracao")

    assert client.get("/db-test").json()["database"] == "conectado"

    resposta = client.post(
        "/ocorrencias",
        json={
            "latitude": -20.4697,
            "longitude": -54.6201,
            "situacao": "Teste automático de integração",
            "tipo": "ferido",
            "especie": "Quati",
        },
    )
    assert resposta.status_code == 201, resposta.text
    criada = resposta.json()
    client.criados.append(criada["id"])
    assert criada["status"] == "aberta"

    foto = b"\x89PNG\r\n\x1a\n teste"
    resposta = client.post(f"/ocorrencias/{criada['id']}/foto", files={"foto": ("t.png", foto, "image/png")})
    assert resposta.status_code == 200, resposta.text
    baixada = client.get(resposta.json()["foto_url"])
    assert baixada.status_code == 200 and baixada.content == foto

    # Mudar status exige admin; aqui só conferimos que a rota está protegida.
    assert client.patch(f"/ocorrencias/{criada['id']}/status", json={"status": "resolvida"}).status_code == 401
    with get_connection() as conn:
        conn.execute("UPDATE ocorrencias SET status = 'resolvida' WHERE id = %s", (criada["id"],))

    ids = [o["id"] for o in client.get("/ocorrencias?tipo=ferido&status=resolvida").json()]
    assert criada["id"] in ids
    assert client.get("/ocorrencias/resumo").json()["total"] >= 1

    token = client.post("/admin/login", json={"usuario": "teste", "senha": "teste-senha"}).json()["token"]
    h = {"Authorization": f"Bearer {token}"}
    est = client.get("/admin/estatisticas", headers=h)
    assert est.status_code == 200, est.text
    assert est.json()["total"] >= 1 and len(est.json()["por_dia"]) >= 1
    assert client.delete(f"/ocorrencias/{criada['id']}", headers=h).status_code == 204
    client.criados.remove(criada["id"])
