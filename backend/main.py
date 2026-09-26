from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from database.connection import get_connection

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class OcorrenciaCreate(BaseModel):
    latitude: float
    longitude: float
    situacao: str


@app.get("/")
def root():
    return {"message": "Fauna Urbana API funcionando!"}


@app.get("/db-test")
def db_test():
    connection = get_connection()

    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()

        return {
            "database": "conectado",
            "resultado": result[0]
        }

    finally:
        connection.close()


@app.post("/ocorrencias")
def criar_ocorrencia(ocorrencia: OcorrenciaCreate):
    connection = get_connection()

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO ocorrencias (latitude, longitude, situacao)
                VALUES (%s, %s, %s)
                RETURNING id, latitude, longitude, situacao, data_registro;
                """,
                (
                    ocorrencia.latitude,
                    ocorrencia.longitude,
                    ocorrencia.situacao
                )
            )

            resultado = cursor.fetchone()

        connection.commit()

        return {
            "id": resultado[0],
            "latitude": resultado[1],
            "longitude": resultado[2],
            "situacao": resultado[3],
            "data_registro": resultado[4]
        }

    finally:
        connection.close()


@app.get("/ocorrencias")
def listar_ocorrencias():
    connection = get_connection()

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, latitude, longitude, situacao, data_registro
                FROM ocorrencias
                ORDER BY data_registro DESC;
                """
            )

            resultados = cursor.fetchall()

        return [
            {
                "id": resultado[0],
                "latitude": resultado[1],
                "longitude": resultado[2],
                "situacao": resultado[3],
                "data_registro": resultado[4]
            }
            for resultado in resultados
        ]

    finally:
        connection.close()
@app.get("/ocorrencias/{id}")
def buscar_ocorrencia(id: int):
    connection = get_connection()

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, latitude, longitude, situacao, data_registro
                FROM ocorrencias
                WHERE id = %s;
                """,
                (id,)
            )

            resultado = cursor.fetchone()

        if resultado is None:
            return {"erro": "Ocorrência não encontrada"}

        return {
            "id": resultado[0],
            "latitude": resultado[1],
            "longitude": resultado[2],
            "situacao": resultado[3],
            "data_registro": resultado[4]
        }

    finally:
        connection.close()