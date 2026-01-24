# 🚀 Archon + Supabase Local Development Setup

A unified Docker Compose setup for running [Archon](https://github.com/coleam00/Archon) AI application with a **local Supabase instance** for development and testing. This setup gives you complete control over your data and allows offline development without relying on Supabase cloud services.

## ✨ What This Provides

- **Local Archon AI Development**: Complete Archon system (Server, MCP, Agents, Frontend) running locally
- **Self-Hosted Supabase**: Full Supabase stack (Database, Auth, API Gateway, Studio) running on your machine
- **Data Privacy**: All data stays on your local machine - no cloud dependencies
- **Offline Development**: Work without internet connection once images are downloaded  
- **Automatic Database Setup**: Archon tables created automatically during initialization
- **One Command Deployment**: Everything runs locally with `docker compose up --build`
- **Hot Reload Development**: Source code changes reflected immediately for rapid iteration

## 🏠 Local Development Focus

This setup is specifically designed for **local development and testing**. It runs Archon with a complete Supabase instance on your local machine, providing:

- **🔒 Data Privacy**: All your data remains on your machine
- **⚡ Fast Development**: No network latency to cloud services  
- **💰 Cost-Free**: No Supabase cloud subscription needed for development
- **🛠️ Full Control**: Complete access to database, logs, and configuration
- **📶 Offline Capable**: Continue development without internet access

> **Note**: This is not intended for production deployment. For production, consider using [Supabase Cloud](https://supabase.com) or setting up a production-grade self-hosted instance with proper security, scaling, and backup strategies.

## 🎯 Quick Start

### Prerequisites

- Docker and Docker Compose v2+ installed
- Git for cloning repositories
- At least 8GB RAM recommended
- Ports 3000, 3737, 8000, 8181, 8051, 8052 available

### Setup Instructions

1. **Clone Required Repositories**
   ```bash
   # Create project directory
   mkdir archon-supabase-project && cd archon-supabase-project
   
   # Clone this setup repository
   git clone <YOUR_REPO_URL> .
   
   # Clone Archon repository
   git clone https://github.com/coleam00/Archon.git archon
   ```

2. **Configure Environment**
   ```bash
   # Copy environment template
   cp .env.example .env
   
   # Edit the .env file with your preferred settings
   # IMPORTANT: Change the default passwords and secrets!
   nano .env
   ```

   **⚠️ CRITICAL: Generate JWT Keys Properly**
   
   The `ANON_KEY` and `SERVICE_ROLE_KEY` must be generated from your `JWT_SECRET` using the official Supabase JWT Generator:
   
   1. **Create a JWT Secret**: Generate a strong, random 32+ character string for `JWT_SECRET`
   2. **Visit the JWT Generator**: Go to https://supabase.com/docs/guides/self-hosting/docker and scroll to the "JWT Generator" section
   3. **Generate ANON_KEY**:
      - Enter your `JWT_SECRET`
      - Set payload to:
        ```json
        {
          "role": "anon",
          "iss": "supabase",
          "iat": 1755759600,
          "exp": 1913526000
        }
        ```
      - Copy the generated token to `ANON_KEY`
   4. **Generate SERVICE_ROLE_KEY**:
      - Keep the same `JWT_SECRET`
      - Change payload to:
        ```json
        {
          "role": "service_role", 
          "iss": "supabase",
          "iat": 1755759600,
          "exp": 1913526000
        }
        ```
      - Copy the generated token to `SERVICE_ROLE_KEY`

3. **Start the System**
   ```bash
   # Build and start all services
   docker compose up --build
   
   # Or run in background
   docker compose up --build -d
   ```

4. **Access Your Local Applications**
   - **Archon UI**: http://localhost:3737 (main application interface)
   - **Supabase Studio**: http://localhost:3000 (local database management)
   - **Supabase API**: http://localhost:8000 (local REST API & auth)
   - **Archon Server API**: http://localhost:8181/health (backend health check)
   
   All services run locally on your machine - no external dependencies!

## 🏗️ Architecture Overview

### Services and Ports

| Service | Container Name | External Port | Description |
|---------|---------------|---------------|-------------|
| **Archon Services** | | | |
| Frontend | Archon-UI | 3737 | React-based user interface |
| Server | Archon-Server | 8181 | FastAPI backend |
| MCP | Archon-MCP | 8051 | Model Context Protocol server |
| Agents | Archon-Agents | 8052 | AI/ML processing services |
| **Supabase Services** | | | |
| Studio | supabase-studio | 3000 | Web admin interface |
| Kong | supabase-kong | 8000, 8443 | API gateway |
| Database | supabase-db | 5432 | PostgreSQL with pgvector |
| Pooler | supabase-pooler | 6543 | Connection pooling |
| Analytics | supabase-analytics | 4000 | Logflare analytics |

### Database Schema

Archon tables are automatically created during database initialization:

- `archon_settings` - Configuration and credentials
- `archon_sources` - Knowledge base sources  
- `archon_crawled_pages` - Document chunks with embeddings
- `archon_code_examples` - Code snippets with embeddings
- `archon_projects` - Project management
- `archon_tasks` - Task tracking
- `archon_project_sources` - Project-source relationships
- `archon_document_versions` - Document version control
- `archon_prompts` - Agent system prompts

## ⚙️ Configuration

### Required Environment Variables

The following **must** be changed in your `.env` file before production:

```bash
# Database password
POSTGRES_PASSWORD=your-super-secret-and-long-postgres-password

# JWT secret (32+ characters) - Used to generate ANON_KEY and SERVICE_ROLE_KEY
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long

# JWT-based API keys (MUST be generated using the JWT Generator tool)
ANON_KEY=YOUR_GENERATED_ANON_KEY_FROM_JWT_GENERATOR
SERVICE_ROLE_KEY=YOUR_GENERATED_SERVICE_ROLE_KEY_FROM_JWT_GENERATOR

# Supabase dashboard login
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=your-secure-dashboard-password

# Encryption keys
SECRET_KEY_BASE=your-secret-key-base-64-chars-long
VAULT_ENC_KEY=your-encryption-key-32-chars-min

# Logflare tokens
LOGFLARE_PUBLIC_ACCESS_TOKEN=your-super-secret-and-long-logflare-key-public
LOGFLARE_PRIVATE_ACCESS_TOKEN=your-super-secret-and-long-logflare-key-private
```

**🔑 JWT Key Generation is Critical**

The `ANON_KEY` and `SERVICE_ROLE_KEY` are NOT random strings - they must be properly generated JWT tokens using your `JWT_SECRET`. Using incorrect keys will cause authentication failures. Always use the official Supabase JWT Generator tool at https://supabase.com/docs/guides/self-hosting/docker.

### Optional Configuration

```bash
# OpenAI API key (can also be configured via Archon UI)
OPENAI_API_KEY=sk-your-openai-api-key-here

# Logfire observability token
LOGFIRE_TOKEN=your-logfire-token

# Service ports (defaults shown)
ARCHON_SERVER_PORT=8181
ARCHON_MCP_PORT=8051
ARCHON_AGENTS_PORT=8052
ARCHON_UI_PORT=3737
```

## 🛠️ Development Workflow

### Managing Services

```bash
# View service status
docker compose ps

# View logs for all services
docker compose logs -f

# View logs for specific service
docker compose logs -f archon-server

# Restart a specific service
docker compose restart archon-server

# Stop everything
docker compose down

# Reset everything (DESTRUCTIVE - removes all data)
docker compose down -v --remove-orphans
```

### Code Development

The setup includes volume mounts for hot reload development:

- Archon Python code: `./archon/python/src` → `/app/src`
- Archon Frontend: `./archon/archon-ui-main/src` → `/app/src`

Changes to source files are automatically reflected in running containers.

### Local Database Access

**Via Local Supabase Studio:**
- URL: http://localhost:3000
- Username: `supabase` (or your `DASHBOARD_USERNAME`)
- Password: Set in `.env` as `DASHBOARD_PASSWORD`

**Via Direct Local Connection:**
```bash
# Local PostgreSQL connection details
Host: localhost
Port: 5432
Database: postgres
Username: postgres
Password: <your POSTGRES_PASSWORD>
```

Your database runs locally in a Docker container with full access and control.

## 🔧 AI Provider Setup

Archon supports multiple AI providers. Configure through the local Settings UI at http://localhost:3737:

- **OpenAI**: Requires API key
- **Google Gemini**: Requires API key  
- **Ollama**: For completely local AI models (no internet required)

API keys can be set via environment variables or configured through the web interface. With Ollama, you can run AI models entirely offline on your local machine.

## 🌟 Why Local Development?

### Benefits of This Setup:
- **🔐 Complete Privacy**: Your conversations, documents, and data never leave your machine
- **⚡ Lightning Fast**: No network latency - everything runs locally
- **💵 Zero Cloud Costs**: No Supabase subscription fees during development
- **🛠️ Full Debugging**: Direct access to logs, database, and all components
- **📶 Work Anywhere**: Develop offline without internet connectivity
- **🔄 Rapid Iteration**: Instant feedback loop for development changes
- **🎯 Production Testing**: Test database migrations and configurations safely

## 📁 Required Files from Supabase

This setup requires specific files from the [Supabase Docker setup](https://github.com/supabase/supabase/tree/master/docker). The following files are included:

### API Configuration
- `volumes/api/kong.yml` - Kong gateway configuration

### Database Setup
- `volumes/db/realtime.sql` - Realtime extensions
- `volumes/db/webhooks.sql` - Webhook functionality  
- `volumes/db/roles.sql` - Database roles and permissions
- `volumes/db/jwt.sql` - JWT authentication setup
- `volumes/db/_supabase.sql` - Core Supabase schema
- `volumes/db/logs.sql` - Logging configuration
- `volumes/db/pooler.sql` - Connection pooler setup
- `volumes/db/archon_setup.sql` - Archon-specific tables

### Functions & Storage
- `volumes/functions/` - Edge function templates
- `volumes/storage/` - File storage configuration

### Monitoring
- `volumes/logs/vector.yml` - Log collection configuration
- `volumes/pooler/pooler.exs` - Database pooler settings

## 🐛 Troubleshooting

### Common Issues

**Port Conflicts:**
```bash
# Check if ports are in use
netstat -tulpn | grep -E ':(3000|3737|8000|8181|8051|8052)'

# Stop conflicting services or change ports in .env
```

**JWT/Authentication Issues:**
```bash
# Common error: "JWT is invalid" or "Authentication failed"
# Solution: Regenerate JWT keys using the proper tool

# 1. Generate new JWT_SECRET (32+ characters)
# 2. Use Supabase JWT Generator: https://supabase.com/docs/guides/self-hosting/docker
# 3. Generate ANON_KEY with role="anon" 
# 4. Generate SERVICE_ROLE_KEY with role="service_role"
# 5. Update .env file and restart services

docker compose restart
```

**Database Connection Issues:**
```bash
# Check database logs
docker compose logs -f db

# Verify database is healthy
docker compose ps db
```

**Service Dependencies:**
```bash
# Restart in dependency order
docker compose restart db
docker compose restart kong
docker compose restart archon-server
```

**Memory Issues:**
```bash
# Monitor resource usage
docker stats

# Increase Docker memory allocation if needed
```

### Reset Everything

If you encounter persistent issues:

```bash
# Stop and remove everything (DESTRUCTIVE)
docker compose down -v --remove-orphans

# Remove any conflicting images
docker system prune -a

# Restart from clean state
docker compose up --build
```

## 🔒 Security Notes

- **Change all default passwords** in `.env` before production
- **Never commit your `.env` file** to version control
- The default JWT keys are for **development only**
- Consider using Docker secrets for production deployments
- Database is exposed on port 5432 - restrict access in production

## 🙏 Attribution & Credits

This local development setup is made possible by combining these excellent open-source projects:

### **🤖 Archon AI Platform**
- **Repository**: [https://github.com/coleam00/Archon](https://github.com/coleam00/Archon)
- **Author**: [@coleam00](https://github.com/coleam00) (Cole Medin)
- **Description**: Advanced AI application with MCP integration, knowledge management, and agent capabilities
- **License**: Check the Archon repository for current license terms

### **🚀 Supabase Backend-as-a-Service**
- **Repository**: [https://github.com/supabase/supabase](https://github.com/supabase/supabase)
- **Organization**: [Supabase](https://github.com/supabase)
- **Description**: Open-source Firebase alternative with PostgreSQL, authentication, and real-time capabilities
- **License**: Apache License 2.0
- **Docker Setup**: Based on [Supabase Docker Configuration](https://github.com/supabase/supabase/tree/master/docker)

### **🔧 Configuration Sources**
- **Supabase JWT Generator**: Official tool from [Supabase Self-Hosting Docs](https://supabase.com/docs/guides/self-hosting/docker)
- **Docker Compose Structure**: Adapted from official Supabase Docker setup
- **Database Schema**: Custom integration combining Archon requirements with Supabase architecture

### **📚 Documentation & Resources**
- **Setup Inspiration**: Official Supabase self-hosting documentation
- **Security Best Practices**: Following both Archon and Supabase recommended configurations
- **Development Workflow**: Optimized for local development based on both projects' guidelines

## 📝 License & Usage

### **License Information**
- **This Setup Configuration**: MIT License (see LICENSE file)
- **Archon**: Please refer to the [Archon repository](https://github.com/coleam00/Archon) for license terms
- **Supabase**: Apache License 2.0 - see [Supabase License](https://github.com/supabase/supabase/blob/master/LICENSE)

### **Attribution Requirements**
When using this setup:
1. **Credit Archon**: Link to [Cole Medin's Archon project](https://github.com/coleam00/Archon)
2. **Credit Supabase**: Link to [Supabase project](https://github.com/supabase/supabase)  
3. **Respect Original Licenses**: Follow the license terms of both projects
4. **Community Contribution**: Consider contributing improvements back to the original projects

## 🤝 Contributing

1. Report issues in the respective repositories:
   - Archon issues: https://github.com/coleam00/Archon/issues
   - Supabase issues: https://github.com/supabase/supabase/issues

2. For setup-specific issues, create an issue in this repository

## 🚀 What's Next?

After your local setup is running:

1. **Configure AI Providers** - Add your API keys via the local Settings UI at http://localhost:3737
2. **Create Projects** - Start organizing your AI workflows locally
3. **Upload Knowledge** - Add documents to your local knowledge base
4. **Explore Features** - Try the MCP integration and agent capabilities
5. **Experiment Safely** - Test features without affecting any cloud resources

### 🎯 Development Tips:
- **Use Ollama** for completely offline AI development
- **Database Studio** at http://localhost:3000 for direct data inspection
- **Hot Reload** means code changes appear instantly
- **All data persists** between container restarts via Docker volumes

---

**Happy Local Building! 🎉🏠**

*Develop with confidence knowing your data stays private and your costs stay zero.*