# DAC — Fauna Urbana

## Sistema de Mapeamento e Proteção da Fauna Urbana

Projeto desenvolvido para o Desafio de Articulação de Competências (DAC) do curso de Análise e Desenvolvimento de Sistemas.

O projeto propõe uma solução tecnológica voltada ao registro, organização e visualização de ocorrências relacionadas à fauna urbana, utilizando participação cidadã e recursos tecnológicos para auxiliar no monitoramento.

---

## 1. Sobre o projeto

A fauna urbana está presente em diferentes regiões das cidades, podendo ser encontrada em áreas residenciais, vias públicas, parques, terrenos e outros ambientes urbanos.

Ocorrências envolvendo animais podem ser registradas de diferentes formas, porém informações como localização, situação encontrada e registros fotográficos podem ficar dispersas ou não serem organizadas de maneira adequada.

O projeto Fauna Urbana propõe centralizar essas informações em um sistema que permita registrar ocorrências e posteriormente disponibilizá-las para visualização e análise.

A proposta utiliza tecnologia para contribuir com o registro e monitoramento da fauna urbana, relacionando-se aos princípios de sustentabilidade e conservação ambiental.

---

## 2. Objetivo

Desenvolver uma solução tecnológica para registrar, organizar e visualizar ocorrências de fauna urbana, permitindo que informações como localização, situação e futuramente imagens sejam associadas aos registros.

### Objetivos específicos

- Permitir o registro de ocorrências de fauna urbana.
- Armazenar informações das ocorrências em um banco de dados.
- Associar as ocorrências às suas respectivas localizações.
- Permitir a consulta das ocorrências registradas.
- Disponibilizar uma interface mobile para interação com o sistema.
- Futuramente utilizar mapas e recursos de inteligência artificial como apoio ao monitoramento.
- Possibilitar a administração e visualização dos dados por meio de uma interface administrativa.

---

## 3. Público e contexto

A solução é direcionada principalmente a cidadãos que desejem registrar ocorrências relacionadas à fauna urbana e, posteriormente, a usuários responsáveis pela análise e administração dessas informações.

O projeto possui como contexto inicial a realidade urbana de Mato Grosso do Sul.

---

## 4. Proposta da solução

O sistema será composto por uma aplicação mobile conectada a uma API responsável pela comunicação com o banco de dados.

Fluxo planejado:

```text
Usuário
   ↓
Aplicativo Mobile
   ↓
API / Backend
   ↓
Banco de Dados
   ↓
Visualização e administração das ocorrências

````

Uma ocorrência poderá conter informações como:

* localização;
* situação encontrada;
* data e horário do registro;
* fotografia;
* posteriormente, espécie identificada ou sugerida.

A identificação por inteligência artificial será utilizada como recurso de apoio e não como substituição da validação humana.

---

## 5. Estado atual do protótipo

O sistema já permite:

* registrar uma ocorrência com **tipo** (avistamento, animal ferido, atropelamento, em risco, dentro de imóvel), **espécie** (com sugestões de espécies comuns em MS), descrição e **foto**;
* obter a localização pelo **GPS** do aparelho ou marcar o ponto tocando no **mapa**;
* ver as ocorrências em **lista** (com filtros por tipo) e no **mapa** (marcadores coloridos por tipo);
* abrir os detalhes de uma ocorrência e acompanhar o **status** (aberta, em análise, resolvida, descartada);
* ver orientação de emergência (190 / 193) quando o animal está ferido ou em risco;
* usar o app em **modo demonstração** quando a API está fora do ar, com aviso claro de que nada vai para o banco.

### Fluxo atualmente funcional

```text
Flutter ── POST /ocorrencias ──────────► FastAPI ── INSERT ──► PostgreSQL
        ── POST /ocorrencias/{id}/foto ►         ── salva em backend/uploads/
        ◄─ GET  /ocorrencias ───────────         ◄─ SELECT ──
```

---

## 6. Tecnologias

* **Mobile:** Flutter, Dart, flutter_map (OpenStreetMap), geolocator, image_picker
* **Backend:** Python, FastAPI, Uvicorn, psycopg
* **Banco de dados:** PostgreSQL
* **Testes:** pytest (API) e flutter_test (app)

---

## 7. Como rodar

### 7.1 Banco de dados

Com o PostgreSQL instalado, crie o usuário e o banco (uma vez só):

```sql
CREATE USER fauna_app WITH PASSWORD 'escolha-uma-senha';
CREATE DATABASE fauna_urbana OWNER fauna_app;
```

Depois crie ou atualize a tabela (pode rodar de novo sem perder dados):

```bash
psql -U fauna_app -d fauna_urbana -f backend/database/schema.sql
```

### 7.2 API

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows  (Linux/Mac: source .venv/bin/activate)
pip install -r requirements-dev.txt
copy .env.example .env          # e coloque a senha do banco no .env
uvicorn main:app --reload --host 0.0.0.0
```

A documentação interativa da API fica em http://127.0.0.1:8000/docs.

Testes da API (não precisam do PostgreSQL):

```bash
python -m pytest
```

### 7.3 Aplicativo

```bash
cd mobile
flutter pub get
flutter run -d chrome                                            # navegador
flutter run --dart-define=API_URL=http://192.168.0.10:8000       # celular físico (IP do PC na mesma rede)
flutter run --dart-define=API_URL=http://10.0.2.2:8000           # emulador Android
flutter test
```

