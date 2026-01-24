# 📋 Required Supabase Files Reference

This document lists all the files required from the [Supabase Docker setup](https://github.com/supabase/supabase/tree/master/docker) and their purposes.

## 🙏 Attribution
**Source**: [Supabase Docker Configuration](https://github.com/supabase/supabase/tree/master/docker)  
**License**: Apache License 2.0  
**Organization**: [Supabase](https://github.com/supabase)  

These files are used under the Apache 2.0 License and adapted for local development with Archon AI Platform.

## 🗂️ File Mapping

### Source: `supabase/docker/volumes/api/`
```
kong.yml → volumes/api/kong.yml
```
**Purpose**: Kong API gateway configuration defining routes, plugins, and proxy settings for Supabase services.

### Source: `supabase/docker/volumes/db/`
```
realtime.sql → volumes/db/realtime.sql
webhooks.sql → volumes/db/webhooks.sql  
roles.sql → volumes/db/roles.sql
jwt.sql → volumes/db/jwt.sql
_supabase.sql → volumes/db/_supabase.sql
logs.sql → volumes/db/logs.sql
pooler.sql → volumes/db/pooler.sql
```
**Purpose**: Database initialization scripts that set up Supabase's core functionality, user roles, JWT handling, and logging.

### Source: `supabase/docker/volumes/functions/`
```
hello/ → volumes/functions/hello/
main/ → volumes/functions/main/
```
**Purpose**: Edge function templates and entry points for Supabase Functions.

### Source: `supabase/docker/volumes/logs/`
```
vector.yml → volumes/logs/vector.yml
```
**Purpose**: Vector log collection configuration for routing container logs to Logflare analytics.

### Source: `supabase/docker/volumes/pooler/`
```
pooler.exs → volumes/pooler/pooler.exs
```
**Purpose**: Elixir configuration for Supavisor database connection pooler.

## 🏗️ Custom Archon Files

### Added for Archon Integration
```
volumes/db/archon_setup.sql
```
**Purpose**: Creates all Archon-specific database tables, indexes, functions, and RLS policies during database initialization.

### Storage Structure
```
volumes/storage/stub/
```
**Purpose**: Placeholder directory structure for Supabase Storage service. Files uploaded through the storage API will be stored here.

## 🚫 Files NOT Included (Intentionally)

### Database Data
- `volumes/db/data/` - Actual PostgreSQL data directory
- `volumes/db/init/data.sql` - Any existing database content

**Reason**: These contain actual database content and should not be included in a template setup.

### Configuration Files with Secrets
- `.env` files with actual credentials
- Any files containing API keys or passwords

**Reason**: Security - template should only include placeholder values.

## 📦 How to Obtain Missing Files

If you need to get these files manually from the Supabase repository:

```bash
# Clone Supabase repository
git clone https://github.com/supabase/supabase.git temp-supabase

# Copy required directories
cp -r temp-supabase/docker/volumes/api ./volumes/
cp -r temp-supabase/docker/volumes/db ./volumes/
cp -r temp-supabase/docker/volumes/functions ./volumes/
cp -r temp-supabase/docker/volumes/logs ./volumes/
cp -r temp-supabase/docker/volumes/pooler ./volumes/

# Remove the temporary clone
rm -rf temp-supabase

# Remove any actual database data
rm -rf ./volumes/db/data
rm -f ./volumes/db/init/data.sql
```

## 🔄 File Versions

This setup is based on Supabase Docker images as of:
- **Studio**: `supabase/studio:2025.06.30-sha-6f5982d`
- **Database**: `supabase/postgres:15.8.1.060`
- **Auth**: `supabase/gotrue:v2.177.0`
- **PostgREST**: `postgrest/postgrest:v12.2.12`
- **Realtime**: `supabase/realtime:v2.34.47`
- **Storage**: `supabase/storage-api:v1.25.7`
- **Analytics**: `supabase/logflare:1.14.2`
- **Meta**: `supabase/postgres-meta:v0.91.0`
- **Functions**: `supabase/edge-runtime:v1.67.4`
- **Pooler**: `supabase/supavisor:2.5.7`

## ⚡ File Size Considerations

### Small Files (< 10KB)
- Configuration files (`.yml`, `.sql`, `.exs`)
- These are safe to include in Git repositories

### Excluded Large Items
- PostgreSQL data directory (can be GBs)
- Container images (downloaded during build)
- User-uploaded storage content

## 🔧 Customization Notes

### Safe to Modify
- `kong.yml` - API gateway routes and plugins
- `vector.yml` - Log routing configuration  
- `pooler.exs` - Connection pooling settings
- Edge function templates

### Do Not Modify
- Core database setup scripts (unless you know what you're doing)
- JWT and authentication configurations
- Realtime and webhook setup scripts

These core files are tightly coupled with Supabase's internal architecture and modifying them may break functionality.

---

For the latest file versions, always check the [official Supabase Docker repository](https://github.com/supabase/supabase/tree/master/docker).