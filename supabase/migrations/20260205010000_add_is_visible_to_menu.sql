-- Add is_visible to menu_categories
alter table menu_categories
add column if not exists is_visible boolean default true;

-- Add is_visible to menu_items
alter table menu_items
add column if not exists is_visible boolean default true;

-- Update existing rows (optional, default handles new rows but good for existing nulls if any)
update menu_categories set is_visible = true where is_visible is null;
update menu_items set is_visible = true where is_visible is null;
