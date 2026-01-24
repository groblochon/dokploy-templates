-- =====================================================
-- Archon Complete Database Setup
-- =====================================================
-- This script sets up all Archon tables and initial data
-- Runs automatically during Supabase initialization
-- =====================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- ARCHON SETTINGS TABLE
-- =====================================================

-- Credentials and Configuration Management Table
CREATE TABLE IF NOT EXISTS archon_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    encrypted_value TEXT,
    is_encrypted BOOLEAN DEFAULT FALSE,
    category VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_archon_settings_key ON archon_settings(key);
CREATE INDEX IF NOT EXISTS idx_archon_settings_category ON archon_settings(category);

-- Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_archon_settings_updated_at
    BEFORE UPDATE ON archon_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create RLS (Row Level Security) policies for settings
ALTER TABLE archon_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow service role full access" ON archon_settings
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow authenticated users to read and update" ON archon_settings
    FOR ALL TO authenticated
    USING (true);

-- =====================================================
-- INITIAL SETTINGS DATA
-- =====================================================

-- Server Configuration
INSERT INTO archon_settings (key, value, is_encrypted, category, description) VALUES
('MCP_TRANSPORT', 'dual', false, 'server_config', 'MCP server transport mode'),
('HOST', 'localhost', false, 'server_config', 'Host to bind to'),
('PORT', '8051', false, 'server_config', 'Port to listen on'),
('MODEL_CHOICE', 'gpt-4o-mini', false, 'rag_strategy', 'Default LLM model')
ON CONFLICT (key) DO NOTHING;

-- RAG Strategy Configuration
INSERT INTO archon_settings (key, value, is_encrypted, category, description) VALUES
('USE_CONTEXTUAL_EMBEDDINGS', 'false', false, 'rag_strategy', 'Enhances embeddings with contextual information'),
('USE_HYBRID_SEARCH', 'true', false, 'rag_strategy', 'Combines vector and keyword search'),
('USE_AGENTIC_RAG', 'true', false, 'rag_strategy', 'Enables code example extraction'),
('USE_RERANKING', 'true', false, 'rag_strategy', 'Applies reranking to improve relevance'),
('LLM_PROVIDER', 'openai', false, 'rag_strategy', 'LLM provider: openai, ollama, or google'),
('EMBEDDING_MODEL', 'text-embedding-3-small', false, 'rag_strategy', 'Embedding model for vector search')
ON CONFLICT (key) DO NOTHING;

-- Feature flags
INSERT INTO archon_settings (key, value, is_encrypted, category, description) VALUES
('LOGFIRE_ENABLED', 'true', false, 'monitoring', 'Enable Pydantic Logfire logging'),
('PROJECTS_ENABLED', 'true', false, 'features', 'Enable Projects and Tasks functionality')
ON CONFLICT (key) DO NOTHING;

-- Placeholder for API keys (to be set via Settings UI)
INSERT INTO archon_settings (key, encrypted_value, is_encrypted, category, description) VALUES
('OPENAI_API_KEY', NULL, true, 'api_keys', 'OpenAI API Key'),
('GOOGLE_API_KEY', NULL, true, 'api_keys', 'Google API Key for Gemini models')
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- KNOWLEDGE BASE TABLES
-- =====================================================

