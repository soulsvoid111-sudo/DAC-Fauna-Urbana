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

A primeira prova de conceito do projeto já foi implementada e validada em um dispositivo Android físico.

Atualmente o sistema permite:

* executar a aplicação Flutter em um smartphone;
* realizar comunicação entre o aplicativo e a API;
* registrar uma ocorrência pelo aplicativo;
* enviar os dados para o backend;
* armazenar a ocorrência no PostgreSQL;
* consultar as ocorrências armazenadas;
* exibir as ocorrências novamente no aplicativo.

### Fluxo atualmente funcional

```text
Flutter
   ↓
POST /ocorrencias
   ↓
FastAPI
   ↓
INSERT
   ↓
PostgreSQL
   ↓
GET /ocorrencias
   ↓
Flutter
```

A prova de conceito foi validada utilizando ocorrências de teste.

---

## 6. Tecnologias

### Mobile

* Flutter
* Dart

### Backend

* Python
* FastAPI
* Uvicorn

### Banco de dados

* PostgreSQL

### Desenvolvimento

* Visual Studio Code
* Git
* GitHub

---

## 7. Estrutura do projeto

```text
DAC-Fauna-Urbana/
│
├── mobile/
│   └── Aplicação Flutter
│
├── backend/
│   ├── database/
│   │   └── connection.py
│   ├── main.py
│   ├── test_db.py
│   └── requirements.txt
│
├── admin/
│   └── Interface administrativa
│
├── docs/
│   └── Documentação do projeto
│
└── README.md
```

---

## 8. API atualmente implementada

### `GET /`

Verifica se a API está funcionando.

### `GET /db-test`

Testa a comunicação entre a API e o PostgreSQL.

### `POST /ocorrencias`

Registra uma nova ocorrência.

Exemplo:

```json
{
  "latitude": -20.4697,
  "longitude": -54.6201,
  "situacao": "Animal encontrado próximo à via"
}
```

### `GET /ocorrencias`

Retorna as ocorrências registradas.

### `GET /ocorrencias/{id}`

Consulta uma ocorrência específica pelo seu identificador.

---

## 9. Banco de dados

O protótipo utiliza PostgreSQL.

A estrutura inicial da tabela de ocorrências contém:

```text
ocorrencias
├── id
├── latitude
├── longitude
├── situacao
└── data_registro
```

A estrutura poderá ser expandida conforme novas funcionalidades forem implementadas.

---

## 10. Arquitetura inicial

A arquitetura atual separa a aplicação mobile, a API e o banco de dados.

```text
                 ┌─────────────────┐
                 │     Flutter     │
                 │     Mobile      │
                 └────────┬────────┘
                          │
                       HTTP/JSON
                          │
                          ▼
                 ┌─────────────────┐
                 │     FastAPI     │
                 │     Backend     │
                 └────────┬────────┘
                          │
                          │ SQL
                          ▼
                 ┌─────────────────┐
                 │   PostgreSQL    │
                 │    Database     │
                 └─────────────────┘
```

---

## 11. Funcionalidades planejadas

O projeto será desenvolvido de forma incremental.

### Próximas funcionalidades

* obtenção da localização por GPS;
* visualização das ocorrências em mapa;
* registro de fotografias;
* armazenamento das imagens;
* autenticação de usuários;
* controle de permissões;
* interface administrativa;
* filtros das ocorrências;
* alteração e gerenciamento do status das ocorrências.

### Funcionalidades futuras

* sugestão de espécie utilizando inteligência artificial;
* validação humana da identificação;
* identificação de áreas com maior concentração de ocorrências;
* indicadores e estatísticas;
* expansão da solução para outros contextos e localidades.

---

## 12. Limitações da versão atual

A versão apresentada nesta etapa é uma prova de conceito inicial.

Ainda não estão implementados:

* GPS automático;
* mapa;
* câmera;
* autenticação;
* armazenamento de imagens;
* inteligência artificial;
* painel administrativo completo.

Essas funcionalidades fazem parte das próximas etapas de desenvolvimento do projeto.

---

## 13. Próximas etapas

O desenvolvimento seguirá de forma incremental, priorizando o fluxo principal do sistema.

```text
POC inicial
    ↓
GPS e localização
    ↓
Registro com fotografia
    ↓
Mapa
    ↓
Autenticação
    ↓
Área administrativa
    ↓
Testes e validação
    ↓
Recursos de IA e indicadores
```

---

## 14. Status

**Pré-entrega 2 — 25/09/2026**

Estado atual:

* [x] Estrutura inicial do projeto
* [x] Ambiente de desenvolvimento
* [x] Aplicação Flutter
* [x] API FastAPI
* [x] PostgreSQL
* [x] Comunicação Flutter → API
* [x] Registro de ocorrência
* [x] Persistência no banco
* [x] Consulta de ocorrências
* [ ] GPS
* [ ] Mapa
* [ ] Fotografia
* [ ] Autenticação
* [ ] Área administrativa
* [ ] Inteligência artificial

---

## 15. Equipe

Projeto desenvolvido por estudantes do curso de Análise e Desenvolvimento de Sistemas — UCDB.

---

## 16. Documentação

A documentação técnica detalhada do projeto será apresentada no Relatório Técnico da DAC.

