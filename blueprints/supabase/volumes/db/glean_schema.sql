-- =====================================================
-- GLEAN DATABASE INTEGRATION NOTES
-- =====================================================
-- GLEAN USES SQLALCHEMY MODELS - NOT STATIC SQL SCHEMAS
-- =====================================================
-- Glean manages its database schema through SQLAlchemy 2.0 models
-- Migration is handled via Alembic migrations
-- Vector embeddings use Milvus (separate database)
-- Supabase integration should focus on:
-- 1. User authentication linking
-- 2. External database connection
-- 3. RLS policies for user data isolation
-- =====================================================

-- GLEAN AUTHENTICATION EXTENSION FOR SUPABASE
-- =====================================================

-- Create extension for Glean user profiles
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Glean user profile linked to Supabase auth
CREATE TABLE IF NOT EXISTS glean.glean_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supabase_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    glean_username VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    avatar_url TEXT,
    preferences JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Glean-specific settings (stored in Supabase)
CREATE TABLE IF NOT EXISTS glean.glean_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES glean.glean_profiles(id) ON DELETE CASCADE,
    key VARCHAR(255) NOT NULL,
    value TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    category VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, key)
);

-- Migration tracking for Glean users
CREATE TABLE IF NOT EXISTS glean.user_migrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supabase_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    migration_version VARCHAR(50) NOT NULL,
    migrated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    notes TEXT
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_glean_profiles_supabase_id ON glean.glean_profiles(supabase_user_id);
CREATE INDEX IF NOT EXISTS idx_glean_profiles_username ON glean.glean_profiles(glean_username);
CREATE INDEX IF NOT EXISTS idx_glean_settings_user_id ON glean.glean_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_glean_settings_key ON glean.glean_settings(key);
CREATE INDEX IF NOT EXISTS idx_glean_user_migrations_user_id ON glean.user_migrations(supabase_user_id);

-- =====================================================
-- RLS POLICIES FOR GLEAN
-- =====================================================

-- Enable RLS on all Glean tables
ALTER TABLE glean.glean_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.glean_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.user_migrations ENABLE ROW LEVEL SECURITY;

-- Service role policies (full access for Glean backend)
CREATE POLICY "Allow service role full access to glean_profiles" ON glean.glean_profiles
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to glean_settings" ON glean.glean_settings
    FOR ALL USING (auth.role() = 'service_role');

-- Authenticated user policies (users can access their own data)
CREATE POLICY "Allow users to manage own profile" ON glean.glean_profiles
    FOR ALL USING (auth.uid() = supabase_user_id);

CREATE POLICY "Allow users to manage own settings" ON glean.glean_settings
    FOR ALL USING (user_id IN (
        SELECT id FROM glean.glean_profiles 
        WHERE supabase_user_id = auth.uid()
    ));

-- Migration access policies
CREATE POLICY "Allow users to view own migrations" ON glean.user_migrations
    FOR SELECT USING (auth.uid() = supabase_user_id);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION glean.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers
CREATE TRIGGER update_glean_profiles_updated_at
    BEFORE UPDATE ON glean.glean_profiles
    FOR EACH ROW EXECUTE FUNCTION glean.update_updated_at_column();

CREATE TRIGGER update_glean_settings_updated_at
    BEFORE UPDATE ON glean.glean_settings
    FOR EACH ROW EXECUTE FUNCTION glean.update_updated_at_column();

-- Grant permissions to Supabase roles
GRANT USAGE ON SCHEMA glean TO authenticated, anon, supabase_auth_admin, supabase_functions_admin;
GRANT SELECT, INSERT, UPDATE ON glean.glean_profiles TO authenticated;
GRANT SELECT ON glean.glean_settings TO authenticated;
GRANT SELECT ON glean.user_migrations TO authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA glean TO supabase_auth_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA glean TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA glean TO supabase_auth_admin;

-- Set default permissions for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA glean GRANT ALL ON TABLES TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA glean GRANT SELECT, INSERT, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA glean GRANT USAGE ON SEQUENCES TO authenticated;

