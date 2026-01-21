# Dépendances des Services Dokploy

## Services de Base (Infrastructure)

### 🗄️ **Bases de Données**
- **PostgreSQL** → budibase, chatwoot, directus, n8n, flowise, actualbudget, outlinewiki, langflow
- **MySQL/MariaDB** → baserow, wordpress, odoo  
- **MongoDB** → nhost, directus, anythingllm, glean
- **SurrealDB** → open-notebook
- **Redis** → budibase, chatwoot, nextcloud, openwebui, flowise, n8n

### 🔍 **Recherche & Indexation**
- **Meilisearch** → karakeep
- **Elasticsearch** → linkwarden, freshrss
- **ChromaDB** → openwebui, open-webui

### 🤖 **AI & ML Services**
- **OpenAI** → archon, open-notebook, karakeep, langflow, openwebui, flowise, anythingllm
- **Crawl4AI** → archon
- **Ollama** → openwebui, open-webui
- **Pipelines** → openwebui, open-webui

### 📁 **Stockage & Médias**
- **S3 Compatible** → budibase, chatwoot, karakeep, nextcloud
- **MinIO** → nhost, supabase
- **Local Storage** → la plupart des services

### 📧 **Email & Communication**
- **SMTP** → budibase, chatwoot, nextcloud, outlinewiki
- **Supabase Auth** → archon, directus, nhost

## Arbre des Dépendances

```
├── 🌐 Core Services
│   ├── 📊 PostgreSQL [Shared Database]
│   │   ├── budibase
│   │   ├── chatwoot
│   │   ├── directus
│   │   ├── n8n
│   │   ├── flowise
│   │   ├── actualbudget
│   │   ├── outlinewiki
│   │   └── langflow
│   │
│   ├── ⚡ Redis [Cache & Queue]
│   │   ├── budibase
│   │   ├── chatwoet
│   │   ├── nextcloud
│   │   ├── openwebui
│   │   ├── flowise
│   │   └── n8n
│   │
│   ├── 🔍 Meilisearch [Search Engine]
│   │   └── karakeep
│   │
│   └── 🤖 Crawl4AI [Web Crawling]
│       └── archon
│
├── 🎯 AI Services
│   ├── openwebui
│   │   ├── 🤖 Ollama [External]
│   │   ├── 📊 ChromaDB [Vector DB]
│   │   └── ⚙️ Pipelines [Processing]
│   │
│   ├── archon
│   │   ├── 🗄️ Supabase [External]
│   │   ├── 🤖 OpenAI [External]
│   │   └── 🕷️ Crawl4AI [External]
│   │
│   ├── karakeep
│   │   ├── 🔍 Meilisearch [External]
│   │   ├── 📁 S3 Storage [External]
│   │   └── 🌐 Chrome Service
│   │
│   └── open-notebook
│       └── 🗄️ SurrealDB [External]
│
├── 📱 Business Applications
│   ├── budibase
│   │   ├── 🗄️ PostgreSQL [External]
│   │   ├── ⚡ Redis [External]
│   │   └── 📁 S3 Storage [External]
│   │
│   ├── chatwoot
│   │   ├── 🗄️ PostgreSQL [External]
│   │   ├── ⚡ Redis [External]
│   │   └── 📁 S3 Storage [External]
│   │
│   └── nextcloud
│       ├── 🗄️ PostgreSQL [Internal]
│       ├── ⚡ Redis [Internal]
│       └── 📁 S3 Storage [External]
│
└── 🔄 Development Tools
    ├── n8n
    │   ├── 🗄️ PostgreSQL [External]
    │   └── ⚡ Redis [External]
    │
    └── flowise
        ├── 🗄️ PostgreSQL [Internal]
        ├── ⚡ Redis [Internal]
        └── 🤖 OpenAI [External]
```

## Variables d'Environnement du Projet

### 📊 **Base de Données**
```bash
POSTGRES_HOST=postgres.domain.com
POSTGRES_DB=database_name
POSTGRES_PASSWORD=secure_password
```

### ⚡ **Redis**
```bash
REDIS_URL=redis://redis.domain.com:6379
```

### 🔍 **Meilisearch**
```bash
MEILI_ADDR=http://meilisearch.domain.com:7700
MEILI_MASTER_KEY=master_key
```

### 🗄️ **SurrealDB**
```bash
SURREAL_URL=ws://surrealdb.domain.com:8000/rpc
SURREAL_PASSWORD=secure_password
```

### 🤖 **AI Services**
```bash
OPENAI_API_KEY=sk-...
OPENAI_API_BASE=https://api.openai.com/v1
OLLAMA_BASE_URL=http://ollama.domain.com:11434
CRAWL4AI_URL=http://crawl4ai.domain.com:11235
```

### 📁 **Stockage S3**
```bash
S3_HOST=s3.domain.com
S3_PORT=443
S3_BUCKET=bucket-name
S3_ACCESS_KEY_ID=access_key
S3_SECRET_ACCESS_KEY=secret_key
S3_REGION=us-east-1
```

### 📧 **Email SMTP**
```bash
SMTP_HOST=smtp.domain.com
SMTP_PORT=587
SMTP_USERNAME=user@domain.com
SMTP_PASSWORD=password
EMAIL_FROM=noreply@domain.com
```