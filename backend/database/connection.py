import os

import psycopg
from psycopg.rows import dict_row

try:
    # Lê o arquivo backend/.env, se existir (veja .env.example).
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass


def get_connection():
    return psycopg.connect(
        host=os.getenv("FAUNA_DB_HOST", "localhost"),
        port=int(os.getenv("FAUNA_DB_PORT", "5432")),
        dbname=os.getenv("FAUNA_DB_NAME", "fauna_urbana"),
        user=os.getenv("FAUNA_DB_USER", "fauna_app"),
        password=os.getenv("FAUNA_DB_PASSWORD"),
        connect_timeout=5,
        row_factory=dict_row,
    )
