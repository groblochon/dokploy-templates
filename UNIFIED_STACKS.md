# Unified Application Stacks in Dokploy Templates

This repository contains integrated application stacks that combine multiple services through a unified Supabase backend for enhanced functionality, performance, and user experience.

## 🎯 Available Integrations

### Archon + Supabase Integration

**Archon AI Assistant** with self-hosted Supabase backend provides:

- **🧠 AI-Powered**: Advanced AI assistant with document analysis
- **🔍 Vector Search**: Semantic search across knowledge bases
- **📊 Project Management**: Task tracking and project organization
- **🔐 Unified Auth**: Single sign-on via Supabase
- **⚡ High Performance**: Connection pooling via Supabase Pooler

**Services Included:**
- Archon Server (FastAPI + Socket.IO)
- Archon MCP Server (Model Context Protocol)
- Archon Frontend (React UI)
- Complete Supabase Stack (Database, Auth, API Gateway, etc.)

**Documentation:** [ARCHON_SUPABASE_INTEGRATION.md](./ARCHON_SUPABASE_INTEGRATION.md)

---

### Glean + Supabase Integration

**Glean Knowledge Management** with self-hosted Supabase backend provides:

- **📚 Knowledge Base**: Advanced document management system
- **🤖 AI-Powered Search**: Vector similarity + hybrid search
- **🏗️ Collections**: Organize documents in workspaces
- **💬 Chat Interface**: Ask questions about your documents
- **🔒 Multi-Tenant**: Row Level Security for data isolation

**Services Included:**
- Glean Backend (FastAPI)
- Glean Frontend (React Web App)
- Glean Admin (React Admin Panel)
- Glean Worker (Background Processing)
- Milvus Vector Database
- Complete Supabase Stack

**Documentation:** [GLEAN_SUPABASE_INTEGRATION.md](./GLEAN_SUPABASE_INTEGRATION.md)

---

## 🏗️ Architecture Philosophy

### Unified Backend Strategy

All integrations follow this pattern:

```
┌─────────────────────────────────────────────────┐
│             Dokploy Project                  │
├─────────────────────────────────────────────────┤
│  Supabase Backend (Shared Foundation)      │
│  ├── PostgreSQL Database                    │
│  ├── Authentication (Supabase Auth)        │
│  ├── API Gateway (Kong)                  │
│  ├── Connection Pooler (Supavisor)        │
│  ├── Real-time (WebSocket)                │
│  ├── Storage (File Management)             │
│  └── Analytics (Logflare)                 │
├─────────────────────────────────────────────────┤
│  Application Services (Blueprints)          │
│  ├── Service 1 (Backend)                 │
│  ├── Service 2 (Frontend)                │
│  ├── Service 3 (Workers/Background)        │
│  └── Service N (Additional Components)      │
└─────────────────────────────────────────────────┘
```

### Key Benefits

1. **🔗 Shared Infrastructure**: Single database, authentication, and API gateway
2. **⚡ Performance**: Optimized connection pooling and caching
3. **🔒 Security**: Centralized authentication and Row Level Security
4. **💰 Cost Efficiency**: Reduced resource usage and maintenance
5. **📈 Scalability**: Easy to add new applications to the stack
6. **🛠️ Maintainability**: Single source of truth for data and authentication

### Integration Patterns

#### Database Schema Integration
- **Dedicated Schemas**: Each application gets its own schema (e.g., `archon.*`, `glean.*`)
- **Row Level Security**: Multi-tenant data isolation
- **Shared Extensions**: Vector, crypto, UUID extensions shared across apps
- **Cross-App Functions**: Unified search and analytics functions

#### Authentication Integration
- **Unified Users**: Single Supabase Auth users table
- **Extended Profiles**: Application-specific user profiles linked to Supabase users
- **Shared Sessions**: JWT tokens work across all applications
- **Consistent Permissions**: Role-based access control

#### API Gateway Integration
- **Unified Routes**: Kong API gateway routes requests to appropriate services
- **Consistent CORS**: Same-origin policies across all apps
- **Shared Authentication**: JWT verification at gateway level
- **Load Balancing**: Automatic load distribution

## 🚀 Deployment Guide

### Prerequisites

1. **Dokploy Instance**: Running with project support
2. **Custom Domain**: Domain for your services
3. **Project Variables**: Configure shared variables at project level

