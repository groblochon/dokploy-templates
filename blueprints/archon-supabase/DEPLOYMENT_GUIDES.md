# Production Deployment Guide

## Overview

This guide explains how to deploy the Archon Supabase Local blueprint in production mode with optimal security and performance settings.

## Prerequisites

- **Docker Compose v2.0+**
- **8GB+ RAM recommended** (12GB+ for high traffic)
- **4+ CPU cores** 
- **100GB+ storage** for production data
- **Domain name** for SSL/HTTPS
- **SSL certificates** (handled by Dokploy)

## Production Setup

### 1. Environment Configuration

Set these variables in your Dokploy deployment:

```bash
DEPLOYMENT_MODE=production
MEMORY_LIMIT=high
POSTGRES_PASSWORD=your-secure-password-here
JWT_SECRET=your-jwt-secret-256-bits
OPENAI_API_KEY=your-openai-key
```

### 2. Version Management

Production uses fixed versions for stability:

```bash
STUDIO_VERSION=2025.06.30-sha-6f5982d
KONG_VERSION=2.8.1
AUTH_VERSION=v2.177.0
REST_VERSION=v12.2.12
REALTIME_VERSION=v2.34.47
ANALYTICS_VERSION=1.14.2
POSTGRES_VERSION=15.8.1.060
```

### 3. Production Optimizations Applied

#### Security Settings
- **JWT expiry**: 1 hour (3600s)
- **Function verification**: Enabled
- **Email autoconfirm**: Disabled
- **Phone signup**: Disabled
- **Anonymous users**: Disabled

#### Database Performance
- **Max connections**: 200
- **Shared preload**: pg_stat_statements
- **Connection pool**: 25 connections
- **Pooler limit**: 200 clients

#### Resource Limits
```yaml
deploy:
  resources:
    limits:
      memory: 1G
      cpus: '1.0'
    reservations:
      memory: 512M
      cpus: '0.5'
```

### 4. Health Checks

All services include production health checks:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:port/health"]
  timeout: 10s
  interval: 30s
  retries: 3
  start_period: 40s
```

### 5. Deployment Commands

#### Production Deployment
```bash
docker compose --profile production up -d
```

#### Production with Resource Limits
```bash
MEMORY_LIMIT=high docker compose --profile production up -d
```

#### Production Health Verification
```bash
docker compose --profile production exec studio curl -f http://localhost:3000/api/platform/profile
docker compose --profile production exec db pg_isready -U postgres
```

## Monitoring Production

### Service Status
```bash
docker compose --profile production ps
```

### Resource Usage
```bash
docker stats $(docker compose --profile production ps -q)
```

### Logs
```bash
docker compose --profile production logs -f studio
docker compose --profile production logs -f db
```

## Production Backup Strategy

### Database Backups
```bash
# Create backup
docker compose --profile production exec db pg_dump -U postgres supabase_db > backup.sql

# Restore backup  
docker compose --profile production exec -T db psql -U postgres supabase_db < backup.sql
```

### Volume Backups
```bash
# Backup volumes
docker run --rm -v archon-supabase_db-config:/data -v $(pwd):/backup alpine tar czf /backup/db-config.tar.gz -C /data .
```

## Scaling Production

### Horizontal Scaling
Add replicas to `docker-compose.yml`:

```yaml
services:
  studio:
    deploy:
      replicas: 2
```

### Resource Scaling
Increase limits in `template.toml`:

```bash
MEMORY_LIMIT=high  # or ultra-high for enterprise
```

## Security Checklist

- [ ] SSL certificates configured
- [ ] JWT secrets are 256+ bits
- [ ] Database password is strong
- [ ] Anonymous access disabled
- [ ] Email verification required
- [ ] Resource limits enforced
- [ ] Health checks enabled
- [ ] Backup strategy in place
- [ ] Monitoring configured

## Troubleshooting Production

### High Memory Usage
```bash
# Check memory usage
docker compose --profile production exec db psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Kill long-running queries
docker compose --profile production exec db psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'active' AND query_start < now() - interval '5 minutes';"
```

### Service Failures
```bash
# Check service health
docker compose --profile production ps

# Restart failed services
docker compose --profile production restart studio
```

### Connection Issues
```bash
# Check Kong API Gateway
docker compose --profile production exec kong kong health

# Check database connections
docker compose --profile production exec db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

## Performance Tuning

### Database Optimization
```sql
-- Add indexes for better performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON auth.users(email);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
```

### Connection Pooling
```bash
# Optimize pooler settings
POOLER_DEFAULT_POOL_SIZE=50
POOLER_MAX_CLIENT_CONN=500
```

---

## Development Deployment Guide

## Overview

Development mode provides debugging capabilities and relaxed security settings for local development.

## Development Setup

### 1. Environment Configuration

```bash
DEPLOYMENT_MODE=development
MEMORY_LIMIT=standard
POSTGRES_PASSWORD=dev-password
JWT_SECRET=dev-jwt-secret
```

### 2. Development Features Enabled

#### Relaxed Security
- **JWT expiry**: 24 hours (86400s)
- **Function verification**: Disabled
- **Email autoconfirm**: Enabled
- **Anonymous users**: Enabled

#### Debug Features
- **Log level**: DEBUG
- **Image transformation**: WebP enabled
- **PostgreSQL extensions**: None (for compatibility)

#### Resource Allocation
```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
```

### 3. Development Deployment

```bash
docker compose --profile development up -d
```

### 4. Development Services Access

- **Supabase Studio**: http://localhost:3000
- **Kong API**: http://localhost:8000
- **Archon Server**: http://localhost:8181
- **Archon UI**: http://localhost:5173
- **Database**: localhost:5432

### 5. Development Database

```bash
# Connect to development database
docker compose --profile development exec db psql -U postgres -d supabase_db

# Reset development data
docker compose --profile development down -v
docker compose --profile development up -d
```

---

Both guides should be saved as separate files for comprehensive deployment documentation.