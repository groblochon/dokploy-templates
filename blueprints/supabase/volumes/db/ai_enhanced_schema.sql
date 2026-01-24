-- =====================================================
-- AI/ML ENHANCED UNIVERSAL SCHEMA
-- =====================================================
-- Additional schema components for AI/ML applications
-- Extends universal_blueprint_schema.sql
-- =====================================================

-- =====================================================
-- DOCUMENT PROCESSING AND EMBEDDINGS
-- =====================================================

-- Universal document storage for AI applications
CREATE TABLE IF NOT EXISTS public.ai_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    content_type VARCHAR(100) DEFAULT 'text/plain',
    summary TEXT,
    metadata JSONB DEFAULT '{}',
    embedding VECTOR(1536),  -- Standard OpenAI dimensions
    tags TEXT[],
    processing_status VARCHAR(50) DEFAULT 'pending',
    chunk_count INTEGER DEFAULT 1,
    word_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Document chunks for better search and retrieval
CREATE TABLE IF NOT EXISTS public.ai_document_chunks (
    id BIGSERIAL PRIMARY KEY,
    document_id UUID REFERENCES public.ai_documents(id) ON DELETE CASCADE,
    blueprint_id VARCHAR(100) NOT NULL,
    chunk_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    embedding VECTOR(1536),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(document_id, chunk_number)
);

-- Embedding jobs tracking
CREATE TABLE IF NOT EXISTS public.ai_embedding_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    document_id UUID REFERENCES public.ai_documents(id) ON DELETE CASCADE,
    model_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    error_message TEXT,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for vector search