### Step-by-Step Deployment

#### 1. Configure Project Variables

```bash
# Core Supabase Configuration
SUPABASE_URL="https://api-supabase.your-domain.com"
SUPABASE_ANON_KEY="generated_during_deployment"
SUPABASE_SERVICE_KEY="generated_during_deployment"

# Database Access
POSTGRES_HOST="supabase-db.supabase-project.svc.cluster.local"
POSTGRES_DB="postgres"
POSTGRES_PASSWORD="generated_during_deployment"

# AI Services (shared)
OPENAI_API_KEY="sk-your-openai-api-key"
OPENAI_API_BASE="https://api.openai.com/v1"

# Application-Specific
ARCHON_SECRET_KEY="your-archon-secret"
GLEAN_SECRET_KEY="your-glean-secret"
```

#### 2. Deploy Supabase Blueprint

1. Deploy **supabase** blueprint first
2. Wait for services to be healthy (3-5 minutes)
3. Copy generated keys from logs
4. Update project variables

#### 3. Deploy Application Blueprints

1. Deploy **archon** blueprint (if using Archon)
2. Deploy **glean** blueprint (if using Glean)
3. Configure domains and ensure variables are accessible
4. Wait for services to start (2-3 minutes each)

#### 4. Verify Integration

- **Supabase Studio**: https://supabase.your-domain.com
- **Archon UI**: https://archon.your-domain.com (if deployed)
- **Glean Web**: https://glean.your-domain.com (if deployed)
- **API Gateway**: https://api-supabase.your-domain.com

## 🔧 Configuration

### Shared Database Configuration

All applications connect through Supabase Pooler for optimal performance:

```toml
# Database connection via pooler
DATABASE_URL = "postgresql://app_admin:${POSTGRES_PASSWORD}@supabase-pooler:6543/postgres"

# Supabase API access
SUPABASE_URL = "https://api-supabase.${main_domain}"
SUPABASE_ANON_KEY = "${ANON_KEY}"
SUPABASE_SERVICE_KEY = "${SERVICE_ROLE_KEY}"
```

### Kong API Gateway Routing

The Kong configuration includes routes for all integrated services:

```yaml
# Supabase Services
- /auth/v1/* → supabase-auth:9999
- /rest/v1/* → supabase-rest:3000
- /storage/v1/* → supabase-storage:5000
- /realtime/v1/* → supabase-realtime:4000

# Archon Routes (if deployed)
- /archon/v1/* → archon-server:8181
- /archon-mcp/v1/* → archon-mcp:8051

# Glean Routes (if deployed)
- /glean/api/v1/* → glean-backend:8000
- /glean/* → glean-web:80
- /glean-admin/* → glean-admin:80
```

## 🔒 Security Architecture

### Multi-Layer Security

1. **Network Level**: Docker network isolation
2. **Gateway Level**: Kong authentication and rate limiting
3. **Application Level**: JWT token validation
4. **Database Level**: Row Level Security (RLS)

### Row Level Security Patterns

```sql
-- Application-specific schemas
CREATE SCHEMA archon;
CREATE SCHEMA glean;

-- RLS policies for data isolation
CREATE POLICY "Users access own data" ON archon.archon_projects
    FOR ALL USING (created_by = auth.uid());

CREATE POLICY "Public access to published content" ON glean.glean_documents
    FOR SELECT USING (is_published = TRUE);

-- Service role full access
CREATE POLICY "Service role full access" ON archon.archon_settings
    FOR ALL USING (auth.role() = 'service_role');
```

## 📊 Performance Optimization

### Connection Pooling

- **Supavisor Pooler**: Manages database connections efficiently
- **Default Configuration**: 20 connections per pool, 100 max
- **Transaction Mode**: Optimized for web applications
- **Automatic Scaling**: Handles traffic spikes automatically

### Vector Search Performance

```sql
-- Optimized vector similarity search
SELECT * FROM archon.match_archon_crawled_pages(
  query_embedding,
  match_count := 10,
  filter := '{"category": "documentation"}'::jsonb
);

-- Hybrid search combining vector + text
SELECT * FROM glean.hybrid_search_documents(
  query_text := 'machine learning',
  query_embedding,
  match_count := 20
);
```

### Caching Strategy

