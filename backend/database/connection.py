import os
import psycopg


def get_connection():
    return psycopg.connect(
        host="localhost",
        dbname="fauna_urbana",
        user="fauna_app",
        password=os.getenv("FAUNA_DB_PASSWORD")
    )