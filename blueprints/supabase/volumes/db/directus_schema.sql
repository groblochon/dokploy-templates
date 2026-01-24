-- =====================================================
-- DIRECTUS CMS SCHEMA
-- =====================================================
-- Schema for directus headless CMS integration with Supabase
-- =====================================================

-- Create blueprint-specific schema
SELECT public.create_blueprint_schema('directus');

-- =====================================================
-- DIRECTUS-CORE TABLES
-- =====================================================

-- Content types (dynamic schema)
CREATE TABLE IF NOT EXISTS directus.content_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    singular_name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    color VARCHAR(20),
    is_system BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Content fields definition
CREATE TABLE IF NOT EXISTS directus.content_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type_id UUID REFERENCES directus.content_types(id) ON DELETE CASCADE,
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    field_name VARCHAR(100) NOT NULL,
    field_type VARCHAR(50) NOT NULL, -- text, number, date, relationship, etc.
    interface VARCHAR(50) NOT NULL, -- text-input, dropdown, checkbox, etc.
    options JSONB DEFAULT '{}',
    default_value TEXT,
    is_required BOOLEAN DEFAULT FALSE,
    is_unique BOOLEAN DEFAULT FALSE,
    is_primary_key BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Content items (the actual data)
CREATE TABLE IF NOT EXISTS directus.items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    content_type_id UUID REFERENCES directus.content_types(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'published', -- draft, published, archived
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Content item data (EAV pattern)
CREATE TABLE IF NOT EXISTS directus.item_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    item_id UUID REFERENCES directus.items(id) ON DELETE CASCADE,
    field_id UUID REFERENCES directus.content_fields(id) ON DELETE CASCADE,
    text_value TEXT,
    number_value NUMERIC,
    date_value TIMESTAMP WITH TIME ZONE,
    boolean_value BOOLEAN,
    json_value JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- DIRECTUS MEDIA AND FILES
-- =====================================================

-- File storage metadata
CREATE TABLE IF NOT EXISTS directus.files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    filename_original VARCHAR(500) NOT NULL,
    filename_disk VARCHAR(500) NOT NULL,
    mime_type VARCHAR(200),
    file_size BIGINT DEFAULT 0,
    storage_adapter VARCHAR(100) DEFAULT 'supabase',
    storage_path TEXT,
    metadata JSONB DEFAULT '{}',
    uploaded_by UUID REFERENCES public.blueprint_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- File relationships to content
CREATE TABLE IF NOT EXISTS directus.file_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    file_id UUID REFERENCES directus.files(id) ON DELETE CASCADE,
    item_id UUID REFERENCES directus.items(id) ON DELETE CASCADE,
    collection_name VARCHAR(100) DEFAULT 'files',
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- DIRECTUS PERMISSIONS
-- =====================================================

-- Roles and permissions
CREATE TABLE IF NOT EXISTS directus.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User roles
CREATE TABLE IF NOT EXISTS directus.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    role_id UUID REFERENCES directus.roles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(profile_id, role_id)
);

-- Permissions
CREATE TABLE IF NOT EXISTS directus.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    action VARCHAR(100) NOT NULL, -- create, read, update, delete, etc.
    collection VARCHAR(100) NOT NULL, -- content_types table name
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Role permissions mapping
CREATE TABLE IF NOT EXISTS directus.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    role_id UUID REFERENCES directus.roles(id) ON DELETE CASCADE,
    permission_id UUID REFERENCES directus.permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(role_id, permission_id)
);

-- =====================================================
-- DIRECTUS WEBHOOKS
-- =====================================================