- **API Responses**: Edge caching via Supabase CDN
- **Database Queries**: Query result caching
- **Static Assets**: Served via Supabase Storage
- **Vector Results**: Cached similarity search results

## 🔍 Monitoring and Analytics

### Unified Logging

All services send logs to centralized Supabase Analytics:

```bash
# View logs from all services
docker logs supabase-kong          # API Gateway logs
docker logs supabase-analytics        # Analytics processing
docker logs archon-server          # Archon application logs
docker logs glean-backend          # Glean application logs
```

### Health Checks

```bash
# Service health monitoring
curl https://api-supabase.your-domain.com/rest/v1/
curl https://archon.your-domain.com/api/health
curl https://glean.your-domain.com/health
```

### Performance Metrics

- **Database Performance**: pg_stat_statements and slow query logs
- **API Response Times**: Kong plugins for response time tracking
- **Vector Search**: Milvus metrics and query performance
- **User Analytics**: Custom analytics tracking in application schemas

## 🚀 Customization and Extension

### Adding New Applications

To add a new application to the unified stack:

1. **Create Application Schema**: `CREATE SCHEMA new_app;`
2. **Define User Profiles**: Link to Supabase auth.users
3. **Implement RLS Policies**: Secure data access
4. **Add Kong Routes**: Configure API gateway routing
5. **Create Variables**: Use project-level variables for configuration

### Example Integration

```sql
-- New application schema
CREATE SCHEMA new_app;

-- User profile extension
CREATE TABLE new_app.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supabase_user_id UUID REFERENCES auth.users(id),
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS policies
ALTER TABLE new_app.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own profile" ON new_app.profiles
    FOR ALL USING (supabase_user_id = auth.uid());
```

## 📁 File Structure

```
dokploy-templates/
├── blueprints/
│   ├── supabase/                  # Core Supabase stack
│   │   ├── volumes/db/
│   │   │   ├── archon_schema.sql     # Archon database schema
│   │   │   ├── archon_setup.sql      # Archon initial data
│   │   │   ├── glean_schema.sql      # Glean database schema
│   │   │   └── glean_setup.sql       # Glean initial data
│   │   ├── kong.yml              # Unified API gateway config
│   │   ├── template.toml          # Supabase configuration
│   │   └── docker-compose.yml     # Supabase services
│   ├── archon/                   # Archon AI assistant
│   │   ├── template.toml          # Archon configuration
│   │   └── docker-compose.yml     # Archon services
│   └── glean/                    # Glean knowledge management
│       ├── template.toml          # Glean configuration
│       └── docker-compose.yml     # Glean services
├── ARCHON_SUPABASE_INTEGRATION.md  # Archon integration guide
├── GLEAN_SUPABASE_INTEGRATION.md   # Glean integration guide
└── UNIFIED_STACKS.md              # This file
```

## 🔮 Future Enhancements

### Planned Features

1. **More Integrations**: Additional applications with Supabase
2. **Real-time Collaboration**: Shared workspaces and live editing
3. **Advanced Analytics**: Business intelligence and reporting
4. **Mobile Applications**: React Native apps with unified backend
5. **Workflow Automation**: Custom workflows and integrations

### Community Contributions

We welcome contributions for:

- New application integrations
- Performance optimizations
- Security improvements
- Documentation enhancements
- Bug fixes and features

## 📚 Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Dokploy Documentation](https://dokploy.com/docs)
- [Archon GitHub](https://github.com/coleam00/Archon)
- [Glean GitHub](https://github.com/LeslieLeung/glean)
- [Kong Gateway](https://docs.konghq.com/)
- [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)

## 🆘 Support

For issues with unified stacks:

1. **General Issues**: Check [Dokploy Templates Issues](https://github.com/dokploy/dokploy-templates/issues)
2. **Archon Issues**: [Archon GitHub Issues](https://github.com/coleam00/Archon/issues)
3. **Glean Issues**: [Glean GitHub Issues](https://github.com/LeslieLeung/glean/issues)
4. **Supabase Issues**: [Supabase GitHub Issues](https://github.com/supabase/supabase/issues)

---

**Built with ❤️ for the open-source community**

This unified approach enables powerful application stacks while maintaining simplicity, security, and performance. Each integration is designed to work seamlessly together while also being deployable independently.