-- =====================================================
-- ARCHON INITIAL SETUP AND CONFIGURATION
-- =====================================================
-- This script sets up initial Archon data and configuration
-- Runs after archon_schema.sql during Supabase initialization
-- =====================================================

-- =====================================================
-- INITIAL SETTINGS DATA
-- =====================================================

-- Server Configuration
INSERT INTO archon.archon_settings (key, value, is_encrypted, category, description) VALUES
('MCP_TRANSPORT', 'dual', false, 'server_config', 'MCP server transport mode'),
('HOST', 'localhost', false, 'server_config', 'Host to bind to'),
('PORT', '8051', false, 'server_config', 'Port to listen on'),
('MODEL_CHOICE', 'gpt-4o-mini', false, 'rag_strategy', 'Default LLM model')
ON CONFLICT (key) DO NOTHING;

-- RAG Strategy Configuration
INSERT INTO archon.archon_settings (key, value, is_encrypted, category, description) VALUES
('USE_CONTEXTUAL_EMBEDDINGS', 'false', false, 'rag_strategy', 'Enhances embeddings with contextual information'),
('USE_HYBRID_SEARCH', 'true', false, 'rag_strategy', 'Combines vector and keyword search'),
('USE_AGENTIC_RAG', 'true', false, 'rag_strategy', 'Enables code example extraction'),
('USE_RERANKING', 'true', false, 'rag_strategy', 'Applies reranking to improve relevance'),
('LLM_PROVIDER', 'openai', false, 'rag_strategy', 'LLM provider: openai, ollama, or google'),
('EMBEDDING_MODEL', 'text-embedding-3-small', false, 'rag_strategy', 'Embedding model for vector search')
ON CONFLICT (key) DO NOTHING;

-- Feature flags
INSERT INTO archon.archon_settings (key, value, is_encrypted, category, description) VALUES
('LOGFIRE_ENABLED', 'true', false, 'monitoring', 'Enable Pydantic Logfire logging'),
('PROJECTS_ENABLED', 'true', false, 'features', 'Enable Projects and Tasks functionality'),
('VECTOR_SEARCH_ENABLED', 'true', false, 'features', 'Enable vector similarity search'),
('CODE_EXTRACTION_ENABLED', 'true', false, 'features', 'Enable code example extraction')
ON CONFLICT (key) DO NOTHING;

-- Placeholder for API keys (to be set via Settings UI or environment)
INSERT INTO archon.archon_settings (key, encrypted_value, is_encrypted, category, description) VALUES
('OPENAI_API_KEY', NULL, true, 'api_keys', 'OpenAI API Key'),
('GOOGLE_API_KEY', NULL, true, 'api_keys', 'Google API Key for Gemini models'),
('ANTHROPIC_API_KEY', NULL, true, 'api_keys', 'Anthropic API Key for Claude models')
ON CONFLICT (key) DO NOTHING;

-- External service URLs
INSERT INTO archon.archon_settings (key, value, is_encrypted, category, description) VALUES
('CRAWL4AI_URL', 'http://crawl4ai:11235', false, 'external_services', 'Crawl4AI service URL'),
('CRAWL4AI_API_KEY', NULL, true, 'external_services', 'Crawl4AI API key (if required)'),
('OLLAMA_URL', 'http://ollama:11434', false, 'external_services', 'Ollama service URL')
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- DEFAULT PROMPTS
-- =====================================================

-- System prompts for different AI tasks
INSERT INTO archon.archon_prompts (prompt_name, prompt, description) VALUES
('code_analysis', 'You are an expert code analyst. Analyze the following code and provide insights on its structure, patterns, and potential improvements.', 'Analyze code structure and patterns'),
('documentation_generation', 'You are a technical documentation expert. Generate comprehensive documentation for the following code or system.', 'Generate technical documentation'),
('bug_analysis', 'You are a debugging expert. Analyze the following code and identify potential bugs, issues, and improvements.', 'Identify bugs and suggest fixes'),
('code_review', 'You are a senior developer performing a code review. Evaluate the code for best practices, security, and maintainability.', 'Perform comprehensive code review'),
('architecture_design', 'You are a software architect. Design system architecture based on the requirements and constraints provided.', 'Design system architecture')
ON CONFLICT (prompt_name) DO NOTHING;

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

-- Soft delete function for tasks
CREATE OR REPLACE FUNCTION archon.archive_task(
    task_id_param UUID,
    archived_by_param TEXT DEFAULT 'system'
)
RETURNS BOOLEAN AS $$
DECLARE
    task_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM archon.archon_tasks
        WHERE id = task_id_param AND archived = FALSE
    ) INTO task_exists;

    IF NOT task_exists THEN
        RETURN FALSE;
    END IF;

    UPDATE archon.archon_tasks
    SET
        archived = TRUE,
        archived_at = NOW(),
        archived_by = archived_by_param,
        updated_at = NOW()
    WHERE id = task_id_param;

    UPDATE archon.archon_tasks
    SET
        archived = TRUE,
        archived_at = NOW(),
        archived_by = archived_by_param,
        updated_at = NOW()
    WHERE parent_task_id = task_id_param AND archived = FALSE;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get or create a user project
CREATE OR REPLACE FUNCTION archon.get_or_create_user_project(
    project_title TEXT,
    user_id UUID DEFAULT auth.uid()
)
RETURNS UUID AS $$
DECLARE
    project_id UUID;
BEGIN
    -- Try to find existing project for this user
    SELECT id INTO project_id
    FROM archon.archon_projects
    WHERE title = project_title
    LIMIT 1;
    
    -- If not found, create new project
    IF project_id IS NULL THEN
        INSERT INTO archon.archon_projects (title, description, created_by)
        VALUES (project_title, 'Auto-created project', COALESCE(user_id::TEXT, 'system'))
        RETURNING id INTO project_id;
    END IF;
    
    RETURN project_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update settings securely
