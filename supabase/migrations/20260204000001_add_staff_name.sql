-- Add staff_name column to order_groups table
ALTER TABLE order_groups ADD COLUMN IF NOT EXISTS staff_name text;

-- Comment for clarity
COMMENT ON COLUMN order_groups.staff_name IS 'Name of the staff member who created the order';
