-- Fix Admin Permissions: Ensure 'Admin' role has 'admin_all' permission
DO $$
DECLARE
    v_role_id uuid;
BEGIN
    -- 1. Find the role_id for 'Admin'
    SELECT id INTO v_role_id FROM shop_roles WHERE name = 'Admin' LIMIT 1;

    -- 2. If role exists, insert 'admin_all' if not present
    IF v_role_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM shop_role_permissions 
            WHERE role_id = v_role_id AND permission_key = 'admin_all'
        ) THEN
            INSERT INTO shop_role_permissions (role_id, permission_key)
            VALUES (v_role_id, 'admin_all');
        END IF;
        
        -- Optional: Add standard permissions for testing just in case 'admin_all' check fails on client side for some reason (though code says it works)
        -- Ideally, admin_all is enough. 
    END IF;
END $$;
