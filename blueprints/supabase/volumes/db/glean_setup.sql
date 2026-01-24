-- =====================================================
-- GLEAN INITIAL CONFIGURATION FOR SUPABASE
-- =====================================================
-- Since Glean uses SQLAlchemy models, this script provides
-- basic setup for authentication integration only
-- Data migration and schema management handled by Glean backend
-- =====================================================

-- =====================================================
-- INITIAL GLEAN SETTINGS
-- =====================================================

-- System configuration
INSERT INTO glean.settings (key, value, is_public, category, description) VALUES
('SITE_NAME', 'Glean Knowledge Base', true, 'general', 'Site name displayed in UI'),
('SITE_DESCRIPTION', 'AI-powered knowledge management system', true, 'general', 'Site description'),
('DEFAULT_MODEL', 'gpt-4o-mini', true, 'ai', 'Default AI model for conversations'),
('MAX_DOCUMENT_SIZE', '10485760', true, 'limits', 'Maximum document size in bytes (10MB)'),
('MAX_UPLOADS_PER_DAY', '100', true, 'limits', 'Maximum uploads per user per day'),
('ENABLE_REGISTRATIONS', 'true', true, 'auth', 'Allow new user registrations'),
('REQUIRE_EMAIL_VERIFICATION', 'false', true, 'auth', 'Require email verification for new users')
ON CONFLICT (key) DO NOTHING;

-- AI and embedding settings
INSERT INTO glean.settings (key, value, is_public, category, description) VALUES
('EMBEDDING_PROVIDER', 'openai', false, 'ai', 'Embedding provider: openai, local'),
('EMBEDDING_MODEL', 'text-embedding-3-small', false, 'ai', 'Embedding model name'),
('EMBEDDING_DIMENSION', '1536', false, 'ai', 'Embedding vector dimensions'),
('CHUNK_SIZE', '1000', false, 'ai', 'Text chunk size for embeddings'),
('CHUNK_OVERLAP', '200', false, 'ai', 'Overlap between chunks'),
('SIMILARITY_THRESHOLD', '0.7', false, 'ai', 'Minimum similarity threshold for recommendations')
ON CONFLICT (key) DO NOTHING;

-- Search and recommendations
INSERT INTO glean.settings (key, value, is_public, category, description) VALUES
('ENABLE_VECTOR_SEARCH', 'true', true, 'search', 'Enable vector similarity search'),
('ENABLE_HYBRID_SEARCH', 'true', true, 'search', 'Enable hybrid vector + text search'),
('SEARCH_RESULTS_LIMIT', '20', true, 'search', 'Maximum search results per page'),
('ENABLE_RECOMMENDATIONS', 'true', true, 'features', 'Enable AI recommendations'),
('RECOMMENDATIONS_COUNT', '5', true, 'features', 'Number of recommendations to show')
ON CONFLICT (key) DO NOTHING;

-- API keys (encrypted, to be set via admin)
INSERT INTO glean.settings (key, value, is_public, category, description) VALUES
('OPENAI_API_KEY', NULL, false, 'api_keys', 'OpenAI API key for embeddings and chat'),
('ANTHROPIC_API_KEY', NULL, false, 'api_keys', 'Anthropic API key for Claude models'),
('GOOGLE_API_KEY', NULL, false, 'api_keys', 'Google API key for Gemini models')
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- DEFAULT COLLECTIONS
-- =====================================================

-- Create a default public collection for getting started
INSERT INTO glean.collections (name, description, slug, is_public, settings, created_by) VALUES
('Getting Started', 'A collection to help you get started with Glean. Add your documents here!', 'getting-started', true, '{"auto_index": true, "enable_chat": true}', 
  (SELECT id FROM glean.glean_users WHERE username = 'admin' LIMIT 1))
ON CONFLICT (slug) DO NOTHING;

