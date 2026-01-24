# Universal Supabase Integration Guide

This guide provides comprehensive instructions for integrating ANY PostgreSQL-based blueprint with Supabase using the unified integration patterns implemented in dokploy-templates.

## 🎯 Overview

The universal integration system provides:

- **🔗 Unified Backend**: Single Supabase instance for all applications
- **👥 Shared Authentication**: Single sign-on via Supabase Auth
- **⚡ Connection Pooling**: High-performance database connections via Supabase Pooler
- **🔒 Row Level Security**: Multi-tenant data isolation
- **🧠 AI Enhancement**: Vector search and AI/ML capabilities
- **📊 Unified Analytics**: Centralized usage tracking and monitoring
- **🔧 Dynamic Schemas**: Automatic schema creation for any application

## 🏗️ Architecture Pattern

```
Dokploy Project: your-domain.com
┌─────────────────────────────────────────────────┐
│         Supabase Backend (Foundation)          │
│  ├── PostgreSQL Database (with extensions)       │
│  ├── Authentication (Supabase Auth)           │
│  ├── API Gateway (Kong)                    │
│  ├── Connection Pooler (Supavisor)          │
│  ├── Real-time (WebSocket)                   │
│  ├── Storage (File Management)                │
│  ├── Analytics (Logflare)                     │
│  └── Universal Schemas (App-specific)        │
├─────────────────────────────────────────────────┤
│      Application Blueprints (Multiple)          │
│  ├── Directus (CMS)                         │
│  ├── AnythingLLM (LLM Orchestration)       │
│  ├── Flowise (Workflow Automation)             │
│  ├── Budibase (Low-code Platform)            │
│  ├── Chatwoot (Customer Support)             │
│  ├── n8n (Workflow Automation)              │
│  ├── Vaultwarden (Password Manager)          │
│  ├── Trilium (Note-taking)                 │
│  ├── Huly (Project Management)               │
│  ├── Affine (Knowledge Management)           │
│  ├── Blinko (Link Management)               │
│  └── [Your Application]                     │
└─────────────────────────────────────────────────┘
```

## 📋 Supported Blueprints

### ✅ High Priority (AI/ML Enhanced)
These blueprints have advanced AI/ML features with vector search:

| Blueprint | Features | Integration Status |
|-----------|---------|-------------------|
| **anythingllm** | LLM orchestration, tools, workflows | ✅ Full AI schema |
| **dify** | Complex AI workflows, vector operations | ✅ Vector enhanced |
| **flowise** | Workflow automation, AI integration | ✅ Ready for integration |
| **langflow** | AI workflow building | ⚠️ Needs migration from internal PG |

### ✅ Medium Priority (Content Management)

| Blueprint | Features | Integration Status |
|-----------|---------|-------------------|
| **directus** | Headless CMS, permissions | ✅ Full CMS schema |
| **budibase** | Low-code platform, database builder | ✅ External ready |
| **affine** | Collaborative knowledge base | ✅ External ready |
| **huly** | Project management, collaboration | ✅ External ready |

### ✅ Standard Priority (General Applications)

| Blueprint | Features | Integration Status |
|-----------|---------|-------------------|
| **chatwoot** | Customer support, live chat | ✅ External ready |
| **n8n** | Workflow automation | ✅ External ready |
| **vaultwarden** | Password manager | ✅ External ready |
| **trilium** | Note-taking, encryption | ✅ External ready |
| **blinko** | Link management | ✅ External ready |

## 🚀 Universal Integration Template

### Standard Template for External PostgreSQL Applications

For any blueprint that currently connects to external PostgreSQL:

```toml
[variables]
main_domain = "${domain}"

[config.env]
# Supabase Core Configuration
SUPABASE_URL = "https://api-supabase.${main_domain}"
SUPABASE_ANON_KEY = "${ANON_KEY}"
SUPABASE_SERVICE_KEY = "${SERVICE_ROLE_KEY}"

# Enhanced Database Connection (via Pooler)
DATABASE_URL = "postgresql://supabase_{blueprint_id}_admin:${{project.POSTGRES_PASSWORD}}@supabase-pooler.supabase-project.svc.cluster.local:6543/postgres"

# Universal Integration Features
UNIVERSAL_BLUEPRINT_SUPPORT = true
DYNAMIC_SCHEMA_CREATION = true
RLS_ENABLED = true
VECTORIZED_SEARCH = true

# Application-specific configuration (preserve existing)
# ... existing app-specific variables ...
```

### AI/ML Enhanced Template

For AI/ML applications with vector search requirements:

