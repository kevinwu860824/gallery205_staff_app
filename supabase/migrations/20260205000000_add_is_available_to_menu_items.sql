-- Add is_available column to menu_items table
alter table menu_items 
add column if not exists is_available boolean default true;

-- Update existing rows to true
update menu_items set is_available = true where is_available is null;
