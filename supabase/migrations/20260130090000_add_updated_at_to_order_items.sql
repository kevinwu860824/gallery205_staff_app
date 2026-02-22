-- Add updated_at column to order_items if it doesn't exist
ALTER TABLE order_items 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create a trigger to automatically update updated_at (Optional but good practice)
-- OR just rely on the app to update it. Given the app logic relies on specific update times for 'deletion', letting the app control it is fine, 
-- but having a default is also good.

COMMENT ON COLUMN order_items.updated_at IS 'Timestamp when the item status was last updated (e.g. cancelled)';