```toml
[variables]
main_domain = "${domain}"

[config.env]
# Supabase Core Configuration
SUPABASE_URL = "https://api-supabase.${main_domain}"
SUPABASE_ANON_KEY = "${ANON_KEY}"
SUPABASE_SERVICE_KEY = "${SERVICE_ROLE_KEY}"

# Enhanced AI/ML Configuration
AI_ENHANCED_SCHEMA = true
AI_EMBEDDING_MODEL = "text-embedding-3-small"
AI_SIMILARITY_THRESHOLD = "0.7"
AI_HYBRID_SEARCH = true
AI_MAX_TOKENS_PER_REQUEST = "4096"
VECTORIZED_SEARCH = true

# OpenAI Configuration (for AI features)
OPENAI_API_KEY = "${{project.OPENAI_API_KEY}}"
OPENAI_API_BASE = "${{project.OPENAI_API_BASE}}"
```

### Content Management Template

For CMS and content-focused applications:

```toml
[variables]
main_domain = "${domain}"

[config.env]
# Supabase Core Configuration
SUPABASE_URL = "https://api-supabase.${main_domain}"
SUPABASE_ANON_KEY = "${ANON_KEY}"
SUPABASE_SERVICE_KEY = "${SERVICE_ROLE_KEY}"

# Content Management Features
CMS_DRAFT_MODE = true
CMS_VERSIONING = true
CMS_WEBHOOKS = true
CMS_PERMISSIONS = true
FILE_STORAGE_ENABLED = true

# Storage Integration
STORAGE_ADAPTER = "supabase"
UPLOAD_MAX_SIZE = "104857600"  # 100MB
```

## 🏗️ Database Schema Architecture

### Universal Tables (Shared by All Apps)

```sql
-- User profile extensions
public.blueprint_profiles        -- App-specific user profiles
public.api_keys               -- Encrypted API keys storage
public.blueprint_settings       -- App-specific configuration

-- AI/ML Enhancement (optional)
public.ai_documents            -- Document storage with embeddings
public.ai_conversations         -- Chat/conversation management
public.ai_models               -- AI model configurations
public.ai_prompt_templates      -- Reusable prompt templates
```

### Application-Specific Schemas

Each application gets its own schema with consistent patterns:

```sql
-- Automatically created for each blueprint
{blueprint_id}.*             -- App-specific tables
{blueprint_id}_admin         -- Admin user for direct DB access
```

### Row Level Security Patterns

Consistent RLS policies across all schemas:

```sql
-- User data isolation
CREATE POLICY "Users can access own data" ON {table}
    FOR ALL USING (profile_id IN (
        SELECT id FROM public.blueprint_profiles 
        WHERE supabase_user_id = auth.uid()
    ));

-- Public data access
CREATE POLICY "Public read access" ON {table}
    FOR SELECT USING (is_public = TRUE);

-- Service role access
CREATE POLICY "Service role full access" ON {table}
    FOR ALL USING (auth.role() = 'service_role');
```

## 🔧 Implementation Steps

### Step 1: Deploy Supabase Foundation

1. **Deploy supabase** blueprint first
2. **Wait for healthy services** (3-5 minutes)
3. **Copy generated keys** from Supabase logs
4. **Configure project variables**:

```bash
# Core Supabase Variables
SUPABASE_URL="https://api-supabase.your-domain.com"
SUPABASE_ANON_KEY="generated_key"
SUPABASE_SERVICE_KEY="generated_service_key"
POSTGRES_HOST="supabase-db.supabase-project.svc.cluster.local"
POSTGRES_PASSWORD="generated_password"

# Enable Universal Features
UNIVERSAL_BLUEPRINT_SUPPORT=true
DYNAMIC_SCHEMA_CREATION=true
RLS_ENABLED=true
```

### Step 2: Configure Application Variables

For each application blueprint:

#### Standard Applications
```bash
# Basic Supabase Integration
DATABASE_URL="postgresql://supabase_{blueprint_id}_admin:password@supabase-pooler:6543/postgres"
SUPABASE_URL="https://api-supabase.your-domain.com"
SUPABASE_ANON_KEY="your_anon_key"
SUPABASE_SERVICE_KEY="your_service_key"
```

#### AI/ML Applications
```bash
# Enhanced AI Integration
DATABASE_URL="postgresql://supabase_{blueprint_id}_admin:password@supabase-pooler:6543/postgres"
AI_ENHANCED_SCHEMA=true
OPENAI_API_KEY="your-openai-key"
VECTORIZED_SEARCH=true
```

