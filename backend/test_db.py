"""Teste rápido de conexão: python test_db.py"""
from database.connection import get_connection

with get_connection() as connection:
    print("Conexão com PostgreSQL realizada com sucesso!")
