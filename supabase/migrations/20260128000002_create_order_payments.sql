-- Create order_payments table for multi-tender support
CREATE TABLE IF NOT EXISTS order_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_group_id UUID NOT NULL REFERENCES order_groups(id) ON DELETE CASCADE,
    payment_method TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    reference TEXT, -- e.g. Last 4 digits
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by TEXT -- optional, user id
);

-- Index for querying payments by order
CREATE INDEX IF NOT EXISTS idx_order_payments_group ON order_payments(order_group_id);