CREATE OR REPLACE FUNCTION archon.update_setting(
    setting_key TEXT,
    setting_value TEXT,
    is_encrypted BOOLEAN DEFAULT FALSE,
    updated_by TEXT DEFAULT 'system'
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE archon.archon_settings
    SET 
        value = CASE WHEN is_encrypted THEN NULL ELSE setting_value END,
        encrypted_value = CASE WHEN is_encrypted THEN setting_value ELSE NULL END,
        is_encrypted = is_encrypted,
        updated_at = NOW()
    WHERE key = setting_key;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PERFORMANCE OPTIMIZATIONS
-- =====================================================

-- Create additional indexes for common queries
CREATE INDEX IF NOT EXISTS idx_archon_settings_category_value ON archon.archon_settings(category, value);
CREATE INDEX IF NOT EXISTS idx_archon_sources_title_created ON archon.archon_sources(title, created_at);
CREATE INDEX IF NOT EXISTS idx_archon_crawled_pages_created_at ON archon.archon_crawled_pages(created_at);
CREATE INDEX IF NOT EXISTS idx_archon_code_examples_created_at ON archon.archon_code_examples(created_at);
CREATE INDEX IF NOT EXISTS idx_archon_projects_title_pinned ON archon.archon_projects(title, pinned);
CREATE INDEX IF NOT EXISTS idx_archon_tasks_project_status ON archon.archon_tasks(project_id, status);
CREATE INDEX IF NOT EXISTS idx_archon_tasks_assignee_status ON archon.archon_tasks(assignee, status);

-- Create partial indexes for better performance
CREATE INDEX IF NOT EXISTS idx_archon_tasks_active ON archon.archon_tasks(project_id, updated_at) 
    WHERE archived = FALSE;
    
CREATE INDEX IF NOT EXISTS idx_archon_crawled_pages_recent ON archon.archon_crawled_pages(source_id, created_at)
    WHERE created_at > NOW() - INTERVAL '30 days';

-- =====================================================
-- VIEWS FOR COMMON QUERIES
-- =====================================================

-- View for active tasks with project info
CREATE OR REPLACE VIEW archon.active_tasks AS
SELECT 
    t.*,
    p.title as project_title,
    p.description as project_description
FROM archon.archon_tasks t
JOIN archon.archon_projects p ON t.project_id = p.id
WHERE t.archived = FALSE;

-- View for sources with page counts
CREATE OR REPLACE VIEW archon.source_stats AS
SELECT 
    s.*,
    COUNT(cp.id) as crawled_pages_count,
    COUNT(ce.id) as code_examples_count,
    s.total_word_count
FROM archon.archon_sources s
LEFT JOIN archon.archon_crawled_pages cp ON s.source_id = cp.source_id
LEFT JOIN archon.archon_code_examples ce ON s.source_id = ce.source_id
GROUP BY s.source_id, s.title, s.summary, s.total_word_count, s.metadata, s.created_at, s.updated_at;

-- =====================================================
-- ARCHON ADMIN USER SETUP
-- =====================================================

-- Ensure Archon admin user has proper permissions
GRANT USAGE ON SCHEMA archon TO supabase_archon_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA archon TO supabase_archon_admin;
GRANT INSERT ON ALL TABLES IN SCHEMA archon TO supabase_archon_admin;
GRANT UPDATE ON ALL TABLES IN SCHEMA archon TO supabase_archon_admin;
GRANT DELETE ON ALL TABLES IN SCHEMA archon TO supabase_archon_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA archon TO supabase_archon_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA archon TO supabase_archon_admin;

-- Grant permissions to authenticated users for necessary tables
GRANT SELECT, INSERT, UPDATE ON archon.archon_settings TO authenticated;
GRANT SELECT ON archon.archon_sources TO authenticated;
GRANT SELECT ON archon.archon_crawled_pages TO authenticated;
GRANT SELECT ON archon.archon_code_examples TO authenticated;
GRANT SELECT, INSERT, UPDATE ON archon.archon_projects TO authenticated;
GRANT SELECT, INSERT, UPDATE ON archon.archon_tasks TO authenticated;
GRANT SELECT, INSERT, UPDATE ON archon.archon_project_sources TO authenticated;
GRANT SELECT ON archon.archon_document_versions TO authenticated;
GRANT SELECT ON archon.archon_prompts TO authenticated;

-- Grant permissions to anonymous users for public data
GRANT SELECT ON archon.archon_sources TO anon;
GRANT SELECT ON archon.archon_crawled_pages TO anon;
GRANT SELECT ON archon.archon_code_examples TO anon;

-- =====================================================
-- FINAL SETUP NOTES
-- =====================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA archon TO authenticated, anon, supabase_auth_admin, supabase_functions_admin;

-- Set default permissions for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA archon GRANT ALL ON TABLES TO supabase_archon_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA archon GRANT SELECT, INSERT, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA archon GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA archon GRANT USAGE, SELECT ON SEQUENCES TO authenticated;

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'Archon database schema and setup completed successfully';
    RAISE NOTICE 'Schema: archon';
    RAISE NOTICE 'Tables: archon_settings, archon_sources, archon_crawled_pages, archon_code_examples, archon_projects, archon_tasks, archon_project_sources, archon_document_versions, archon_prompts';
    RAISE NOTICE 'Extensions: vector, pgcrypto, uuid-ossp, pg_trgm';
    RAISE NOTICE 'User: supabase_archon_admin';
END $$;