-- Webhook configurations
CREATE TABLE IF NOT EXISTS directus.webhooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    profile_id UUID REFERENCES public.blueprint_profiles(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    url TEXT NOT NULL,
    method VARCHAR(10) DEFAULT 'POST',
    events JSONB DEFAULT '[]', -- Array of events to trigger on
    headers JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    last_triggered TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Webhook delivery logs
CREATE TABLE IF NOT EXISTS directus.webhook_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blueprint_id VARCHAR(100) DEFAULT 'directus',
    webhook_id UUID REFERENCES directus.webhooks(id) ON DELETE CASCADE,
    event_data JSONB,
    response_code INTEGER,
    response_body TEXT,
    response_time_ms INTEGER,
    status VARCHAR(50) DEFAULT 'pending', -- pending, success, failed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- CREATE INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_directus_content_types_blueprint_id ON directus.content_types(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_directus_content_fields_content_type_id ON directus.content_fields(content_type_id);
CREATE INDEX IF NOT EXISTS idx_directus_items_content_type_id ON directus.items(content_type_id);
CREATE INDEX IF NOT EXISTS idx_directus_items_profile_id ON directus.items(profile_id);
CREATE INDEX IF NOT EXISTS idx_directus_items_status ON directus.items(status);
CREATE INDEX IF NOT EXISTS idx_directus_item_data_item_id ON directus.item_data(item_id);
CREATE INDEX IF NOT EXISTS idx_directus_files_profile_id ON directus.files(profile_id);
CREATE INDEX IF NOT EXISTS idx_directus_file_relationships_item_id ON directus.file_relationships(item_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_profile_id ON directus.user_roles(profile_id);
CREATE INDEX IF NOT EXISTS idx_directus_webhooks_profile_id ON directus.webhooks(profile_id);
CREATE INDEX IF NOT EXISTS idx_directus_webhook_logs_webhook_id ON directus.webhook_logs(webhook_id);

-- =====================================================
-- DEFAULT DATA
-- =====================================================

-- Insert default content types
INSERT INTO directus.content_types (blueprint_id, name, singular_name, description, icon, color, sort_order) VALUES
('directus', 'Pages', 'Page', 'Static page content with rich text and media', 'article', '#6366f1', 1),
('directus', 'Posts', 'Post', 'Blog posts with metadata and categorization', 'news', '#3b82f6', 2),
('directus', 'Products', 'Product', 'Product catalog with pricing and variants', 'shopping-bag', '#10b981', 3)
ON CONFLICT DO NOTHING;

-- Insert default fields for Pages
INSERT INTO directus.content_fields (content_type_id, field_name, field_type, interface, is_required, sort_order) VALUES
((SELECT id FROM directus.content_types WHERE name = 'Pages' AND blueprint_id = 'directus'), 'title', 'text', 'text-input', TRUE, 1),
((SELECT id FROM directus.content_types WHERE name = 'Pages' AND blueprint_id = 'directus'), 'content', 'text', 'wysiwyg', TRUE, 2),
((SELECT id FROM directus.content_types WHERE name = 'Pages' AND blueprint_id = 'directus'), 'slug', 'text', 'text-input', TRUE, 3),
((SELECT id FROM directus.content_types WHERE name = 'Pages' AND blueprint_id = 'directus'), 'meta_description', 'text', 'text-input', FALSE, 4),
((SELECT id FROM directus.content_types WHERE name = 'Pages' AND blueprint_id = 'directus'), 'meta_keywords', 'text', 'tags-input', FALSE, 5)
ON CONFLICT DO NOTHING;

-- Insert default roles
INSERT INTO directus.roles (blueprint_id, name, description, icon, sort_order) VALUES
('directus', 'Administrator', 'Full system access with all permissions', 'admin', 1),
('directus', 'Editor', 'Can create and edit content', 'edit', 2),
('directus', 'Viewer', 'Read-only access to content', 'eye', 3)
ON CONFLICT DO NOTHING;

-- Insert default permissions
INSERT INTO directus.permissions (blueprint_id, action, collection, description) VALUES
('directus', 'create', 'pages', 'Create new pages'),
('directus', 'read', 'pages', 'View page content'),
('directus', 'update', 'pages', 'Edit existing pages'),
('directus', 'delete', 'pages', 'Delete pages'),
('directus', 'create', 'posts', 'Create new posts'),
('directus', 'read', 'posts', 'View post content'),
('directus', 'update', 'posts', 'Edit existing posts'),
('directus', 'delete', 'posts', 'Delete posts'),
('directus', 'create', 'products', 'Create new products'),
('directus', 'read', 'products', 'View product information'),
('directus', 'update', 'products', 'Edit product details'),
('directus', 'delete', 'products', 'Delete products')
ON CONFLICT DO NOTHING;

-- Grant admin role all permissions
INSERT INTO directus.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM directus.roles r, directus.permissions p 
WHERE r.blueprint_id = 'directus' AND p.blueprint_id = 'directus'
ON CONFLICT DO NOTHING;

-- =====================================================
-- INSERT DEFAULT DIRECTUS SETTINGS
-- =====================================================

INSERT INTO public.blueprint_settings (blueprint_id, key, value, is_public, category, description) VALUES
('directus', 'SITE_NAME', 'Directus CMS', true, 'general', 'Site name displayed in CMS'),
('directus', 'SITE_DESCRIPTION', 'Headless CMS powered by Supabase', true, 'general', 'Site description'),
('directus', 'DEFAULT_LANGUAGE', 'en-US', true, 'localization', 'Default language for content'),
('directus', 'ENABLE_DRAFT_MODE', 'true', true, 'content', 'Enable draft/published workflow'),
('directus', 'ENABLE_VERSIONING', 'true', true, 'content', 'Enable content versioning'),
('directus', 'MAX_UPLOAD_SIZE', '104857600', true, 'limits', 'Maximum file upload size in bytes (100MB)'),
('directus', 'ALLOWED_FILE_TYPES', '["jpg", "jpeg", "png", "gif", "pdf", "doc", "docx"]', true, 'limits', 'Allowed file types for upload'),
('directus', 'ENABLE_WEBHOOKS', 'true', true, 'features', 'Enable webhook support'),
('directus', 'WEBHOOK_TIMEOUT', '30000', true, 'features', 'Webhook timeout in milliseconds'),
('directus', 'ENABLE_REALTIME', 'true', true, 'features', 'Enable real-time content updates'),
('directus', 'CACHE_DURATION', '3600', true, 'performance', 'Content cache duration in seconds')
ON CONFLICT (blueprint_id, key) DO NOTHING;

-- =====================================================
-- LOG COMPLETION
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Directus CMS schema completed successfully';
    RAISE NOTICE 'Tables: content_types, content_fields, items, item_data, files, file_relationships, roles, user_roles, permissions, role_permissions, webhooks, webhook_logs';
    RAISE NOTICE 'Default content types: Pages, Posts, Products';
    RAISE NOTICE 'Default roles: Administrator, Editor, Viewer';
    RAISE NOTICE 'RLS enabled on all content tables';
    RAISE NOTICE 'Webhook support configured';
END $$;