-- Estrutura do banco do Fauna Urbana.
-- Pode ser executado mais de uma vez: cria o que falta e não apaga dados.
--
--   psql -U fauna_app -d fauna_urbana -f backend/database/schema.sql

CREATE TABLE IF NOT EXISTS ocorrencias (
    id            SERIAL PRIMARY KEY,
    latitude      DOUBLE PRECISION NOT NULL,
    longitude     DOUBLE PRECISION NOT NULL,
    situacao      TEXT NOT NULL,
    data_registro TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Colunas adicionadas depois da primeira versão (bancos antigos recebem aqui).
ALTER TABLE ocorrencias ADD COLUMN IF NOT EXISTS tipo     VARCHAR(30)  NOT NULL DEFAULT 'avistamento';
ALTER TABLE ocorrencias ADD COLUMN IF NOT EXISTS especie  VARCHAR(100);
ALTER TABLE ocorrencias ADD COLUMN IF NOT EXISTS status   VARCHAR(20)  NOT NULL DEFAULT 'aberta';
ALTER TABLE ocorrencias ADD COLUMN IF NOT EXISTS foto_url VARCHAR(255);
-- Hash da chave de acompanhamento: só quem registrou (com a chave no celular) consulta o próprio registro.
ALTER TABLE ocorrencias ADD COLUMN IF NOT EXISTS chave_hash VARCHAR(64);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ocorrencias_tipo_check') THEN
        ALTER TABLE ocorrencias ADD CONSTRAINT ocorrencias_tipo_check
            CHECK (tipo IN ('avistamento', 'ferido', 'atropelado', 'em_risco', 'em_imovel'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ocorrencias_status_check') THEN
        ALTER TABLE ocorrencias ADD CONSTRAINT ocorrencias_status_check
            CHECK (status IN ('aberta', 'em_analise', 'resolvida', 'descartada'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ocorrencias_data   ON ocorrencias (data_registro DESC);
CREATE INDEX IF NOT EXISTS idx_ocorrencias_tipo   ON ocorrencias (tipo);
CREATE INDEX IF NOT EXISTS idx_ocorrencias_status ON ocorrencias (status);

-- Fotos guardadas no próprio banco (a hospedagem gratuita apaga arquivos do servidor a cada reinício).
CREATE TABLE IF NOT EXISTS fotos (
    ocorrencia_id INTEGER PRIMARY KEY REFERENCES ocorrencias (id) ON DELETE CASCADE,
    conteudo      BYTEA NOT NULL,
    tipo          VARCHAR(30) NOT NULL,
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
