import psycopg

connection = psycopg.connect(
    "host=localhost dbname=fauna_urbana user=fauna_app password=fauna_dev_2026"
)

print("Conexão com PostgreSQL realizada com sucesso!")

connection.close()