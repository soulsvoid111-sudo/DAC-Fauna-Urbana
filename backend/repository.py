"""Acesso à tabela de ocorrências. Todo SQL do sistema fica aqui."""

COLUNAS = "id, latitude, longitude, situacao, tipo, especie, status, foto_url, data_registro"


class OcorrenciaRepository:
    def __init__(self, connection):
        self.connection = connection

    def criar(self, dados: dict) -> dict:
        with self.connection.cursor() as cursor:
            cursor.execute(
                f"""
                INSERT INTO ocorrencias (latitude, longitude, situacao, tipo, especie, chave_hash)
                VALUES (%(latitude)s, %(longitude)s, %(situacao)s, %(tipo)s, %(especie)s, %(chave_hash)s)
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

    def chave_hash(self, id: int) -> str | None:
        with self.connection.cursor() as cursor:
            cursor.execute("SELECT chave_hash FROM ocorrencias WHERE id = %s;", (id,))
            linha = cursor.fetchone()
            return linha["chave_hash"] if linha else None

    def buscar_com_chaves(self, ids: list[int]) -> list[dict]:
        """Devolve as ocorrências pedidas com o hash da chave, para conferir quem pode ver."""
        if not ids:
            return []
        with self.connection.cursor() as cursor:
            cursor.execute(
                f"SELECT {COLUNAS}, chave_hash FROM ocorrencias WHERE id = ANY(%s) ORDER BY data_registro DESC;",
                (ids,),
            )
            return cursor.fetchall()

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

    def apagar(self, id: int) -> bool:
        with self.connection.cursor() as cursor:
            cursor.execute("DELETE FROM ocorrencias WHERE id = %s RETURNING id;", (id,))
            apagou = cursor.fetchone() is not None
        self.connection.commit()
        return apagou

    def estatisticas(self, dias: int = 30) -> dict:
        urgentes = "('ferido', 'em_risco', 'em_imovel')"
        with self.connection.cursor() as cursor:
            dados = self.resumo()
            cursor.execute(f"SELECT COUNT(*) AS n FROM ocorrencias WHERE tipo IN {urgentes} AND status = 'aberta';")
            dados["urgentes_abertas"] = cursor.fetchone()["n"]
            cursor.execute("SELECT COUNT(*) AS n FROM ocorrencias WHERE foto_url IS NOT NULL;")
            dados["com_foto"] = cursor.fetchone()["n"]
            cursor.execute(
                """
                SELECT (data_registro AT TIME ZONE 'America/Campo_Grande')::date AS dia, COUNT(*) AS total
                FROM ocorrencias
                WHERE data_registro >= NOW() - make_interval(days => %s)
                GROUP BY dia ORDER BY dia;
                """,
                (dias,),
            )
            dados["por_dia"] = [{"dia": l["dia"].isoformat(), "total": l["total"]} for l in cursor.fetchall()]
            cursor.execute(
                """
                SELECT especie, COUNT(*) AS total FROM ocorrencias
                WHERE especie IS NOT NULL GROUP BY especie ORDER BY total DESC, especie LIMIT 5;
                """
            )
            dados["top_especies"] = [{"especie": l["especie"], "total": l["total"]} for l in cursor.fetchall()]
        return dados
