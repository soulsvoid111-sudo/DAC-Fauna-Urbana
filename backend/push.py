"""Notificações no celular (Web Push), mesmo com o app fechado.

O servidor assina cada envio com um par de chaves VAPID:
    FAUNA_VAPID_PUBLICA   chave pública (vai para o app)
    FAUNA_VAPID_PRIVADA   chave privada (só no servidor; nunca no código)

Para gerar um par novo:  python push.py
"""
import base64
import json
import logging
import os

log = logging.getLogger("fauna.push")

CONTATO = "https://fauna-urbana.onrender.com"


def chave_publica() -> str | None:
    return os.getenv("FAUNA_VAPID_PUBLICA") or None


def configurado() -> bool:
    return bool(os.getenv("FAUNA_VAPID_PUBLICA") and os.getenv("FAUNA_VAPID_PRIVADA"))


def mensagem_status(ocorrencia: dict) -> dict | None:
    """Texto da notificação para cada mudança de situação (None = não avisa)."""
    n = f"#{ocorrencia['id']}"
    nome = ocorrencia.get("especie") or "sua ocorrência"
    textos = {
        "resolvida": (
            "Sua ocorrência foi resolvida! 💚",
            f"A ocorrência {n} ({nome}) foi resolvida pela equipe SOFUR. "
            "Obrigado por contribuir com a proteção da fauna urbana!",
        ),
        "em_analise": (
            "A equipe está cuidando da sua ocorrência",
            f"A ocorrência {n} está em análise e os responsáveis estão sendo acionados.",
        ),
        "descartada": (
            "Sua ocorrência foi analisada",
            f"A equipe analisou a ocorrência {n} e não foi necessária uma ação. Obrigado por avisar!",
        ),
    }
    if ocorrencia["status"] not in textos:
        return None
    titulo, corpo = textos[ocorrencia["status"]]
    return {"titulo": titulo, "mensagem": corpo, "url": "/", "tag": f"ocorrencia-{ocorrencia['id']}"}


def enviar(inscricao: dict, dados: dict) -> bool:
    """Envia uma notificação. Devolve False se a inscrição não vale mais (celular desinstalou ou bloqueou)."""
    from pywebpush import WebPushException, webpush  # importado só quando usado

    try:
        webpush(
            subscription_info={
                "endpoint": inscricao["endpoint"],
                "keys": {"p256dh": inscricao["p256dh"], "auth": inscricao["auth"]},
            },
            data=json.dumps(dados, ensure_ascii=False),
            vapid_private_key=os.environ["FAUNA_VAPID_PRIVADA"],
            vapid_claims={"sub": CONTATO},
            ttl=24 * 60 * 60,
        )
        return True
    except WebPushException as erro:
        status = getattr(erro.response, "status_code", None)
        if status in (404, 410):
            return False
        log.warning("Falha ao enviar notificação: %s", erro)
        return True
    except Exception as erro:  # nunca derruba a mudança de status por causa da notificação
        log.warning("Falha ao enviar notificação: %s", erro)
        return True


def gerar_chaves() -> tuple[str, str]:
    """Par de chaves VAPID no formato que navegadores e o pywebpush esperam (base64url)."""
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import ec

    privada = ec.generate_private_key(ec.SECP256R1())
    numero = privada.private_numbers().private_value.to_bytes(32, "big")
    publica = privada.public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint
    )

    def b64(dados: bytes) -> str:
        return base64.urlsafe_b64encode(dados).rstrip(b"=").decode()

    return b64(publica), b64(numero)


if __name__ == "__main__":
    publica, privada = gerar_chaves()
    print(f"FAUNA_VAPID_PUBLICA={publica}")
    print(f"FAUNA_VAPID_PRIVADA={privada}")
