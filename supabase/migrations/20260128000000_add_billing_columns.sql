-- Add billing related columns to order_groups
ALTER TABLE order_groups
ADD COLUMN IF NOT EXISTS service_fee_rate INTEGER DEFAULT 10,
ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS final_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS payment_method TEXT;