#### Content Management Applications
```bash
# CMS Integration
DATABASE_URL="postgresql://supabase_{blueprint_id}_admin:password@supabase-pooler:6543/postgres"
CMS_DRAFT_MODE=true
FILE_STORAGE_ENABLED=true
STORAGE_ADAPTER="supabase"
```

### Step 3: Deploy Application Blueprints

1. **Deploy each blueprint** with configured variables
2. **Configure domains** for each application
3. **Wait for services** to initialize (2-3 minutes each)
4. **Test integrations** between services

### Step 4: Verification and Testing

#### Database Verification
```sql
-- Check schemas were created
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name LIKE '%_blueprint_id%';

-- Check RLS is enabled
SELECT tablename FROM pg_tables 
WHERE schemaname = '{blueprint_id}' AND rowsecurity = true;
```

#### API Gateway Verification
```bash
# Test Kong routing
curl https://api-supabase.your-domain.com/rest/v1/

# Check app-specific routes
curl https://api-supabase.your-domain.com/{blueprint_endpoint}/
```

## 🔒 Security Architecture

### Multi-Layer Security

1. **Network Security**: Docker network isolation
2. **API Gateway**: Kong authentication and rate limiting
3. **Application**: JWT token validation
4. **Database**: Row Level Security (RLS)
5. **Encryption**: Encrypted API key storage

### Access Control Patterns

#### User Hierarchy
```sql
-- Blueprint administrators
auth.role() = 'service_role'

-- Authenticated users
auth.uid() IS NOT NULL

-- Anonymous users
auth.uid() IS NULL
```

#### Permission Matrix

| Role | Database | API | Application Data |
|-------|----------|-----|-----------------|
| Service Role | Full | Full | Full |
| Authenticated | Limited | Limited | Own Data |
| Anonymous | Read Public | Read Public | Public Data |

## 🚀 Performance Optimization

### Connection Pooling Benefits

- **Supavisor Pooler**: 20 default connections per service
- **Automatic Scaling**: Up to 100 concurrent connections
- **Transaction Mode**: Optimized for web applications
- **Resource Efficiency**: Shared connection pool across apps

### Vector Search Performance

```sql
-- Optimized similarity search
SELECT * FROM public.ai_search_documents(
  query_embedding,
  match_count := 10,
  blueprint_filter := '{blueprint_id}',
  similarity_threshold := 0.7
);

-- Hybrid search (vector + text)
SELECT * FROM public.ai_hybrid_search(
  query_text := 'search query',
  query_embedding,
  text_weight := 0.3,
  vector_weight := 0.7
);
```

### Caching Strategy

- **Edge Caching**: Via Supabase CDN
- **Query Results**: L1/L2 cache for common queries
- **Static Assets**: Supabase Storage integration
- **API Responses**: Configurable cache headers

## 📊 Monitoring and Analytics

### Unified Logging

All applications send structured logs to Supabase Analytics:

```bash
# View all application logs
docker logs supabase-analytics
docker logs supabase-kong
```

### Performance Metrics

Track across all integrated applications:

- **Database Performance**: Query execution times
- **API Response Times**: Via Kong plugins
- **User Analytics**: Usage patterns across applications
- **Cost Tracking**: AI/ML usage and costs
- **Error Rates**: Application reliability metrics

### Business Intelligence

```sql
-- Cross-application analytics
SELECT 
    blueprint_id,
    COUNT(*) as active_users,
    SUM(token_count) as total_tokens,
    AVG(response_time_ms) as avg_response_time
FROM public.ai_usage_analytics
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY blueprint_id;
```

## 🔄 Migration Guide

### From Internal PostgreSQL

For applications currently using internal PostgreSQL:

1. **Backup Existing Data**: Export from internal DB
2. **Update Configuration**: Change to external Supabase
3. **Deploy Integration**: Use unified template
4. **Import Data**: Load into Supabase via API or direct DB
5. **Remove Internal Service**: Clean up old PostgreSQL container

### Migration Scripts

```sql
-- Export existing data
pg_dump -h localhost -U postgres -d {database} > backup.sql

-- Import into Supabase
psql -h supabase-pooler -U supabase_{blueprint_id}_admin -d postgres < backup.sql
```

## 🔮 Advanced Configuration

### Custom Extensions

Add application-specific PostgreSQL extensions:

```sql
-- Enable in universal schema
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Schema-specific setup
SELECT public.create_blueprint_schema('{blueprint_id}');
```

### Custom Functions

Create reusable functions across schemas:

