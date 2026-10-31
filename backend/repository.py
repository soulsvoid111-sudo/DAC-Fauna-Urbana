"""Acesso à tabela de ocorrências. Todo SQL do sistema fica aqui."""

COLUNAS = "id, latitude, longitude, situacao, tipo, especie, status, foto_url, data_registro"


class OcorrenciaRepository:
    def __init__(self, connection):
        self.connection = connection

    def criar(self, dados: dict) -> dict:
        with self.connection.cursor() as cursor:
            cursor.execute(
                f"""
                INSERT INTO ocorrencias (latitude, longitude, situacao, tipo, especie)
                VALUES (%(latitude)s, %(longitude)s, %(situacao)s, %(tipo)s, %(especie)s)
                RETURNING {COLUNAS};
                """,
                dados,
            )
            resultado = cursor.fetchone()
        self.connection.commit()
        return resultado

    def listar(self, tipo: str | None = None, status: str | None = None, limite: int = 200) -> list[dict]:
        filtros, parametros = [], {"limite": limite}
        if tipo:
            filtros.append("tipo = %(tipo)s")
            parametros["tipo"] = tipo
        if status:
            filtros.append("status = %(status)s")
            parametros["status"] = status
        where = f"WHERE {' AND '.join(filtros)}" if filtros else ""

        with self.connection.cursor() as cursor:
            cursor.execute(
                f"SELECT {COLUNAS} FROM ocorrencias {where} ORDER BY data_registro DESC LIMIT %(limite)s;",
                parametros,
            )
            return cursor.fetchall()

    def buscar(self, id: int) -> dict | None:
        with self.connection.cursor() as cursor:
            cursor.execute(f"SELECT {COLUNAS} FROM ocorrencias WHERE id = %s;", (id,))
            return cursor.fetchone()

    def atualizar(self, id: int, campo: str, valor) -> dict | None:
        if campo != "status":
            raise ValueError(f"Campo não permitido: {campo}")
        with self.connection.cursor() as cursor:
            cursor.execute(
                f"UPDATE ocorrencias SET {campo} = %s WHERE id = %s RETURNING {COLUNAS};",
                (valor, id),
            )
            resultado = cursor.fetchone()
        self.connection.commit()
        return resultado

    def salvar_foto(self, id: int, conteudo: bytes, tipo: str, foto_url: str) -> dict | None:
        with self.connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO fotos (ocorrencia_id, conteudo, tipo) VALUES (%s, %s, %s)
                ON CONFLICT (ocorrencia_id) DO UPDATE SET conteudo = EXCLUDED.conteudo, tipo = EXCLUDED.tipo, criado_em = NOW();
                """,
                (id, conteudo, tipo),
            )
            cursor.execute(
                f"UPDATE ocorrencias SET foto_url = %s WHERE id = %s RETURNING {COLUNAS};",
                (foto_url, id),
            )
            resultado = cursor.fetchone()
        self.connection.commit()
        return resultado

    def buscar_foto(self, id: int) -> dict | None:
        with self.connection.cursor() as cursor:
            cursor.execute("SELECT conteudo, tipo FROM fotos WHERE ocorrencia_id = %s;", (id,))
            return cursor.fetchone()

    def resumo(self) -> dict:
        with self.connection.cursor() as cursor:
            cursor.execute("SELECT tipo, COUNT(*) AS total FROM ocorrencias GROUP BY tipo;")
            por_tipo = {linha["tipo"]: linha["total"] for linha in cursor.fetchall()}
            cursor.execute("SELECT status, COUNT(*) AS total FROM ocorrencias GROUP BY status;")
            por_status = {linha["status"]: linha["total"] for linha in cursor.fetchall()}
        return {"total": sum(por_tipo.values()), "por_tipo": por_tipo, "por_status": por_status}
