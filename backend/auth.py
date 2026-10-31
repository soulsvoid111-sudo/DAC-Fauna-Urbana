"""Login do painel administrativo.

A senha nunca fica no código: o servidor guarda só o "hash" dela na variável
FAUNA_ADMIN_SENHA_HASH. Para gerar o hash de uma senha nova:

    python auth.py "minha senha"

Variáveis usadas:
    FAUNA_ADMIN_USUARIO      nome de usuário do admin
    FAUNA_ADMIN_SENHA_HASH   hash gerado pelo comando acima
    FAUNA_SECRET_KEY         texto aleatório e longo para assinar os tokens
"""
import base64
import hashlib
import hmac
import json
import os
import secrets
import sys
import time
from collections import defaultdict
from typing import Annotated

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

ITERACOES = 310_000
DURACAO_TOKEN = 12 * 60 * 60  # 12 horas
MAX_TENTATIVAS = 5
JANELA_BLOQUEIO = 5 * 60  # 5 minutos


def _b64(dados: bytes) -> str:
    return base64.urlsafe_b64encode(dados).rstrip(b"=").decode()


def _de_b64(texto: str) -> bytes:
    return base64.urlsafe_b64decode(texto + "=" * (-len(texto) % 4))


def gerar_hash(senha: str) -> str:
    sal = secrets.token_bytes(16)
    resumo = hashlib.pbkdf2_hmac("sha256", senha.encode(), sal, ITERACOES)
    return f"pbkdf2_sha256${ITERACOES}${_b64(sal)}${_b64(resumo)}"


def senha_confere(senha: str, hash_salvo: str) -> bool:
    try:
        algoritmo, iteracoes, sal, resumo = hash_salvo.split("$")
        if algoritmo != "pbkdf2_sha256":
            return False
        calculado = hashlib.pbkdf2_hmac("sha256", senha.encode(), _de_b64(sal), int(iteracoes))
        return hmac.compare_digest(calculado, _de_b64(resumo))
    except (ValueError, TypeError):
        return False


def _chave() -> bytes:
    chave = os.getenv("FAUNA_SECRET_KEY", "")
    if len(chave) < 16:
        raise HTTPException(status_code=503, detail="Painel administrativo não configurado no servidor.")
    return chave.encode()


def criar_token(usuario: str) -> str:
    corpo = _b64(json.dumps({"u": usuario, "exp": int(time.time()) + DURACAO_TOKEN}).encode())
    assinatura = _b64(hmac.new(_chave(), corpo.encode(), hashlib.sha256).digest())
    return f"{corpo}.{assinatura}"


def ler_token(token: str) -> str | None:
    try:
        corpo, assinatura = token.split(".")
        esperada = _b64(hmac.new(_chave(), corpo.encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(assinatura, esperada):
            return None
        dados = json.loads(_de_b64(corpo))
        if dados["exp"] < time.time():
            return None
        return dados["u"]
    except (ValueError, KeyError, json.JSONDecodeError):
        return None


# Bloqueia por alguns minutos quem errar a senha muitas vezes seguidas.
_falhas: dict[str, list[float]] = defaultdict(list)


def _ip(request: Request) -> str:
    encaminhado = request.headers.get("x-forwarded-for", "")
    return encaminhado.split(",")[0].strip() or (request.client.host if request.client else "?")


def verificar_login(request: Request, usuario: str, senha: str) -> str:
    usuario_certo = os.getenv("FAUNA_ADMIN_USUARIO", "")
    hash_certo = os.getenv("FAUNA_ADMIN_SENHA_HASH", "")
    if not usuario_certo or not hash_certo:
        raise HTTPException(status_code=503, detail="Painel administrativo não configurado no servidor.")

    ip = _ip(request)
    agora = time.time()
    _falhas[ip] = [t for t in _falhas[ip] if agora - t < JANELA_BLOQUEIO]
    if len(_falhas[ip]) >= MAX_TENTATIVAS:
        raise HTTPException(status_code=429, detail="Muitas tentativas. Aguarde alguns minutos e tente de novo.")

    # O hash é sempre calculado, mesmo com usuário errado, para não dar pistas pelo tempo de resposta.
    senha_ok = senha_confere(senha, hash_certo)
    usuario_ok = hmac.compare_digest(usuario.strip().lower(), usuario_certo.strip().lower())
    if not (senha_ok and usuario_ok):
        _falhas[ip].append(agora)
        raise HTTPException(status_code=401, detail="Usuário ou senha incorretos.")

    _falhas.pop(ip, None)
    return usuario_certo


_bearer = HTTPBearer(auto_error=False)


def exigir_admin(credenciais: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)]) -> str:
    usuario = ler_token(credenciais.credentials) if credenciais else None
    if usuario is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Faça login no painel administrativo.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return usuario


Admin = Annotated[str, Depends(exigir_admin)]


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print('Uso: python auth.py "senha"')
        sys.exit(1)
    print(gerar_hash(sys.argv[1]))
