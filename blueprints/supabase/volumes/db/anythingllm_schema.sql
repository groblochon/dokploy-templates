-- =====================================================
-- ANYTHINGLLM SCHEMA
-- =====================================================
-- Schema for AnythingLLM LLM orchestration platform
-- Designed for integration with Supabase RLS and extensions
-- =====================================================

-- Create blueprint-specific schema
SELECT public.create_blueprint_schema('anythingllm');

-- =====================================================
-- ANYTHINGLLM CORE TABLES
-- =====================================================

-- LLM model configurations
CREATE TABLE IF NOT EXISTS anythingllm.models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    provider VARCHAR(100) NOT NULL, -- openai, anthropic, local, etc.
    model_id VARCHAR(255) NOT NULL,
    model_type VARCHAR(50) DEFAULT 'chat', -- chat, embedding, image, audio
    api_base_url TEXT,
    api_key_encrypted TEXT,
    max_tokens INTEGER,
    supports_tools BOOLEAN DEFAULT FALSE,
    supports_vision BOOLEAN DEFAULT FALSE,
    supports_streaming BOOLEAN DEFAULT TRUE,
    pricing JSONB DEFAULT '{}', -- per-token pricing info
    parameters JSONB DEFAULT '{}', -- model parameters (temperature, etc.)
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- LLM workflows
CREATE TABLE IF NOT EXISTS anythingllm.workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    model_id UUID REFERENCES anythingllm.models(id) ON DELETE SET NULL,
    system_prompt TEXT,
    tools JSONB DEFAULT '[]',
    workflow_definition JSONB NOT NULL, -- JSON workflow structure
    variables JSONB DEFAULT '{}',
    settings JSONB DEFAULT '{}',
    is_public BOOLEAN DEFAULT FALSE,
    is_template BOOLEAN DEFAULT FALSE,
    usage_count INTEGER DEFAULT 0,
    last_used TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- LLM conversations
CREATE TABLE IF NOT EXISTS anythingllm.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    workflow_id UUID REFERENCES anythingllm.workflows(id) ON DELETE SET NULL,
    title VARCHAR(500),
    model_id UUID REFERENCES anythingllm.models(id) ON DELETE SET NULL,
    system_prompt_override TEXT,
    context JSONB DEFAULT '{}',
    status VARCHAR(50) DEFAULT 'active', -- active, paused, completed
    settings JSONB DEFAULT '{}',
    cost_tracking JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- LLM messages
CREATE TABLE IF NOT EXISTS anythingllm.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    conversation_id UUID REFERENCES anythingllm.conversations(id) ON DELETE CASCADE,
    role VARCHAR(20) CHECK (role IN ('user', 'assistant', 'system', 'tool')),
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    tool_calls JSONB DEFAULT '[]',
    token_count INTEGER DEFAULT 0,
    model VARCHAR(255),
    cost DECIMAL(10, 6) DEFAULT 0.000000,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Function calls tracking
CREATE TABLE IF NOT EXISTS anythingllm.function_calls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    message_id UUID REFERENCES anythingllm.messages(id) ON DELETE CASCADE,
    tool_name VARCHAR(255) NOT NULL,
    arguments JSONB DEFAULT '{}',
    result JSONB DEFAULT '{}',
    execution_time_ms INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending', -- pending, completed, failed
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- ANYTHINGLLM TOOLS AND INTEGRATIONS
-- =====================================================

-- Tool definitions
CREATE TABLE IF NOT EXISTS anythingllm.tools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    tool_type VARCHAR(50) NOT NULL, -- function, api, webhook, custom
    configuration JSONB NOT NULL, -- Tool-specific config
    is_enabled BOOLEAN DEFAULT TRUE,
    is_public BOOLEAN DEFAULT FALSE,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- External API integrations
CREATE TABLE IF NOT EXISTS anythingllm.integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    integration_type VARCHAR(100) NOT NULL, -- api_key, oauth, webhook
    endpoint TEXT NOT NULL,
    configuration JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    last_sync TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- PROMPT MANAGEMENT
