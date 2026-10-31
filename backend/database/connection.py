import os
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

try:
    # Lê o arquivo backend/.env, se existir (veja .env.example).
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

SCHEMA = Path(__file__).parent / "schema.sql"


def get_connection():
    # Em produção (Neon/Render) basta DATABASE_URL, ex.:
    # postgresql://usuario:senha@host/banco?sslmode=require
    url = os.getenv("DATABASE_URL")
    if url:
        return psycopg.connect(url, connect_timeout=10, row_factory=dict_row)

    return psycopg.connect(
        host=os.getenv("FAUNA_DB_HOST", "localhost"),
        port=int(os.getenv("FAUNA_DB_PORT", "5432")),
        dbname=os.getenv("FAUNA_DB_NAME", "fauna_urbana"),
        user=os.getenv("FAUNA_DB_USER", "fauna_app"),
        password=os.getenv("FAUNA_DB_PASSWORD"),
        connect_timeout=5,
        row_factory=dict_row,
    )


def aplicar_schema():
    """Cria ou atualiza as tabelas. Pode rodar várias vezes sem apagar dados."""
    with get_connection() as connection:
        connection.execute(SCHEMA.read_text(encoding="utf-8"))
