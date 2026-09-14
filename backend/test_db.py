import psycopg
import os

connection = psycopg.connect(
    host="localhost",
    dbname="fauna_urbana",
    user="fauna_app",
    password=os.getenv("FAUNA_DB_PASSWORD")
)

print("Conexão com PostgreSQL realizada com sucesso!")

connection.close()