> No celular físico, `127.0.0.1` aponta para o próprio celular. Use o IP do computador onde a API está rodando.
> No Windows, gerar o app Android exige ativar o **Modo de Desenvolvedor** (Configurações → Para desenvolvedores).

### 7.4 Publicação (Render + Neon)

* **Banco:** PostgreSQL no [Neon](https://neon.tech). Copie a *connection string* (com `sslmode=require`).
* **API:** *Web Service* no [Render](https://render.com), com:
  * pasta raiz `backend`;
  * build `pip install -r requirements.txt`;
  * start `uvicorn main:app --host 0.0.0.0 --port $PORT`;
  * variável `DATABASE_URL` com a connection string do Neon.

  As tabelas são criadas sozinhas quando a API inicia.
* **App (site):** *Static Site* no Render, com:
  * pasta raiz `mobile`;
  * build `bash build_web.sh`;
  * pasta publicada `build/web`;
  * variável `API_URL` com o endereço da API (ex.: `https://fauna-urbana-api.onrender.com`).
* **Manter a API acordada:** o plano gratuito desliga a API após 15 min sem uso. O workflow `.github/workflows/manter-api-acordada.yml` chama a API a cada 10 min. Para ativar, crie a variável `API_URL` em *Settings → Secrets and variables → Actions → Variables*.
* **Fotos:** ficam guardadas no próprio banco (tabela `fotos`), porque o disco do plano gratuito é apagado a cada reinício.

---

## 8. Estrutura do projeto

```text
DAC-Fauna-Urbana/
├── backend/
│   ├── database/
│   │   ├── connection.py     # conexão (lê o .env)
│   │   └── schema.sql        # criação/atualização da tabela
│   ├── tests/test_api.py     # testes da API
│   ├── main.py               # rotas e validação
│   ├── repository.py         # todo o SQL
│   └── .env.example
└── mobile/lib/
    ├── main.dart             # app e navegação (Registros / Mapa)
    ├── config.dart           # endereço da API e centro do mapa
    ├── models/               # Ocorrencia, tipos e status
    ├── services/             # chamadas HTTP e estado da lista
    ├── screens/              # lista, mapa e formulário de registro
    ├── widgets/              # componentes e tela de detalhes
    └── data/                 # espécies sugeridas e dados de demonstração
```

---

## 9. API

| Método | Rota | O que faz |
|---|---|---|
| GET | `/` | Verifica se a API está no ar |
| GET | `/db-test` | Testa a conexão com o PostgreSQL |
| POST | `/ocorrencias` | Cria uma ocorrência (responde **201**) |
| GET | `/ocorrencias?tipo=&status=&limite=` | Lista, com filtros opcionais |
| GET | `/ocorrencias/resumo` | Totais por tipo e por status |
| GET | `/ocorrencias/{id}` | Busca uma ocorrência (**404** se não existir) |
| PATCH | `/ocorrencias/{id}/status` | Altera o status |
| POST | `/ocorrencias/{id}/foto` | Envia a foto (JPG, PNG ou WEBP, até 8 MB) |
| GET | `/ocorrencias/{id}/foto` | Devolve a foto |

Exemplo de criação:

```json
{
  "latitude": -20.4697,
  "longitude": -54.6201,
  "situacao": "Quati mancando perto do estacionamento",
  "tipo": "ferido",
  "especie": "Quati"
}
```

A API valida os dados (latitude entre -90 e 90, longitude entre -180 e 180, descrição de 3 a 500 caracteres, tipo da lista) e responde **422** quando algo está errado. Se o banco estiver fora do ar, responde **503** com uma mensagem clara.

---

## 10. Banco de dados

```text
ocorrencias
├── id             SERIAL
├── latitude       DOUBLE PRECISION
├── longitude      DOUBLE PRECISION
├── situacao       TEXT
├── tipo           avistamento | ferido | atropelado | em_risco | em_imovel
├── especie        texto opcional
├── status         aberta | em_analise | resolvida | descartada
├── foto_url       endereço da foto (o arquivo fica na tabela fotos)
└── data_registro  TIMESTAMPTZ
```

---

## 11. Próximas etapas

* autenticação de usuários e permissão para alterar status só para administradores;
* painel administrativo web;
* mapa de calor das áreas com mais ocorrências (ex.: trechos com atropelamentos);
* sugestão de espécie por inteligência artificial, com validação humana;
* servidor de mapas próprio ou pago antes de uso em larga escala (os tiles públicos do OpenStreetMap têm limite de uso);
* política de privacidade (LGPD), já que o app guarda a localização de quem registra.

---

## 12. Status

* [x] Estrutura inicial, Flutter, FastAPI e PostgreSQL
* [x] Registro e consulta de ocorrências
* [x] Tipo da ocorrência e espécie
* [x] GPS
* [x] Mapa
* [x] Fotografia
* [x] Status das ocorrências e filtros
* [x] Testes automatizados (API e app)
* [ ] Autenticação
* [ ] Área administrativa
* [ ] Inteligência artificial

---

## 13. Equipe

Projeto desenvolvido por estudantes do curso de Análise e Desenvolvimento de Sistemas — UCDB.

---

## 14. Documentação

A documentação técnica detalhada do projeto será apresentada no Relatório Técnico da DAC.

