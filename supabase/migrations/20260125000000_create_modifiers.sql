-- Create Modifier Groups table
CREATE TABLE IF NOT EXISTS modifier_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    selection_type TEXT NOT NULL CHECK (selection_type IN ('single', 'multiple')),
    min_selection INTEGER DEFAULT 0,
    max_selection INTEGER,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for modifier_groups
ALTER TABLE modifier_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read modifier_groups" ON modifier_groups FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert modifier_groups" ON modifier_groups FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can update modifier_groups" ON modifier_groups FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can delete modifier_groups" ON modifier_groups FOR DELETE USING (auth.role() = 'authenticated');


-- Create Modifiers table (The actual options like "Half Sugar", "Pearl")
CREATE TABLE IF NOT EXISTS modifiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES modifier_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price_adjustment NUMERIC DEFAULT 0, -- Extra cost, e.g., +5
    is_sold_out BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for modifiers
ALTER TABLE modifiers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read modifiers" ON modifiers FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert modifiers" ON modifiers FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can update modifiers" ON modifiers FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can delete modifiers" ON modifiers FOR DELETE USING (auth.role() = 'authenticated');


-- Create Join Table: Menu Items <-> Modifier Groups
-- This allows reusable modifier groups (e.g., "Sugar Level" used by 50 tea drinks)
CREATE TABLE IF NOT EXISTS menu_item_modifier_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    modifier_group_id UUID NOT NULL REFERENCES modifier_groups(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(menu_item_id, modifier_group_id)
);

-- Enable RLS for join table
ALTER TABLE menu_item_modifier_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read menu_item_modifier_groups" ON menu_item_modifier_groups FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert menu_item_modifier_groups" ON menu_item_modifier_groups FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can update menu_item_modifier_groups" ON menu_item_modifier_groups FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can delete menu_item_modifier_groups" ON menu_item_modifier_groups FOR DELETE USING (auth.role() = 'authenticated');