CREATE INDEX ON public.ai_documents USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX ON public.ai_document_chunks USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_ai_documents_blueprint_id ON public.ai_documents(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_ai_documents_profile_id ON public.ai_documents(profile_id);
CREATE INDEX IF NOT EXISTS idx_ai_documents_status ON public.ai_documents(processing_status);
CREATE INDEX IF NOT EXISTS idx_ai_documents_tags ON public.ai_documents USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_ai_documents_created_at ON public.ai_documents(created_at);

-- =====================================================
-- CHAT AND CONVERSATION MANAGEMENT
-- =====================================================

-- Universal conversation management
CREATE TABLE IF NOT EXISTS public.ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    title VARCHAR(500),
    model VARCHAR(100) DEFAULT 'gpt-4o-mini',
    system_prompt TEXT,
    context JSONB DEFAULT '{}',
    settings JSONB DEFAULT '{}',
    is_public BOOLEAN DEFAULT FALSE,
    message_count INTEGER DEFAULT 0,
    token_usage JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chat messages with context tracking
CREATE TABLE IF NOT EXISTS public.ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
    blueprint_id VARCHAR(100) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    token_count INTEGER DEFAULT 0,
    model VARCHAR(100),
    tools_used JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ai_conversations_blueprint_id ON public.ai_conversations(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_profile_id ON public.ai_conversations(profile_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_created_at ON public.ai_conversations(created_at);
CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation_id ON public.ai_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_ai_messages_created_at ON public.ai_messages(created_at);

-- =====================================================
-- KNOWLEDGE BASE AND SEARCH
-- =====================================================

-- Knowledge collections/workspaces
CREATE TABLE IF NOT EXISTS public.ai_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(50) DEFAULT 'general', -- general, code, research, personal
    settings JSONB DEFAULT '{}',
    is_public BOOLEAN DEFAULT FALSE,
    document_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Document-collection relationships
CREATE TABLE IF NOT EXISTS public.ai_collection_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID REFERENCES public.ai_collections(id) ON DELETE CASCADE,
    document_id UUID REFERENCES public.ai_documents(id) ON DELETE CASCADE,
    blueprint_id VARCHAR(100) NOT NULL,
    added_by UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(collection_id, document_id)
);

-- Search analytics for optimization
CREATE TABLE IF NOT EXISTS public.ai_search_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    query_type VARCHAR(50) DEFAULT 'text', -- text, vector, hybrid
    results_count INTEGER DEFAULT 0,
    response_time_ms INTEGER,
    filters JSONB DEFAULT '{}',
    embedding_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ai_collections_blueprint_id ON public.ai_collections(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_ai_collections_profile_id ON public.ai_collections(profile_id);
CREATE INDEX IF NOT EXISTS idx_ai_collections_type ON public.ai_collections(type);
CREATE INDEX IF NOT EXISTS idx_ai_collection_documents_collection_id ON public.ai_collection_documents(collection_id);
CREATE INDEX IF NOT EXISTS idx_ai_search_history_blueprint_id ON public.ai_search_history(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_ai_search_history_created_at ON public.ai_search_history(created_at);

-- =====================================================
-- AI WORKFLOW AND AUTOMATION
-- =====================================================

-- Workflow definitions
CREATE TABLE IF NOT EXISTS public.ai_workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    workflow_definition JSONB NOT NULL, -- JSON workflow definition
    triggers JSONB DEFAULT '{}', -- When to run workflow
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    execution_count INTEGER DEFAULT 0,
    last_executed TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Workflow execution history
CREATE TABLE IF NOT EXISTS public.ai_workflow_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID REFERENCES public.ai_workflows(id) ON DELETE CASCADE,
    blueprint_id VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending', -- pending, running, completed, failed
    input_data JSONB DEFAULT '{}',
    output_data JSONB DEFAULT '{}',
    error_message TEXT,
    execution_time_ms INTEGER,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ai_workflows_blueprint_id ON public.ai_workflows(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_ai_workflows_profile_id ON public.ai_workflows(profile_id);
CREATE INDEX IF NOT EXISTS idx_ai_workflows_active ON public.ai_workflows(is_active);
CREATE INDEX IF NOT EXISTS idx_ai_workflow_executions_workflow_id ON public.ai_workflow_executions(workflow_id);
CREATE INDEX IF NOT EXISTS idx_ai_workflow_executions_status ON public.ai_workflow_executions(status);

-- =====================================================
-- AI MODEL CONFIGURATION
-- =====================================================

-- Model configurations and settings
CREATE TABLE IF NOT EXISTS public.ai_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL, -- openai, anthropic, google, local
    model_type VARCHAR(50) DEFAULT 'chat', -- chat, embedding, fine-tuned
    model_id VARCHAR(100) NOT NULL, -- gpt-4, claude-3, gemini-pro
    description TEXT,
    pricing JSONB DEFAULT '{}', -- token pricing info
    capabilities JSONB DEFAULT '{}', -- vision, tools, streaming, etc.
    max_tokens INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(blueprint_id, model_id)
);

-- Model usage tracking
CREATE TABLE IF NOT EXISTS public.ai_model_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    model_id UUID REFERENCES public.ai_models(id) ON DELETE CASCADE,
    usage_type VARCHAR(50) NOT NULL, -- prompt_tokens, completion_tokens, embedding
    token_count INTEGER DEFAULT 0,
    cost DECIMAL(10, 6) DEFAULT 0.000000,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ai_models_blueprint_id ON public.ai_models(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_ai_models_provider ON public.ai_models(provider);
CREATE INDEX IF NOT EXISTS idx_ai_models_active ON public.ai_models(is_active);
CREATE INDEX IF NOT EXISTS idx_ai_model_usage_blueprint_id ON public.ai_model_usage(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_ai_model_usage_profile_id ON public.ai_model_usage(profile_id);
CREATE INDEX IF NOT EXISTS idx_ai_model_usage_created_at ON public.ai_model_usage(created_at);

-- =====================================================
-- AI PROMPTS AND TEMPLATES
-- =====================================================

-- Prompt templates for different use cases
CREATE TABLE IF NOT EXISTS public.ai_prompt_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100), -- writing, coding, analysis, translation, etc.
    template_text TEXT NOT NULL,
    variables JSONB DEFAULT '{}', -- Template variables definition
    model_requirements JSONB DEFAULT '{}', -- Required model capabilities
    usage_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES public.blueprint_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Fine-tuned models and custom prompts
CREATE TABLE IF NOT EXISTS public.ai_custom_prompts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    prompt_type VARCHAR(50) DEFAULT 'system', -- system, user, assistant
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    model_id UUID REFERENCES public.ai_models(id) ON DELETE SET NULL,
    is_favorite BOOLEAN DEFAULT FALSE,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ai_prompt_templates_blueprint_id ON public.ai_prompt_templates(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_ai_prompt_templates_category ON public.ai_prompt_templates(category);
CREATE INDEX IF NOT EXISTS idx_ai_prompt_templates_public ON public.ai_prompt_templates(is_public);
CREATE INDEX IF NOT EXISTS idx_ai_custom_prompts_profile_id ON public.ai_custom_prompts(profile_id);
CREATE INDEX IF NOT EXISTS idx_ai_custom_prompts_favorite ON public.ai_custom_prompts(is_favorite);

-- =====================================================
-- RLS POLICIES FOR AI TABLES
-- =====================================================

-- Enable RLS on all AI tables
ALTER TABLE public.ai_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_embedding_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_collection_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_workflow_executions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_model_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_prompt_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_custom_prompts ENABLE ROW LEVEL SECURITY;

-- Service role policies (full access)
CREATE POLICY "Allow service role full access to ai_documents" ON public.ai_documents
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to ai_conversations" ON public.ai_conversations
    FOR ALL USING (auth.role() = 'service_role');

-- Authenticated user policies
CREATE POLICY "Allow authenticated users to manage own ai_documents" ON public.ai_documents
    FOR ALL USING (profile_id IN (
        SELECT id FROM public.blueprint_profiles 
        WHERE supabase_user_id = auth.uid()
    ));

CREATE POLICY "Allow public read access to public ai_documents" ON public.ai_documents
    FOR SELECT USING (is_public = TRUE);

CREATE POLICY "Allow authenticated users to manage own ai_conversations" ON public.ai_conversations
    FOR ALL USING (profile_id IN (
        SELECT id FROM public.blueprint_profiles 
        WHERE supabase_user_id = auth.uid()
    ));

-- Anonymous policies (public data access)
CREATE POLICY "Allow anonymous read access to public ai_prompt_templates" ON public.ai_prompt_templates
    FOR SELECT USING (is_public = TRUE);

-- =====================================================
-- AI-SPECIFIC SEARCH FUNCTIONS
-- =====================================================

-- Advanced vector search with filtering
CREATE OR REPLACE FUNCTION public.ai_search_documents(
    query_embedding VECTOR(1536),
    match_count INT DEFAULT 10,
    blueprint_filter VARCHAR(100) DEFAULT NULL,
    collection_filter UUID DEFAULT NULL,
    user_filter UUID DEFAULT NULL,
    similarity_threshold FLOAT DEFAULT 0.7
) RETURNS TABLE (
    id UUID,
    title TEXT,
    content TEXT,
    similarity FLOAT,
    blueprint_id VARCHAR(100),
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
        d.blueprint_id,
        cd.collection_id
    FROM public.ai_documents d
    LEFT JOIN public.ai_collection_documents cd ON d.id = cd.document_id
    WHERE 
        d.processing_status = 'completed'
        AND d.embedding IS NOT NULL
        AND (blueprint_filter IS NULL OR d.blueprint_id = blueprint_filter)
        AND (collection_filter IS NULL OR cd.collection_id = collection_filter)
        AND (user_filter IS NULL OR d.profile_id = user_filter)
        AND d.is_public = TRUE OR d.profile_id = user_filter
    HAVING (1 - (d.embedding <=> query_embedding)) >= similarity_threshold
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Hybrid search combining vector and text search
CREATE OR REPLACE FUNCTION public.ai_hybrid_search(
    query_text TEXT,
    query_embedding VECTOR(1536),
    match_count INT DEFAULT 10,
    text_weight FLOAT DEFAULT 0.3,
    vector_weight FLOAT DEFAULT 0.7
) RETURNS TABLE (
    id UUID,
    title TEXT,
    content TEXT,
    text_score REAL,
    vector_similarity FLOAT,
    combined_score FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.title,
        d.content,
        ts_rank(to_tsvector('english', d.title || ' ' || d.content), plainto_tsquery('english', query_text)) AS text_score,
        1 - (d.embedding <=> query_embedding) AS vector_similarity,
        (ts_rank(to_tsvector('english', d.title || ' ' || d.content), plainto_tsquery('english', query_text)) * text_weight + 
         (1 - (d.embedding <=> query_embedding)) * vector_weight) AS combined_score
    FROM public.ai_documents d
    WHERE 
        d.processing_status = 'completed'
        AND d.embedding IS NOT NULL
        AND d.is_public = TRUE
        AND to_tsvector('english', d.title || ' ' || d.content) @@ plainto_tsquery('english', query_text)
    ORDER BY combined_score DESC
    LIMIT match_count;
END;
$$;

-- Vector search across document chunks
CREATE OR REPLACE FUNCTION public.ai_search_chunks(
    query_embedding VECTOR(1536),
    match_count INT DEFAULT 10,
    blueprint_filter VARCHAR(100) DEFAULT NULL
) RETURNS TABLE (
    id BIGINT,
    document_id UUID,
    chunk_number INT,
    content TEXT,
    similarity FLOAT,
    blueprint_id VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dc.id,
        dc.document_id,
        dc.chunk_number,
        dc.content,
        1 - (dc.embedding <=> query_embedding) AS similarity,
        dc.blueprint_id
    FROM public.ai_document_chunks dc
    JOIN public.ai_documents d ON dc.document_id = d.id
    WHERE 
        d.processing_status = 'completed'
        AND (blueprint_filter IS NULL OR dc.blueprint_id = blueprint_filter)
    ORDER BY dc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- =====================================================
-- AI UTILITY FUNCTIONS
-- =====================================================

-- Function to track model usage
CREATE OR REPLACE FUNCTION public.track_ai_usage(
    blueprint_id_param VARCHAR(100),
    model_id_param UUID,
    usage_type_param VARCHAR(50),
    token_count_param INTEGER DEFAULT 0,
    cost_param DECIMAL(10, 6) DEFAULT 0.000000
)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO public.ai_model_usage (
        blueprint_id, model_id, usage_type, token_count, cost
    ) VALUES (
        blueprint_id_param, model_id_param, usage_type_param, token_count_param, cost_param
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get conversation with context
CREATE OR REPLACE FUNCTION public.get_conversation_context(
    conversation_id_param UUID,
    message_limit INT DEFAULT 10
) RETURNS TABLE (
    id UUID,
    role VARCHAR(20),
    content TEXT,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.role,
        m.content,
        m.created_at
    FROM public.ai_messages m
    WHERE m.conversation_id = conversation_id_param
    ORDER BY m.created_at DESC
    LIMIT message_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- DEFAULT AI MODELS CONFIGURATION
-- =====================================================

-- Insert common AI models
INSERT INTO public.ai_models (blueprint_id, name, provider, model_type, model_id, description, max_tokens, capabilities) VALUES
('universal', 'GPT-4o Mini', 'openai', 'chat', 'gpt-4o-mini', 'OpenAI GPT-4o Mini model for general use', 128000, '{"vision": false, "tools": true, "streaming": true}'),
('universal', 'GPT-4o', 'openai', 'chat', 'gpt-4o', 'OpenAI GPT-4o model for complex tasks', 128000, '{"vision": true, "tools": true, "streaming": true}'),
('universal', 'Claude 3.5 Sonnet', 'anthropic', 'chat', 'claude-3-5-sonnet', 'Anthropic Claude 3.5 Sonnet model', 200000, '{"vision": true, "tools": true, "streaming": true}'),
('universal', 'Text Embedding 3 Small', 'openai', 'embedding', 'text-embedding-3-small', 'OpenAI text embedding model', 8191, '{"vision": false, "tools": false, "streaming": false}'),
('universal', 'Text Embedding 3 Large', 'openai', 'embedding', 'text-embedding-3-large', 'OpenAI large text embedding model', 8191, '{"vision": false, "tools": false, "streaming": false}')
ON CONFLICT (blueprint_id, model_id) DO NOTHING;

-- Default AI settings
INSERT INTO public.blueprint_settings (blueprint_id, key, value, is_public, category, description) VALUES
('universal', 'DEFAULT_EMBEDDING_MODEL', 'text-embedding-3-small', true, 'ai', 'Default embedding model for AI applications'),
('universal', 'DEFAULT_CHAT_MODEL', 'gpt-4o-mini', true, 'ai', 'Default chat model for conversations'),
('universal', 'VECTOR_DIMENSIONS', '1536', true, 'ai', 'Vector dimensions for embeddings'),
('universal', 'SIMILARITY_THRESHOLD', '0.7', true, 'ai', 'Default similarity threshold for vector search'),
('universal', 'ENABLE_HYBRID_SEARCH', 'true', true, 'ai', 'Enable hybrid text+vector search'),
('universal', 'MAX_TOKENS_PER_REQUEST', '4096', true, 'ai', 'Maximum tokens per API request'),
('universal', 'ENABLE_TRACKING', 'true', true, 'analytics', 'Enable usage tracking and analytics')
ON CONFLICT (blueprint_id, key) DO NOTHING;

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'AI/ML enhanced universal schema completed successfully';
    RAISE NOTICE 'Tables: ai_documents, ai_document_chunks, ai_embedding_jobs, ai_conversations, ai_messages, ai_collections, ai_collection_documents, ai_search_history, ai_workflows, ai_workflow_executions, ai_models, ai_model_usage, ai_prompt_templates, ai_custom_prompts';
    RAISE NOTICE 'Functions: ai_search_documents, ai_hybrid_search, ai_search_chunks, track_ai_usage, get_conversation_context';
    RAISE NOTICE 'Default AI models configured: GPT-4o, Claude 3.5, Text Embedding 3';
    RAISE NOTICE 'RLS enabled on all AI tables';
END $$;