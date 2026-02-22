ALTER TABLE "order_items" 
ADD COLUMN "print_status" text DEFAULT 'pending';

-- Update existing items to 'success' so they don't appear as unprinted
UPDATE "order_items" SET "print_status" = 'success';

ALTER TABLE "order_items"
ALTER COLUMN "print_status" SET NOT NULL;

ALTER TABLE "order_items"
ADD CONSTRAINT "order_items_print_status_check"
CHECK (print_status IN ('pending', 'success', 'failed'));