-- Sources table
CREATE TABLE IF NOT EXISTS archon_sources (
    source_id TEXT PRIMARY KEY,
    summary TEXT,
    total_word_count INTEGER DEFAULT 0,
    title TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_archon_sources_title ON archon_sources(title);
CREATE INDEX IF NOT EXISTS idx_archon_sources_metadata ON archon_sources USING GIN(metadata);

-- Crawled pages table
CREATE TABLE IF NOT EXISTS archon_crawled_pages (
    id BIGSERIAL PRIMARY KEY,
    url VARCHAR NOT NULL,
    chunk_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    source_id TEXT NOT NULL,
    embedding VECTOR(1536),  -- OpenAI embeddings are 1536 dimensions
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(url, chunk_number),
    FOREIGN KEY (source_id) REFERENCES archon_sources(source_id)
);

-- Create indexes for better performance
CREATE INDEX ON archon_crawled_pages USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX idx_archon_crawled_pages_metadata ON archon_crawled_pages USING GIN (metadata);
CREATE INDEX idx_archon_crawled_pages_source_id ON archon_crawled_pages (source_id);

-- Code examples table
CREATE TABLE IF NOT EXISTS archon_code_examples (
    id BIGSERIAL PRIMARY KEY,
    url VARCHAR NOT NULL,
    chunk_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    summary TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    source_id TEXT NOT NULL,
    embedding VECTOR(1536),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(url, chunk_number),
    FOREIGN KEY (source_id) REFERENCES archon_sources(source_id)
);

-- Create indexes for better performance
CREATE INDEX ON archon_code_examples USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX idx_archon_code_examples_metadata ON archon_code_examples USING GIN (metadata);
CREATE INDEX idx_archon_code_examples_source_id ON archon_code_examples (source_id);

-- =====================================================
-- RLS POLICIES FOR KNOWLEDGE BASE
-- =====================================================

-- Enable RLS on knowledge base tables
ALTER TABLE archon_crawled_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE archon_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE archon_code_examples ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Allow public read access to archon_crawled_pages"
  ON archon_crawled_pages FOR SELECT TO public USING (true);

CREATE POLICY "Allow public read access to archon_sources"
  ON archon_sources FOR SELECT TO public USING (true);

CREATE POLICY "Allow public read access to archon_code_examples"
  ON archon_code_examples FOR SELECT TO public USING (true);

-- Allow service role full access
CREATE POLICY "Allow service role full access to archon_crawled_pages" ON archon_crawled_pages
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to archon_sources" ON archon_sources
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to archon_code_examples" ON archon_code_examples
    FOR ALL USING (auth.role() = 'service_role');

-- =====================================================
-- SEARCH FUNCTIONS
-- =====================================================

-- Function to search for documentation chunks
CREATE OR REPLACE FUNCTION match_archon_crawled_pages (
  query_embedding VECTOR(1536),
  match_count INT DEFAULT 10,
  filter JSONB DEFAULT '{}'::jsonb,
  source_filter TEXT DEFAULT NULL
) RETURNS TABLE (
  id BIGINT,
  url VARCHAR,
  chunk_number INTEGER,
  content TEXT,
  metadata JSONB,
  source_id TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
#variable_conflict use_column
BEGIN
  RETURN QUERY
  SELECT
    id,
    url,
    chunk_number,
    content,
    metadata,
    source_id,
    1 - (archon_crawled_pages.embedding <=> query_embedding) AS similarity
  FROM archon_crawled_pages
  WHERE metadata @> filter
    AND (source_filter IS NULL OR source_id = source_filter)
  ORDER BY archon_crawled_pages.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- Function to search for code examples
CREATE OR REPLACE FUNCTION match_archon_code_examples (
  query_embedding VECTOR(1536),
  match_count INT DEFAULT 10,
  filter JSONB DEFAULT '{}'::jsonb,
  source_filter TEXT DEFAULT NULL
) RETURNS TABLE (
  id BIGINT,
  url VARCHAR,
  chunk_number INTEGER,
  content TEXT,
  summary TEXT,
  metadata JSONB,
  source_id TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
#variable_conflict use_column
BEGIN
  RETURN QUERY
  SELECT
    id,
    url,
    chunk_number,
    content,
    summary,
    metadata,
    source_id,
    1 - (archon_code_examples.embedding <=> query_embedding) AS similarity
  FROM archon_code_examples
  WHERE metadata @> filter
    AND (source_filter IS NULL OR source_id = source_filter)
  ORDER BY archon_code_examples.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- =====================================================
-- PROJECTS AND TASKS MODULE
-- =====================================================

-- Task status enumeration
DO $$ BEGIN
    CREATE TYPE task_status AS ENUM ('todo','doing','review','done');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Projects table
CREATE TABLE IF NOT EXISTS archon_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  docs JSONB DEFAULT '[]'::jsonb,
  features JSONB DEFAULT '[]'::jsonb,
  data JSONB DEFAULT '[]'::jsonb,
  github_repo TEXT,
  pinned BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tasks table
CREATE TABLE IF NOT EXISTS archon_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES archon_projects(id) ON DELETE CASCADE,
  parent_task_id UUID REFERENCES archon_tasks(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  status task_status DEFAULT 'todo',
  assignee TEXT DEFAULT 'User' CHECK (assignee IS NOT NULL AND assignee != ''),
  task_order INTEGER DEFAULT 0,
  feature TEXT,
  sources JSONB DEFAULT '[]'::jsonb,
  code_examples JSONB DEFAULT '[]'::jsonb,
  archived BOOLEAN DEFAULT false,
  archived_at TIMESTAMPTZ NULL,
  archived_by TEXT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Project Sources junction table
CREATE TABLE IF NOT EXISTS archon_project_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES archon_projects(id) ON DELETE CASCADE,
  source_id TEXT NOT NULL,
  linked_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT DEFAULT 'system',
  notes TEXT,
  UNIQUE(project_id, source_id)
);

-- Document Versions table
CREATE TABLE IF NOT EXISTS archon_document_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES archon_projects(id) ON DELETE CASCADE,
  task_id UUID REFERENCES archon_tasks(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL,
  version_number INTEGER NOT NULL,
  content JSONB NOT NULL,
  change_summary TEXT,
  change_type TEXT DEFAULT 'update',
  document_id TEXT,
  created_by TEXT DEFAULT 'system',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT chk_project_or_task CHECK (
    (project_id IS NOT NULL AND task_id IS NULL) OR
    (project_id IS NULL AND task_id IS NOT NULL)
  ),
  UNIQUE(project_id, task_id, field_name, version_number)
);

-- Prompts table
CREATE TABLE IF NOT EXISTS archon_prompts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prompt_name TEXT UNIQUE NOT NULL,
  prompt TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_archon_tasks_project_id ON archon_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_archon_tasks_status ON archon_tasks(status);
CREATE INDEX IF NOT EXISTS idx_archon_tasks_assignee ON archon_tasks(assignee);
CREATE INDEX IF NOT EXISTS idx_archon_tasks_order ON archon_tasks(task_order);
CREATE INDEX IF NOT EXISTS idx_archon_tasks_archived ON archon_tasks(archived);
CREATE INDEX IF NOT EXISTS idx_archon_project_sources_project_id ON archon_project_sources(project_id);
CREATE INDEX IF NOT EXISTS idx_archon_project_sources_source_id ON archon_project_sources(source_id);
CREATE INDEX IF NOT EXISTS idx_archon_document_versions_project_id ON archon_document_versions(project_id);
CREATE INDEX IF NOT EXISTS idx_archon_document_versions_task_id ON archon_document_versions(task_id);
CREATE INDEX IF NOT EXISTS idx_archon_prompts_name ON archon_prompts(prompt_name);

-- Apply triggers to projects and tasks tables
CREATE OR REPLACE TRIGGER update_archon_projects_updated_at
    BEFORE UPDATE ON archon_projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_archon_tasks_updated_at
    BEFORE UPDATE ON archon_tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_archon_prompts_updated_at
    BEFORE UPDATE ON archon_prompts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Soft delete function for tasks
CREATE OR REPLACE FUNCTION archive_task(
    task_id_param UUID,
    archived_by_param TEXT DEFAULT 'system'
)
RETURNS BOOLEAN AS $$
DECLARE
    task_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM archon_tasks
        WHERE id = task_id_param AND archived = FALSE
    ) INTO task_exists;

    IF NOT task_exists THEN
        RETURN FALSE;
    END IF;

    UPDATE archon_tasks
    SET
        archived = TRUE,
        archived_at = NOW(),
        archived_by = archived_by_param,
        updated_at = NOW()
    WHERE id = task_id_param;

    UPDATE archon_tasks
    SET
        archived = TRUE,
        archived_at = NOW(),
        archived_by = archived_by_param,
        updated_at = NOW()
    WHERE parent_task_id = task_id_param AND archived = FALSE;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- RLS POLICIES FOR PROJECTS MODULE
-- =====================================================

-- Enable RLS on all project tables
ALTER TABLE archon_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE archon_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE archon_project_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE archon_document_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE archon_prompts ENABLE ROW LEVEL SECURITY;

-- Service role policies (full access)
CREATE POLICY "Allow service role full access to archon_projects" ON archon_projects
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to archon_tasks" ON archon_tasks
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to archon_project_sources" ON archon_project_sources
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to archon_document_versions" ON archon_document_versions
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to archon_prompts" ON archon_prompts
    FOR ALL USING (auth.role() = 'service_role');

-- Authenticated user policies
CREATE POLICY "Allow authenticated users to read and update archon_projects" ON archon_projects
    FOR ALL TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to read and update archon_tasks" ON archon_tasks
    FOR ALL TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to read and update archon_project_sources" ON archon_project_sources
    FOR ALL TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to read archon_document_versions" ON archon_document_versions
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to read archon_prompts" ON archon_prompts
    FOR SELECT TO authenticated USING (true);