-- Create a private collection template
INSERT INTO glean.collections (name, description, slug, is_public, settings, created_by) VALUES
('My Knowledge', 'Your personal knowledge base. Keep your documents and notes here.', 'my-knowledge', false, '{"auto_index": true, "enable_chat": true}', 
  (SELECT id FROM glean.glean_users WHERE username = 'admin' LIMIT 1))
ON CONFLICT (slug) DO NOTHING;

-- =====================================================
-- SAMPLE DOCUMENTS (for demo purposes)
-- =====================================================

-- Sample document for getting started
INSERT INTO glean.documents (title, content, summary, collection_id, author_id, is_published, tags) VALUES
('Welcome to Glean', 
'# Welcome to Glean Knowledge Base

Glean is an AI-powered knowledge management system that helps you:

## Features
- **Document Management**: Upload and organize your documents
- **AI Search**: Find information using natural language queries
- **Vector Embeddings**: Semantic search across your knowledge base
- **Chat Interface**: Ask questions about your documents
- **Collaboration**: Share collections with your team

## Getting Started
1. Upload your first document
2. Wait for processing and embedding
3. Try the search functionality
4. Start a conversation about your documents

## Tips
- Use descriptive titles for your documents
- Add relevant tags for better organization
- Create collections to organize related documents
- Try the AI chat to ask questions about your content

Happy knowledge management!', 
'A comprehensive guide to getting started with Glean knowledge management system',
(SELECT id FROM glean.collections WHERE slug = 'getting-started' LIMIT 1),
(SELECT id FROM glean.glean_users WHERE username = 'admin' LIMIT 1),
true,
ARRAY['tutorial', 'getting-started', 'guide'])
ON CONFLICT DO NOTHING;

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

