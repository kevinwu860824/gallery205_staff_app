-- Add modifiers column to order_items to store selected options snapshot
-- We use JSONB to store the array of selected modifiers: [{name: "Half Sugar", price: 0}, ...]

ALTER TABLE "order_items" 
ADD COLUMN IF NOT EXISTS "modifiers" JSONB DEFAULT '[]'::jsonb;