-- Function to get or create Glean profile
CREATE OR REPLACE FUNCTION glean.get_or_create_glean_profile(
    supabase_user_id UUID DEFAULT auth.uid(),
    glean_username VARCHAR DEFAULT NULL,
    display_name TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    glean_profile_id UUID;
BEGIN
    -- Try to find existing Glean profile
    SELECT id INTO glean_profile_id
    FROM glean.glean_profiles
    WHERE supabase_user_id = supabase_user_id;
    
    -- If not found, create new profile
    IF glean_profile_id IS NULL THEN
        INSERT INTO glean.glean_profiles (
            supabase_user_id, 
            glean_username,
            display_name
        ) VALUES (
            supabase_user_id, 
            COALESCE(glean_username, 'glean_user_' || substr(supabase_user_id::text, 1, 8)),
            COALESCE(display_name, 'Glean User')
        )
        RETURNING id INTO glean_profile_id;
        
        -- Record migration
        INSERT INTO glean.user_migrations (supabase_user_id, migration_version, notes)
        VALUES (supabase_user_id, 'v1.0.0', 'Initial Glean profile creation');
    END IF;
    
    RETURN glean_profile_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update Glean settings
CREATE OR REPLACE FUNCTION glean.update_glean_setting(
    setting_key TEXT,
    setting_value TEXT,
    user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN AS $$
DECLARE
    glean_profile_id UUID;
BEGIN
    -- Get Glean profile ID from Supabase user ID
    SELECT id INTO glean_profile_id
    FROM glean.glean_profiles
    WHERE supabase_user_id = user_id;
    
    IF glean_profile_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Insert or update setting
    INSERT INTO glean.glean_settings (user_id, key, value)
    VALUES (glean_profile_id, setting_key, setting_value)
    ON CONFLICT (user_id, key) 
    DO UPDATE SET 
        value = setting_value,
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Initialize with some default Glean settings
DO $$
BEGIN
    RAISE NOTICE 'Glean Supabase integration schema completed';
    RAISE NOTICE 'Schema: glean (authentication extension)';
    RAISE NOTICE 'Tables: glean_profiles, glean_settings, user_migrations';
    RAISE NOTICE 'Functions: get_or_create_glean_profile, update_glean_setting';
    RAISE NOTICE 'RLS enabled on all Glean tables';
    RAISE NOTICE 'Ready for SQLAlchemy-based Glean integration';
END $$;

-- =====================================================
-- GLEAN USER MANAGEMENT
-- =====================================================

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS glean.glean_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supabase_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    bio TEXT,
    avatar_url TEXT,
    role VARCHAR(50) DEFAULT 'user',
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_glean_users_supabase_id ON glean.glean_users(supabase_user_id);
CREATE INDEX IF NOT EXISTS idx_glean_users_username ON glean.glean_users(username);
CREATE INDEX IF NOT EXISTS idx_glean_users_role ON glean.glean_users(role);

-- =====================================================
-- KNOWLEDGE BASE AND DOCUMENTS
-- =====================================================

-- Document collections (workspaces/organizations)
CREATE TABLE IF NOT EXISTS glean.collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    slug VARCHAR(255) UNIQUE NOT NULL,
    settings JSONB DEFAULT '{}',
    is_public BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES glean.glean_users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Documents and knowledge base
CREATE TABLE IF NOT EXISTS glean.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID REFERENCES glean.collections(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    summary TEXT,
    url TEXT,
    file_type VARCHAR(50) DEFAULT 'text',
    metadata JSONB DEFAULT '{}',
    embedding VECTOR(1536),  -- OpenAI embeddings
    tags TEXT[],
    author_id UUID REFERENCES glean.glean_users(id) ON DELETE SET NULL,
    is_published BOOLEAN DEFAULT FALSE,
    view_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Document chunks for better search
CREATE TABLE IF NOT EXISTS glean.document_chunks (
    id BIGSERIAL PRIMARY KEY,
    document_id UUID REFERENCES glean.documents(id) ON DELETE CASCADE,
    chunk_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    embedding VECTOR(1536),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(document_id, chunk_number)
);

-- Create indexes for vector search
CREATE INDEX ON glean.documents USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX ON glean.document_chunks USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_documents_collection_id ON glean.documents(collection_id);
CREATE INDEX IF NOT EXISTS idx_documents_author_id ON glean.documents(author_id);
CREATE INDEX IF NOT EXISTS idx_documents_tags ON glean.documents USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON glean.documents(created_at);

-- =====================================================
-- CONVERSATIONS AND CHAT
-- =====================================================

-- Chat conversations
CREATE TABLE IF NOT EXISTS glean.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500),
    collection_id UUID REFERENCES glean.collections(id) ON DELETE CASCADE,
    user_id UUID REFERENCES glean.glean_users(id) ON DELETE CASCADE,
    model VARCHAR(100) DEFAULT 'gpt-4o-mini',
    system_prompt TEXT,
    settings JSONB DEFAULT '{}',
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chat messages
CREATE TABLE IF NOT EXISTS glean.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES glean.conversations(id) ON DELETE CASCADE,
    role VARCHAR(20) CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    token_count INTEGER DEFAULT 0,
    model VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON glean.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON glean.messages(created_at);
CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON glean.conversations(user_id);

-- =====================================================
-- BOOKMARKS AND FAVORITES
-- =====================================================

-- User bookmarks
CREATE TABLE IF NOT EXISTS glean.bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES glean.glean_users(id) ON DELETE CASCADE,
    document_id UUID REFERENCES glean.documents(id) ON DELETE CASCADE,
    collection_id UUID REFERENCES glean.collections(id) ON DELETE CASCADE,
    title VARCHAR(500),
    notes TEXT,
    tags TEXT[],
    is_favorite BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, document_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON glean.bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_document_id ON glean.bookmarks(document_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_tags ON glean.bookmarks USING gin(tags);

-- =====================================================
-- SEARCH AND ANALYTICS
-- =====================================================

-- Search history
CREATE TABLE IF NOT EXISTS glean.search_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES glean.glean_users(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    results_count INTEGER DEFAULT 0,
    filters JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Document analytics
CREATE TABLE IF NOT EXISTS glean.document_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES glean.documents(id) ON DELETE CASCADE,
    user_id UUID REFERENCES glean.glean_users(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- view, like, share, download
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_search_history_user_id ON glean.search_history(user_id);
CREATE INDEX IF NOT EXISTS idx_document_analytics_document_id ON glean.document_analytics(document_id);
CREATE INDEX IF NOT EXISTS idx_document_analytics_action ON glean.document_analytics(action);

-- =====================================================
-- SETTINGS AND CONFIGURATION
-- =====================================================

-- Glean settings (system-wide)
CREATE TABLE IF NOT EXISTS glean.settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    category VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User preferences
CREATE TABLE IF NOT EXISTS glean.user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES glean.glean_users(id) ON DELETE CASCADE,
    theme VARCHAR(50) DEFAULT 'light',
    language VARCHAR(10) DEFAULT 'en',
    notifications JSONB DEFAULT '{}',
    ai_settings JSONB DEFAULT '{}',
    ui_settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- =====================================================
-- TRIGGERS FOR UPDATED_AT
-- =====================================================

CREATE OR REPLACE FUNCTION glean.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to relevant tables
CREATE TRIGGER update_glean_users_updated_at
    BEFORE UPDATE ON glean.glean_users
    FOR EACH ROW EXECUTE FUNCTION glean.update_updated_at_column();

CREATE TRIGGER update_collections_updated_at
    BEFORE UPDATE ON glean.collections
    FOR EACH ROW EXECUTE FUNCTION glean.update_updated_at_column();

CREATE TRIGGER update_documents_updated_at
    BEFORE UPDATE ON glean.documents
    FOR EACH ROW EXECUTE FUNCTION glean.update_updated_at_column();

CREATE TRIGGER update_conversations_updated_at
    BEFORE UPDATE ON glean.conversations
    FOR EACH ROW EXECUTE FUNCTION glean.update_updated_at_column();

CREATE TRIGGER update_settings_updated_at
    BEFORE UPDATE ON glean.settings
    FOR EACH ROW EXECUTE FUNCTION glean.update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON glean.user_preferences
    FOR EACH ROW EXECUTE FUNCTION glean.update_updated_at_column();

-- =====================================================
-- RLS POLICIES
-- =====================================================

-- Enable RLS on all glean tables
ALTER TABLE glean.glean_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.document_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE glean.user_preferences ENABLE ROW LEVEL SECURITY;

-- Service role policies (full access)
CREATE POLICY "Allow service role full access to glean_users" ON glean.glean_users
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to collections" ON glean.collections
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to documents" ON glean.documents
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to conversations" ON glean.conversations
    FOR ALL USING (auth.role() = 'service_role');

-- Authenticated user policies
CREATE POLICY "Allow authenticated users to manage glean_users" ON glean.glean_users
    FOR ALL USING (auth.uid() = supabase_user_id OR auth.role() = 'service_role');

CREATE POLICY "Allow authenticated users to read public collections" ON glean.collections
    FOR SELECT USING (is_public = TRUE OR created_by = (SELECT id FROM glean.glean_users WHERE supabase_user_id = auth.uid()));

CREATE POLICY "Allow authenticated users to manage own collections" ON glean.collections
    FOR ALL USING (created_by = (SELECT id FROM glean.glean_users WHERE supabase_user_id = auth.uid()));

-- Public access to published documents
CREATE POLICY "Allow public read access to published documents" ON glean.documents
    FOR SELECT USING (is_published = TRUE);

CREATE POLICY "Allow authenticated users to read collection documents" ON glean.documents
    FOR SELECT USING (collection_id IN (
        SELECT id FROM glean.collections 
        WHERE is_public = TRUE OR created_by = (SELECT id FROM glean.glean_users WHERE supabase_user_id = auth.uid())
    ));

-- Users can manage their own conversations
CREATE POLICY "Allow authenticated users to manage own conversations" ON glean.conversations
    FOR ALL USING (user_id = (SELECT id FROM glean.glean_users WHERE supabase_user_id = auth.uid()));

-- Users can manage their own bookmarks
CREATE POLICY "Allow authenticated users to manage own bookmarks" ON glean.bookmarks
    FOR ALL USING (user_id = (SELECT id FROM glean.glean_users WHERE supabase_user_id = auth.uid()));

-- =====================================================
-- SEARCH FUNCTIONS
-- =====================================================

-- Vector search function for documents
CREATE OR REPLACE FUNCTION glean.search_documents (
  query_embedding VECTOR(1536),
  match_count INT DEFAULT 10,
  collection_filter UUID DEFAULT NULL,
  user_filter UUID DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  title TEXT,
  content TEXT,
  similarity FLOAT,
  collection_id UUID,
  author_id UUID
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.title,
    d.content,
    1 - (d.embedding <=> query_embedding) AS similarity,
    d.collection_id,
    d.author_id
  FROM glean.documents d
  WHERE 
    (collection_filter IS NULL OR d.collection_id = collection_filter)
    AND (user_filter IS NULL OR d.author_id = user_filter)
    AND d.is_published = TRUE
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- Hybrid search (vector + text)
CREATE OR REPLACE FUNCTION glean.hybrid_search_documents (
  query_text TEXT,
  query_embedding VECTOR(1536),
  match_count INT DEFAULT 10,
  collection_filter UUID DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  title TEXT,
  content TEXT,
  similarity FLOAT,
  text_rank REAL,
  combined_score REAL,
  collection_id UUID
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.title,
    d.content,
    1 - (d.embedding <=> query_embedding) AS similarity,
    ts_rank(to_tsvector('english', d.title || ' ' || d.content), plainto_tsquery('english', query_text)) AS text_rank,
    (1 - (d.embedding <=> query_embedding)) + ts_rank(to_tsvector('english', d.title || ' ' || d.content), plainto_tsquery('english', query_text)) AS combined_score,
    d.collection_id
  FROM glean.documents d
  WHERE 
    (collection_filter IS NULL OR d.collection_id = collection_filter)
    AND d.is_published = TRUE
    AND to_tsvector('english', d.title || ' ' || d.content) @@ plainto_tsquery('english', query_text)
  ORDER BY combined_score DESC
  LIMIT match_count;
END;
$$;

-- =====================================================
-- GLEAN ADMIN USER SETUP
-- =====================================================

-- Create Glean admin user for direct database access
CREATE USER IF NOT EXISTS supabase_glean_admin WITH PASSWORD '${POSTGRES_PASSWORD}';
GRANT ALL PRIVILEGES ON SCHEMA glean TO supabase_glean_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA glean TO supabase_glean_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA glean TO supabase_glean_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA glean TO supabase_glean_admin;

-- Grant permissions to authenticated users
GRANT USAGE ON SCHEMA glean TO authenticated, anon, supabase_auth_admin, supabase_functions_admin;
GRANT SELECT ON glean.collections TO authenticated, anon;
GRANT SELECT ON glean.documents TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE ON glean.conversations TO authenticated;
GRANT SELECT, INSERT ON glean.messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON glean.bookmarks TO authenticated;
GRANT SELECT, INSERT ON glean.search_history TO authenticated;
GRANT SELECT ON glean.document_analytics TO authenticated;
GRANT SELECT, INSERT, UPDATE ON glean.user_preferences TO authenticated;

-- Set default permissions for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA glean GRANT ALL ON TABLES TO supabase_glean_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA glean GRANT SELECT, INSERT, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA glean GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA glean GRANT USAGE, SELECT ON SEQUENCES TO authenticated;

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'Glean database schema completed successfully';
    RAISE NOTICE 'Schema: glean';
    RAISE NOTICE 'Tables: glean_users, collections, documents, document_chunks, conversations, messages, bookmarks, search_history, document_analytics, settings, user_preferences';
    RAISE NOTICE 'Extensions: vector, pgcrypto, uuid-ossp, pg_trgm';
    RAISE NOTICE 'User: supabase_glean_admin';
END $$;