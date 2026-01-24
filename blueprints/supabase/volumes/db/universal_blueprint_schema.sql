-- =====================================================
-- UNIVERSAL POSTGRESQL BLUEPRINT SCHEMA
-- =====================================================
-- This script creates unified schema structure for all PostgreSQL blueprints
-- Designed for integration with Supabase RLS and extensions
-- =====================================================

-- Enable required PostgreSQL extensions for all applications
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =====================================================
-- UNIVERSAL USER PROFILE EXTENSION
-- =====================================================

-- Extended user profiles that work alongside Supabase auth.users
CREATE TABLE IF NOT EXISTS public.blueprint_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supabase_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    blueprint_id VARCHAR(100) NOT NULL,
    username VARCHAR(255) UNIQUE,
    display_name VARCHAR(255),
    avatar_url TEXT,
    role VARCHAR(50) DEFAULT 'user',
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(supabase_user_id, blueprint_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_blueprint_profiles_supabase_id ON public.blueprint_profiles(supabase_user_id);
CREATE INDEX IF NOT EXISTS idx_blueprint_profiles_blueprint_id ON public.blueprint_profiles(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_blueprint_profiles_username ON public.blueprint_profiles(username);

-- =====================================================
-- UNIVERSAL API KEYS MANAGEMENT
-- =====================================================

-- Centralized API keys storage with encryption
CREATE TABLE IF NOT EXISTS public.api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    service_name VARCHAR(100) NOT NULL,
    key_name VARCHAR(255) NOT NULL,
    encrypted_key TEXT,
    key_type VARCHAR(50) DEFAULT 'api_key',
    permissions JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_api_keys_profile_id ON public.api_keys(profile_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_service_name ON public.api_keys(service_name);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON public.api_keys(is_active);

-- =====================================================
-- UNIVERSAL SETTINGS SYSTEM
-- =====================================================

-- Application settings storage
CREATE TABLE IF NOT EXISTS public.blueprint_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) NOT NULL,
    key VARCHAR(255) NOT NULL,
    value TEXT,
    encrypted_value TEXT,
    is_encrypted BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT FALSE,
    category VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(blueprint_id, key)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_blueprint_settings_blueprint_id ON public.blueprint_settings(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_blueprint_settings_key ON public.blueprint_settings(key);
CREATE INDEX IF NOT EXISTS idx_blueprint_settings_category ON public.blueprint_settings(category);
CREATE INDEX IF NOT EXISTS idx_blueprint_settings_public ON public.blueprint_settings(is_public);

-- =====================================================
-- TRIGGERS FOR UPDATED_AT
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to all tables
CREATE TRIGGER update_blueprint_profiles_updated_at
    BEFORE UPDATE ON public.blueprint_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_api_keys_updated_at
    BEFORE UPDATE ON public.api_keys
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_blueprint_settings_updated_at
    BEFORE UPDATE ON public.blueprint_settings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- RLS POLICIES
-- =====================================================

-- Enable RLS on universal tables
ALTER TABLE public.blueprint_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blueprint_settings ENABLE ROW LEVEL SECURITY;

-- Service role policies (full access)
CREATE POLICY "Allow service role full access to blueprint_profiles" ON public.blueprint_profiles
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to api_keys" ON public.api_keys
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access to blueprint_settings" ON public.blueprint_settings
    FOR ALL USING (auth.role() = 'service_role');

-- Authenticated user policies (own data access)
CREATE POLICY "Allow authenticated users to manage own profile" ON public.blueprint_profiles
    FOR ALL USING (auth.uid() = supabase_user_id);

CREATE POLICY "Allow authenticated users to manage own api_keys" ON public.api_keys
    FOR ALL USING (profile_id IN (
        SELECT id FROM public.blueprint_profiles 
        WHERE supabase_user_id = auth.uid()
    ));

CREATE POLICY "Allow authenticated users to read public settings" ON public.blueprint_settings
    FOR SELECT USING (is_public = TRUE);

-- Anonymous policies (public data access)
CREATE POLICY "Allow anonymous read access to public settings" ON public.blueprint_settings
    FOR SELECT USING (is_public = TRUE);

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

-- Function to get or create blueprint profile
CREATE OR REPLACE FUNCTION public.get_or_create_blueprint_profile(
    blueprint_id_param TEXT,
    user_id UUID DEFAULT auth.uid(),
    username_param TEXT DEFAULT NULL,
    display_name_param TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    profile_id UUID;
BEGIN
    -- Try to find existing profile
    SELECT id INTO profile_id
    FROM public.blueprint_profiles
    WHERE supabase_user_id = user_id AND blueprint_id = blueprint_id_param;
    
    -- If not found, create new profile
    IF profile_id IS NULL THEN
        INSERT INTO public.blueprint_profiles (
            supabase_user_id, 
            blueprint_id,
            username,
            display_name
        ) VALUES (
            user_id, 
            blueprint_id_param,
            COALESCE(username_param, blueprint_id_param || '_' || substr(user_id::text, 1, 8)),
            COALESCE(display_name_param, 'User of ' || blueprint_id_param)
        )
        RETURNING id INTO profile_id;
    END IF;
    
    RETURN profile_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to store encrypted API key
CREATE OR REPLACE FUNCTION public.store_api_key(
    service_name_param TEXT,
    key_name_param TEXT,
    key_value_param TEXT,
    profile_id_param UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    key_id UUID;
    target_profile_id UUID;
BEGIN
    -- Use provided profile_id or get current user's profile
    IF profile_id_param IS NOT NULL THEN
        target_profile_id := profile_id_param;
    ELSE
        SELECT id INTO target_profile_id
        FROM public.blueprint_profiles
        WHERE supabase_user_id = auth.uid()
        LIMIT 1;
    END IF;
    
    -- Insert or update API key
    INSERT INTO public.api_keys (
        profile_id,
        service_name,
        key_name,
        encrypted_key,
        key_type
    ) VALUES (
        target_profile_id,
        service_name_param,
        key_name_param,
        key_value_param, -- Will be encrypted by application
        'api_key'
    )
    RETURNING id INTO key_id;
    
    RETURN key_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get decrypted API key
CREATE OR REPLACE FUNCTION public.get_api_key(
    service_name_param TEXT,
    key_name_param TEXT
)
RETURNS TEXT AS $$
DECLARE
    decrypted_key TEXT;
BEGIN
    SELECT encrypted_key INTO decrypted_key
    FROM public.api_keys ak
    JOIN public.blueprint_profiles bp ON ak.profile_id = bp.id
    WHERE 
        ak.service_name = service_name_param
        AND ak.key_name = key_name_param
        AND ak.is_active = TRUE
        AND bp.supabase_user_id = auth.uid()
        AND bp.blueprint_id = ak.service_name; -- Assuming service name matches blueprint
    
    RETURN decrypted_key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update blueprint settings
CREATE OR REPLACE FUNCTION public.update_blueprint_setting(
    blueprint_id_param TEXT,
    setting_key_param TEXT,
    setting_value_param TEXT,
    is_encrypted_param BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.blueprint_settings
    SET 
        value = CASE WHEN is_encrypted_param THEN NULL ELSE setting_value_param END,
        encrypted_value = CASE WHEN is_encrypted_param THEN setting_value_param ELSE NULL END,
        is_encrypted = is_encrypted_param,
        updated_at = NOW()
    WHERE blueprint_id = blueprint_id_param AND key = setting_key_param;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- BLUEPRINT-SPECIFIC SCHEMA CREATION HELPERS
-- =====================================================

-- Function to create blueprint-specific schema
CREATE OR REPLACE FUNCTION public.create_blueprint_schema(
    blueprint_id_param TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    schema_name TEXT;
BEGIN
    schema_name := blueprint_id_param;
    
    -- Create schema
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);
    
    -- Create admin user
    EXECUTE format('CREATE USER IF NOT EXISTS supabase_%s_admin WITH PASSWORD $1', schema_name, quote_literal('${POSTGRES_PASSWORD}'));
    
    -- Grant permissions
    EXECUTE format('GRANT ALL PRIVILEGES ON SCHEMA %I TO supabase_%s_admin', schema_name, schema_name);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO supabase_%s_admin', schema_name, schema_name);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA %I TO supabase_%s_admin', schema_name, schema_name);
    EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA %I TO supabase_%s_admin', schema_name, schema_name);
    
    -- Grant authenticated user permissions
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO authenticated', schema_name);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA %I TO authenticated', schema_name);
    EXECUTE format('GRANT USAGE ON ALL SEQUENCES IN SCHEMA %I TO authenticated', schema_name);
    
    -- Grant anonymous user permissions for public data
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO anon', schema_name);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO anon', schema_name);
    
    -- Set default permissions for future objects
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON TABLES TO supabase_%s_admin', schema_name, schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, INSERT, UPDATE ON TABLES TO authenticated', schema_name, schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT USAGE ON SEQUENCES TO authenticated', schema_name, schema_name);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- DEFAULT SETTINGS FOR ALL BLUEPRINTS
-- =====================================================

-- Common settings that most blueprints might need
INSERT INTO public.blueprint_settings (blueprint_id, key, value, is_public, category, description) VALUES
('universal', 'MAX_FILE_SIZE', '52428800', true, 'limits', 'Maximum file upload size in bytes (50MB)'),
('universal', 'MAX_CONCURRENT_USERS', '100', true, 'limits', 'Maximum concurrent users per blueprint'),
('universal', 'ENABLE_RLS', 'true', true, 'security', 'Enable Row Level Security'),
('universal', 'POOLER_ENABLED', 'true', true, 'database', 'Enable connection pooling'),
('universal', 'VECTOR_SEARCH_ENABLED', 'false', true, 'features', 'Enable vector search capabilities'),
('universal', 'REALTIME_ENABLED', 'false', true, 'features', 'Enable real-time subscriptions'),
('universal', 'STORAGE_ENABLED', 'false', true, 'features', 'Enable file storage integration'),
('universal', 'AUTH_ENABLED', 'true', true, 'features', 'Enable Supabase authentication')
ON CONFLICT (blueprint_id, key) DO NOTHING;

-- =====================================================
-- FINAL SETUP AND PERMISSIONS
-- =====================================================

-- Grant permissions on public schema tables
GRANT USAGE ON SCHEMA public TO authenticated, anon, supabase_auth_admin, supabase_functions_admin;
GRANT SELECT, INSERT, UPDATE ON public.blueprint_profiles TO authenticated;
GRANT SELECT ON public.blueprint_settings TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE ON public.api_keys TO authenticated;

-- Set default permissions for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO anon;

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'Universal PostgreSQL blueprint schema completed successfully';
    RAISE NOTICE 'Tables: blueprint_profiles, api_keys, blueprint_settings';
    RAISE NOTICE 'Extensions: vector, pgcrypto, uuid-ossp, pg_trgm';
    RAISE NOTICE 'Functions: get_or_create_blueprint_profile, store_api_key, get_api_key, update_blueprint_setting, create_blueprint_schema';
    RAISE NOTICE 'RLS enabled on all tables';
    RAISE NOTICE 'Ready for blueprint-specific schema creation';
END $$;