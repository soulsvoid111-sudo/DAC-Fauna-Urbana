"""Notificações no celular: inscrição protegida pela chave e envio quando a equipe muda o status."""
import pytest
from fastapi.testclient import TestClient

import main
import push
from tests.test_api import VALIDA, RepositorioEmMemoria, admin_configurado, cabecalho_admin  # noqa: F401

pytestmark = pytest.mark.usefixtures("admin_configurado")


class RepoComPush(RepositorioEmMemoria):
    def __init__(self):
        super().__init__()
        self.push: list[dict] = []

    def salvar_inscricao(self, ocorrencia_id, endpoint, p256dh, auth):
        self.push = [i for i in self.push if not (i["ocorrencia_id"] == ocorrencia_id and i["endpoint"] == endpoint)]
        self.push.append({"ocorrencia_id": ocorrencia_id, "endpoint": endpoint, "p256dh": p256dh, "auth": auth})

    def inscricoes(self, ocorrencia_id):
        return [i for i in self.push if i["ocorrencia_id"] == ocorrencia_id]

    def remover_inscricao(self, endpoint):
        self.push = [i for i in self.push if i["endpoint"] != endpoint]


INSCRICAO = {"endpoint": "https://push.exemplo.com/celular-1", "keys": {"p256dh": "B" * 87, "auth": "a" * 22}}


@pytest.fixture
def ambiente(monkeypatch):
    monkeypatch.setenv("FAUNA_VAPID_PUBLICA", "chave-publica-de-teste")
    monkeypatch.setenv("FAUNA_VAPID_PRIVADA", "chave-privada-de-teste")
    enviados = []
    respostas = {}

    def falso_enviar(inscricao, dados):
        enviados.append((inscricao["endpoint"], dados))
        return respostas.get(inscricao["endpoint"], True)

    monkeypatch.setattr(push, "enviar", falso_enviar)
    repo = RepoComPush()
    main.app.dependency_overrides[main.get_repository] = lambda: repo
    yield TestClient(main.app), repo, enviados, respostas
    main.app.dependency_overrides.clear()


def test_chave_publica_disponivel(ambiente):
    client, *_ = ambiente
    assert client.get("/push/chave-publica").json() == {"chave": "chave-publica-de-teste"}


def test_chave_publica_sem_configuracao(ambiente, monkeypatch):
    client, *_ = ambiente
    monkeypatch.delenv("FAUNA_VAPID_PUBLICA")
    assert client.get("/push/chave-publica").status_code == 503


def test_so_quem_registrou_pede_aviso(ambiente):
    client, repo, *_ = ambiente
    minha = client.post("/ocorrencias", json=VALIDA).json()
    outra = client.post("/ocorrencias", json=VALIDA).json()

    assert client.post(f"/ocorrencias/{minha['id']}/avisar", json={"chave": outra["chave"], "inscricao": INSCRICAO}).status_code == 403
    assert client.post(f"/ocorrencias/{minha['id']}/avisar", json={"chave": minha["chave"], "inscricao": INSCRICAO}).status_code == 204
    # repetir não duplica
    client.post(f"/ocorrencias/{minha['id']}/avisar", json={"chave": minha["chave"], "inscricao": INSCRICAO})
    assert len(repo.inscricoes(minha["id"])) == 1


def test_resolvida_envia_notificacao_ao_celular(ambiente):
    client, _, enviados, _ = ambiente
    minha = client.post("/ocorrencias", json={**VALIDA, "especie": "Quati"}).json()
    client.post(f"/ocorrencias/{minha['id']}/avisar", json={"chave": minha["chave"], "inscricao": INSCRICAO})

    h = cabecalho_admin(client)
    client.patch(f"/ocorrencias/{minha['id']}/status", json={"status": "resolvida"}, headers=h)
    assert len(enviados) == 1
    endpoint, dados = enviados[0]
    assert endpoint == INSCRICAO["endpoint"]
    assert dados["titulo"].startswith("Sua ocorrência foi resolvida")
    assert f"#{minha['id']}" in dados["mensagem"] and "Quati" in dados["mensagem"]
    assert "Obrigado por contribuir" in dados["mensagem"]

    # mesmo status de novo não repete a notificação
    client.patch(f"/ocorrencias/{minha['id']}/status", json={"status": "resolvida"}, headers=h)
    assert len(enviados) == 1


def test_celular_que_desinstalou_e_removido(ambiente):
    client, repo, enviados, respostas = ambiente
    minha = client.post("/ocorrencias", json=VALIDA).json()
    client.post(f"/ocorrencias/{minha['id']}/avisar", json={"chave": minha["chave"], "inscricao": INSCRICAO})
    respostas[INSCRICAO["endpoint"]] = False  # o serviço de push respondeu "não existe mais"

    client.patch(f"/ocorrencias/{minha['id']}/status", json={"status": "em_analise"}, headers=cabecalho_admin(client))
    assert len(enviados) == 1
    assert repo.inscricoes(minha["id"]) == []


def test_voltar_para_aberta_nao_notifica(ambiente):
    client, _, enviados, _ = ambiente
    minha = client.post("/ocorrencias", json=VALIDA).json()
    client.post(f"/ocorrencias/{minha['id']}/avisar", json={"chave": minha["chave"], "inscricao": INSCRICAO})
    h = cabecalho_admin(client)
    client.patch(f"/ocorrencias/{minha['id']}/status", json={"status": "em_analise"}, headers=h)
    client.patch(f"/ocorrencias/{minha['id']}/status", json={"status": "aberta"}, headers=h)
    assert len(enviados) == 1


def test_chaves_vapid_geradas_tem_o_formato_certo():
    publica, privada = push.gerar_chaves()
    assert len(publica) == 87 and len(privada) == 43
