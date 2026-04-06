-- Add shop_id to order_items for Realtime security filtering
-- Fixes: order_items Realtime subscriptions had no shop_id filter,
--        allowing cross-shop data leakage in Admin Web live views.

-- 1. Add column
ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS shop_id UUID REFERENCES shops(id);

-- 2. Backfill existing rows
UPDATE order_items oi
SET shop_id = og.shop_id
FROM order_groups og
WHERE oi.order_group_id = og.id
  AND oi.shop_id IS NULL;

-- 3. Index for Realtime filter + RLS
CREATE INDEX IF NOT EXISTS idx_order_items_shop_id
  ON order_items(shop_id);

-- 4. Trigger: auto-populate shop_id on INSERT
CREATE OR REPLACE FUNCTION fn_set_order_item_shop_id()
RETURNS TRIGGER AS $$
BEGIN
  SELECT shop_id INTO NEW.shop_id
  FROM order_groups
  WHERE id = NEW.order_group_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_order_items_shop_id ON order_items;
CREATE TRIGGER trg_order_items_shop_id
  BEFORE INSERT ON order_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_set_order_item_shop_id();

-- 5. RLS policy using shop_id directly (required for Realtime filter to work)
DROP POLICY IF EXISTS "order_items_shop_id_select" ON order_items;
CREATE POLICY "order_items_shop_id_select" ON order_items
  FOR SELECT
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));
