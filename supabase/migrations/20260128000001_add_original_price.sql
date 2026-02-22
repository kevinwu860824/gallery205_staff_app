-- Add original_price to order_items to support restoring price after "Treat" (Comp)
ALTER TABLE order_items
ADD COLUMN IF NOT EXISTS original_price NUMERIC;