-- =====================================================

-- Prompt templates
CREATE TABLE IF NOT EXISTS anythingllm.prompt_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100), -- coding, writing, analysis, creative
    description TEXT,
    template TEXT NOT NULL,
    variables JSONB DEFAULT '{}', -- Template variables definition
    is_public BOOLEAN DEFAULT TRUE,
    is_favorite BOOLEAN DEFAULT FALSE,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Fine-tuned prompts
CREATE TABLE IF NOT EXISTS anythingllm.fine_tuned_prompts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    base_model VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    training_data_info JSONB DEFAULT '{}',
    model_file_path TEXT,
    metrics JSONB DEFAULT '{}', -- Performance metrics
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- USAGE ANALYTICS
-- =====================================================

-- Usage tracking
CREATE TABLE IF NOT EXISTS anythingllm.usage_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    model_id UUID REFERENCES anythingllm.models(id) ON DELETE SET NULL,
    tool_id UUID REFERENCES anythingllm.tools(id) ON DELETE SET NULL,
    usage_type VARCHAR(50) NOT NULL, -- conversation, tool_call, embedding, etc.
    token_count INTEGER DEFAULT 0,
    cost DECIMAL(10, 6) DEFAULT 0.000000,
    response_time_ms INTEGER,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Performance monitoring