-- Function to get or create user from Supabase auth
CREATE OR REPLACE FUNCTION glean.get_or_create_user(
    user_id UUID DEFAULT auth.uid(),
    username TEXT DEFAULT NULL,
    display_name TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    glean_user_id UUID;
BEGIN
    -- Try to find existing Glean user
    SELECT id INTO glean_user_id
    FROM glean.glean_users
    WHERE supabase_user_id = user_id;
    
    -- If not found, create new user
    IF glean_user_id IS NULL THEN
        INSERT INTO glean.glean_users (
            supabase_user_id, 
            username, 
            display_name,
            role
        ) VALUES (
            user_id, 
            COALESCE(username, 'user_' || substr(user_id::text, 1, 8)),
            COALESCE(display_name, 'New User'),
            'user'
        )
        RETURNING id INTO glean_user_id;
    END IF;
    
    RETURN glean_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user settings
CREATE OR REPLACE FUNCTION glean.update_user_preferences(
    preference_key TEXT,
    preference_value JSONB
)
RETURNS BOOLEAN AS $$
DECLARE
    user_id UUID;
BEGIN
    user_id := (SELECT id FROM glean.glean_users WHERE supabase_user_id = auth.uid());
    
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    INSERT INTO glean.user_preferences (user_id, ai_settings)
    VALUES (user_id, jsonb_build_object(preference_key, preference_value))
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        ai_settings = jsonb_set(user_preferences.ai_settings, ARRAY[preference_key], preference_value),
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log document analytics
CREATE OR REPLACE FUNCTION glean.log_document_analytics(
    document_id_param UUID,
    action_param TEXT,
    metadata_param JSONB DEFAULT '{}'::jsonb
)
RETURNS BOOLEAN AS $$
DECLARE
    user_id UUID;
BEGIN
    user_id := (SELECT id FROM glean.glean_users WHERE supabase_user_id = auth.uid());
    
    IF user_id IS NULL THEN
        user_id := NULL; -- Anonymous access
    END IF;
    
    INSERT INTO glean.document_analytics (document_id, user_id, action, metadata)
    VALUES (document_id_param, user_id, action_param, metadata_param);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user statistics
CREATE OR REPLACE FUNCTION glean.get_user_stats(
    target_user_id UUID DEFAULT auth.uid()
)
RETURNS TABLE (
    documents_count BIGINT,
    collections_count BIGINT,
    conversations_count BIGINT,
    bookmarks_count BIGINT,
    total_views BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM glean.documents WHERE author_id = target_user_id) as documents_count,
        (SELECT COUNT(*) FROM glean.collections WHERE created_by = target_user_id) as collections_count,
        (SELECT COUNT(*) FROM glean.conversations WHERE user_id = target_user_id) as conversations_count,
        (SELECT COUNT(*) FROM glean.bookmarks WHERE user_id = target_user_id) as bookmarks_count,
        COALESCE((SELECT SUM(view_count) FROM glean.documents WHERE author_id = target_user_id), 0) as total_views;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PERFORMANCE OPTIMIZATIONS
-- =====================================================

-- Additional indexes for common queries
CREATE INDEX IF NOT EXISTS idx_documents_published_created ON glean.documents(is_published, created_at);
CREATE INDEX IF NOT EXISTS idx_collections_public_created ON glean.collections(is_public, created_at);
CREATE INDEX IF NOT EXISTS idx_conversations_user_updated ON glean.conversations(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON glean.messages(conversation_id, created_at);

-- Partial indexes for better performance
CREATE INDEX IF NOT EXISTS idx_documents_recent ON glean.documents(author_id, created_at) 
    WHERE is_published = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_search_history_user_created ON glean.search_history(user_id, created_at)
    WHERE created_at > NOW() - INTERVAL '30 days';

-- =====================================================
-- VIEWS FOR COMMON QUERIES
-- =====================================================

-- View for user documents with collection info
CREATE OR REPLACE VIEW glean.user_documents AS
SELECT 
    d.*,
    c.name as collection_name,
    c.slug as collection_slug,
    u.username as author_username,
    u.display_name as author_display_name
FROM glean.documents d
JOIN glean.collections c ON d.collection_id = c.id
JOIN glean.glean_users u ON d.author_id = u.id
WHERE d.is_published = TRUE OR d.author_id = (SELECT id FROM glean.glean_users WHERE supabase_user_id = auth.uid());

-- View for recent conversations
CREATE OR REPLACE VIEW glean.recent_conversations AS
SELECT 
    c.*,
    u.username as user_username,
    u.display_name as user_display_name,
    (SELECT COUNT(*) FROM glean.messages m WHERE m.conversation_id = c.id) as message_count,
    (SELECT created_at FROM glean.messages m WHERE m.conversation_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message_at
FROM glean.conversations c
JOIN glean.glean_users u ON c.user_id = u.id
WHERE c.user_id = (SELECT id FROM glean.glean_users WHERE supabase_user_id = auth.uid())
ORDER BY c.updated_at DESC;

-- =====================================================
-- FINAL SETUP AND CLEANUP
-- =====================================================

-- Ensure Glean admin user has proper permissions
GRANT USAGE ON SCHEMA glean TO supabase_glean_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA glean TO supabase_glean_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA glean TO supabase_glean_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA glean TO supabase_glean_admin;

-- Initialize with admin user if it doesn't exist
INSERT INTO glean.glean_users (
    supabase_user_id, 
    username, 
    display_name,
    role,
    settings
) VALUES (
    gen_random_uuid(), -- This will be updated when first admin logs in
    'admin', 
    'System Administrator',
    'super_admin',
    '{"theme": "light", "notifications": {"email": true, "push": true}}'::jsonb
) ON CONFLICT (username) DO NOTHING;

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'Glean setup completed successfully';
    RAISE NOTICE 'Default collections created: getting-started, my-knowledge';
    RAISE NOTICE 'Sample document added to getting-started collection';
    RAISE NOTICE 'Functions available: get_or_create_user, update_user_preferences, log_document_analytics, get_user_stats';
    RAISE NOTICE 'Views available: user_documents, recent_conversations';
END $$;