```sql
-- Example: Universal search function
CREATE OR REPLACE FUNCTION public.universal_search(
    query_text TEXT,
    blueprint_filter VARCHAR(100),
    limit_count INT DEFAULT 10
) RETURNS TABLE (
    blueprint_id VARCHAR(100),
    content_type VARCHAR(100),
    title TEXT,
    relevance_score FLOAT
);
```

## 🚀 Troubleshooting

### Common Integration Issues

#### 1. Connection Problems
```bash
# Test database connectivity
docker exec -it supabase-db psql -U postgres -d postgres -c "SELECT 1;"

# Check pooler status
docker exec -it supabase-pooler curl http://localhost:4000/api/health
```

#### 2. Schema Creation Failures
```sql
-- Check universal schema exists
SELECT EXISTS (
    SELECT 1 FROM information_schema.schemata 
    WHERE schema_name = 'public'
);

-- Check blueprint schema creation
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name LIKE '%{blueprint_id}%';
```

#### 3. RLS Policy Issues
```sql
-- Verify RLS enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname LIKE '%{blueprint_id}%';
```

### Performance Debugging

```bash
# Check pooler metrics
curl http://supabase-pooler:4000/metrics

# Monitor query performance
docker exec -it supabase-db psql -U postgres -d postgres -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;
"
```

## 📁 File Structure

```
dokploy-templates/
├── blueprints/
│   ├── supabase/                          # Core Supabase stack
│   │   ├── volumes/db/
│   │   │   ├── universal_blueprint_schema.sql      # Universal tables
│   │   │   ├── ai_enhanced_schema.sql          # AI/ML enhancement
│   │   │   ├── directus_schema.sql              # CMS schema
│   │   │   ├── anythingllm_schema.sql           # LLM orchestration
│   │   │   ├── archon_schema.sql               # Archon AI schema
│   │   │   ├── glean_schema.sql                # Glean knowledge base
│   │   │   └── [app_specific_schema].sql   # Individual app schemas
│   │   ├── template.toml                      # Enhanced configuration
│   │   ├── kong.yml                          # Unified API gateway
│   │   └── docker-compose.yml                 # All services
│   ├── [all blueprints]/                    # Enhanced templates
│   │   ├── template.toml                      # Supabase integration
│   │   └── docker-compose.yml                 # External PG removal
│   └── [individual blueprints]/               # Each with own integration
├── UNIFIED_STACKS.md                       # This unified guide
├── ARCHON_SUPABASE_INTEGRATION.md           # Archon specific guide
└── GLEAN_SUPABASE_INTEGRATION.md            # Glean specific guide
```

## 🚀 Future Enhancements

### Planned Features

1. **Auto-Discovery**: Automatic blueprint integration detection
2. **Dynamic Routing**: Automatic Kong route configuration
3. **Multi-Tenancy**: Advanced isolation patterns
4. **Real-time Collaboration**: Shared workspaces across apps
5. **Advanced Analytics**: Business intelligence dashboard
6. **Mobile Sync**: Offline-first mobile application sync

### Community Contributions

We welcome contributions for:

- New blueprint schemas
- Enhanced integration patterns
- Performance optimizations
- Security improvements
- Documentation enhancements

## 📚 Additional Resources

### Documentation
- [Supabase Documentation](https://supabase.com/docs)
- [Dokploy Templates](https://github.com/dokploy/dokploy-templates)
- [PostgreSQL RLS Guide](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Kong API Gateway](https://docs.konghq.com/)

### Integration Examples
- [Archon Integration](./ARCHON_SUPABASE_INTEGRATION.md)
- [Glean Integration](./GLEAN_SUPABASE_INTEGRATION.md)
- [AI/ML Patterns](./AI_ENHANCED_PATTERNS.md)
- [CMS Integration Guide](./CMS_INTEGRATION_GUIDE.md)

## 🆘 Support

### Getting Help

For integration issues:

1. **General Problems**: Check this guide and troubleshooting section
2. **Specific Blueprint Issues**: Check blueprint-specific integration guides
3. **Supabase Issues**: [Supabase GitHub Issues](https://github.com/supabase/supabase/issues)
4. **Dokploy Issues**: [Dokploy Templates Issues](https://github.com/dokploy/dokploy-templates/issues)

### Contribution Guidelines

1. **Consistent Patterns**: Follow established schema and security patterns
2. **Documentation**: Include comprehensive setup and usage guides
3. **Testing**: Test integrations before submitting
4. **Security**: Ensure RLS policies and proper data isolation

---

**Built with 🚀 for the open-source community**

This universal integration system enables seamless deployment of multiple applications with a unified Supabase backend, providing consistency, security, and performance while maintaining flexibility for application-specific requirements.