CREATE TABLE IF NOT EXISTS anythingllm.performance_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'anythingllm',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    model_id UUID REFERENCES anythingllm.models(id) ON DELETE CASCADE,
    metric_name VARCHAR(100) NOT NULL, -- latency, throughput, error_rate, etc.
    metric_value DECIMAL(10, 6),
    unit VARCHAR(50), -- ms, requests/min, %, etc.
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- CREATE INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_anythingllm_models_blueprint_id ON anythingllm.models(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_models_provider ON anythingllm.models(provider);
CREATE INDEX IF NOT EXISTS idx_anythingllm_models_active ON anythingllm.models(is_active);
CREATE INDEX IF NOT EXISTS idx_anythingllm_workflows_blueprint_id ON anythingllm.workflows(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_workflows_profile_id ON anythingllm.workflows(profile_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_workflows_public ON anythingllm.workflows(is_public);
CREATE INDEX IF NOT EXISTS idx_anythingllm_conversations_blueprint_id ON anythingllm.conversations(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_conversations_profile_id ON anythingllm.conversations(profile_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_messages_conversation_id ON anythingllm.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_messages_created_at ON anythingllm.messages(created_at);
CREATE INDEX IF NOT EXISTS idx_anythingllm_function_calls_message_id ON anythingllm.function_calls(message_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_tools_blueprint_id ON anythingllm.tools(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_tools_enabled ON anythingllm.tools(is_enabled);
CREATE INDEX IF NOT EXISTS idx_anythingllm_integrations_blueprint_id ON anythingllm.integrations(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_prompt_templates_blueprint_id ON anythingllm.prompt_templates(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_prompt_templates_category ON anythingllm.prompt_templates(category);
CREATE INDEX IF NOT EXISTS idx_anythingllm_prompt_templates_public ON anythingllm.prompt_templates(is_public);
CREATE INDEX IF NOT EXISTS idx_anythingllm_usage_analytics_blueprint_id ON anythingllm.usage_analytics(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_anythingllm_performance_metrics_model_id ON anythingllm.performance_metrics(model_id);

-- =====================================================
-- RLS POLICIES
-- =====================================================

-- Enable RLS on all AnythingLLM tables
ALTER TABLE anythingllm.models ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.function_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.tools ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.prompt_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.fine_tuned_prompts ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.usage_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE anythingllm.performance_metrics ENABLE ROW LEVEL SECURITY;

-- Service role policies
CREATE POLICY "Allow service role full access to anythingllm_models" ON anythingllm.models
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to anythingllm_workflows" ON anythingllm.workflows
    FOR ALL USING (auth.role() = 'service_role');

-- Authenticated user policies
CREATE POLICY "Allow authenticated users to manage own models" ON anythingllm.models
    FOR ALL USING (profile_id IN (
        SELECT id FROM public.blueprint_profiles 
        WHERE supabase_user_id = auth.uid()
    ));

CREATE POLICY "Allow authenticated users to manage own workflows" ON anythingllm.workflows
    FOR ALL USING (profile_id IN (
        SELECT id FROM public.blueprint_profiles 
        WHERE supabase_user_id = auth.uid()
    ));

CREATE POLICY "Allow authenticated users to manage own conversations" ON anythingllm.conversations
    FOR ALL USING (profile_id IN (
        SELECT id FROM public.blueprint_profiles 
        WHERE supabase_user_id = auth.uid()
    ));

CREATE POLICY "Allow authenticated users to manage own tools" ON anythingllm.tools
    FOR ALL USING (profile_id IN (
        SELECT id FROM public.blueprint_profiles 
        WHERE supabase_user_id = auth.uid()
    ));

-- Public access policies
CREATE POLICY "Allow public read access to anythingllm_prompt_templates" ON anythingllm.prompt_templates
    FOR SELECT USING (is_public = TRUE);

CREATE POLICY "Allow public read access to public anythingllm_workflows" ON anythingllm.workflows
    FOR SELECT USING (is_public = TRUE);

-- =====================================================
-- DEFAULT MODELS AND WORKFLOWS
-- =====================================================

-- Insert default models
INSERT INTO anythingllm.models (blueprint_id, profile_id, name, provider, model_id, model_type, max_tokens, supports_tools, supports_vision, supports_streaming, parameters) VALUES
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'GPT-4o Mini', 'openai', 'gpt-4o-mini', 'chat', 128000, TRUE, FALSE, TRUE, '{"temperature": 0.7, "max_tokens": 4096}'),
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'GPT-4o', 'openai', 'gpt-4o', 'chat', 128000, TRUE, TRUE, TRUE, '{"temperature": 0.7, "max_tokens": 4096}'),
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'Claude 3.5 Sonnet', 'anthropic', 'claude-3-5-sonnet', 'chat', 200000, TRUE, TRUE, TRUE, '{"temperature": 0.7, "max_tokens": 4096}'),
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'Text Embedding 3 Small', 'openai', 'text-embedding-3-small', 'embedding', 8191, FALSE, FALSE, FALSE, '{"dimensions": 1536}'),
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'Claude 3.5 Haiku', 'anthropic', 'claude-3-5-haiku', 'chat', 200000, TRUE, FALSE, TRUE, '{"temperature": 0.7, "max_tokens": 4096}')
ON CONFLICT DO NOTHING;

-- Insert default workflow templates
INSERT INTO anythingllm.workflows (blueprint_id, profile_id, name, description, model_id, system_prompt, workflow_definition, is_template, is_public) VALUES
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'General Chat', 'General purpose conversation workflow', (SELECT id FROM anythingllm.models WHERE model_id = 'gpt-4o-mini' LIMIT 1), 'You are a helpful AI assistant. Respond naturally and helpfully to user queries.', '{"steps": [{"type": "llm_call", "model": "{{model}}", "messages": "{{conversation_history}}"}]}', TRUE, TRUE),
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'Code Analysis', 'Analyze code and provide insights', (SELECT id FROM anythingllm.models WHERE model_id = 'gpt-4o' LIMIT 1), 'You are an expert software engineer. Analyze the provided code and suggest improvements, identify potential bugs, and explain complex patterns.', '{"steps": [{"type": "llm_call", "model": "{{model}}", "messages": [{"role": "user", "content": "Analyze this code: {{code}}"}]}]}', TRUE, TRUE),
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'Creative Writing', 'Creative writing and brainstorming', (SELECT id FROM anythingllm.models WHERE model_id = 'claude-3-5-sonnet' LIMIT 1), 'You are a creative writing assistant. Help users brainstorm ideas, write engaging content, and provide creative suggestions.', '{"steps": [{"type": "llm_call", "model": "{{model}}", "messages": [{"role": "user", "content": "Help me with creative writing: {{prompt}}"}]}]}', TRUE, TRUE)
ON CONFLICT DO NOTHING;

-- Insert default prompt templates
INSERT INTO anythingllm.prompt_templates (blueprint_id, profile_id, name, category, description, template, variables, is_public) VALUES
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'Code Review', 'coding', 'Review code for best practices and potential issues', 'You are a senior software engineer. Review this code for:\n\n- Code quality and best practices\n- Potential bugs and security issues\n- Performance optimizations\n- Code organization and maintainability\n\nCode:\n{{code}}', '{"code": "string", "language": "string", "focus_area": "string"}', TRUE),
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'Debug Assistant', 'coding', 'Help debug code issues', 'You are an expert debugger. Help me identify and fix this issue:\n\n{{context}}\n\n{{error_description}}', '{"context": "string", "error_description": "string", "stack_trace": "string"}', TRUE),
('anythingllm', (SELECT id FROM public.blueprint_profiles WHERE blueprint_id = 'anythingllm' AND username = 'admin' LIMIT 1), 'API Documentation', 'writing', 'Generate API documentation', 'Generate comprehensive API documentation for:\n\n{{code_snippet}}\n\nInclude:\n- Function descriptions\n- Parameter details\n- Example usage\n- Error handling\n\n{{format}} style documentation.', '{"code_snippet": "string", "format": "string", "api_version": "string"}', TRUE)
ON CONFLICT DO NOTHING;

