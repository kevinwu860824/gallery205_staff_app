-- Add open_id to link orders and payments to cash register shifts
ALTER TABLE order_groups ADD COLUMN IF NOT EXISTS open_id UUID;
ALTER TABLE order_payments ADD COLUMN IF NOT EXISTS open_id UUID;

CREATE INDEX IF NOT EXISTS idx_order_groups_open_id ON order_groups(open_id);
CREATE INDEX IF NOT EXISTS idx_order_payments_open_id ON order_payments(open_id);