-- =====================================================
-- INSERT ANYTHINGLLM SETTINGS
-- =====================================================

INSERT INTO public.blueprint_settings (blueprint_id, key, value, is_public, category, description) VALUES
('anythingllm', 'DEFAULT_MODEL', 'gpt-4o-mini', true, 'llm', 'Default LLM model for conversations'),
('anythingllm', 'MAX_CONVERSATION_LENGTH', '50', true, 'llm', 'Maximum messages per conversation'),
('anythingllm', 'ENABLE_TOOLS', 'true', true, 'llm', 'Enable tool/function calling'),
('anythingllm', 'STREAM_RESPONSES', 'true', true, 'llm', 'Enable streaming responses'),
('anythingllm', 'COST_TRACKING', 'true', true, 'analytics', 'Enable per-conversation cost tracking'),
('anythingllm', 'DEFAULT_TEMPERATURE', '0.7', true, 'llm', 'Default temperature for LLM responses'),
('anythingllm', 'MAX_TOKENS_PER_REQUEST', '4096', true, 'limits', 'Maximum tokens per LLM request'),
('anythingllm', 'ENABLE_WORKFLOW_TEMPLATES', 'true', true, 'features', 'Enable workflow template system'),
('anythingllm', 'ENABLE_FINE_TUNING', 'false', true, 'features', 'Enable model fine-tuning interface'),
('anythingllm', 'RATE_LIMIT_REQUESTS_PER_MINUTE', '60', true, 'limits', 'Rate limit per user per minute'),
('anythingllm', 'ENABLE_REALTIME_UPDATES', 'true', true, 'features', 'Enable real-time conversation updates'),
('anythingllm', 'ENABLE_ANALYTICS_DASHBOARD', 'true', true, 'analytics', 'Enable usage analytics dashboard')
ON CONFLICT (blueprint_id, key) DO NOTHING;

-- =====================================================
-- LOG COMPLETION
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'AnythingLLM schema completed successfully';
    RAISE NOTICE 'Tables: models, workflows, conversations, messages, function_calls, tools, integrations, prompt_templates, fine_tuned_prompts, usage_analytics, performance_metrics';
    RAISE NOTICE 'Default models configured: GPT-4o Mini, GPT-4o, Claude 3.5 Sonnet, Claude 3.5 Haiku';
    RAISE NOTICE 'Default workflows created: General Chat, Code Analysis, Creative Writing';
    RAISE NOTICE 'Default prompt templates added for code review, debugging, and documentation';
    RAISE NOTICE 'RLS enabled on all tables';
END $$;