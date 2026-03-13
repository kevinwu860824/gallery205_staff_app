-- ============================================================
-- FIX: RLS Shop Isolation
-- 問題：所有 table 的 policy 只檢查 auth.role() = 'authenticated'
--       未過濾 shop_id，導致任何登入用戶可存取所有店家資料
-- 修正：透過 user_shop_map 確認用戶屬於該 shop 才允許存取
-- ============================================================

-- 先清除舊 function，避免 CREATE OR REPLACE 因 return type 不符報錯
-- CASCADE 同時刪除依賴此 function 的 policy（下方會重建）
DROP FUNCTION IF EXISTS public.get_user_shop_ids() CASCADE;
DROP FUNCTION IF EXISTS public.get_user_shop_ids_text() CASCADE;

-- Helper function：取得目前登入用戶有權存取的所有 shop_id
-- 使用 SECURITY DEFINER 讓 RLS policy 能查詢 user_shop_map
CREATE OR REPLACE FUNCTION public.get_user_shop_ids()
RETURNS TABLE(shop_id UUID)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT usm.shop_code
  FROM public.user_shop_map usm
  WHERE usm.user_id = auth.uid()
    AND usm.is_active = true;
$$;

-- 同樣支援 text 型態的 shop_id (inventory tables 用 text)
CREATE OR REPLACE FUNCTION public.get_user_shop_ids_text()
RETURNS TABLE(shop_id TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT usm.shop_code::text
  FROM public.user_shop_map usm
  WHERE usm.user_id = auth.uid()
    AND usm.is_active = true;
$$;

-- ============================================================
-- modifier_groups：有直接的 shop_id (UUID)
-- ============================================================
DROP POLICY IF EXISTS "Public read modifier_groups" ON public.modifier_groups;
DROP POLICY IF EXISTS "Authenticated users can insert modifier_groups" ON public.modifier_groups;
DROP POLICY IF EXISTS "Authenticated users can update modifier_groups" ON public.modifier_groups;
DROP POLICY IF EXISTS "Authenticated users can delete modifier_groups" ON public.modifier_groups;

CREATE POLICY "Shop members can read modifier_groups"
  ON public.modifier_groups FOR SELECT
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

CREATE POLICY "Shop members can insert modifier_groups"
  ON public.modifier_groups FOR INSERT
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

CREATE POLICY "Shop members can update modifier_groups"
  ON public.modifier_groups FOR UPDATE
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

CREATE POLICY "Shop members can delete modifier_groups"
  ON public.modifier_groups FOR DELETE
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- modifiers：透過 modifier_groups 取得 shop_id
-- ============================================================
DROP POLICY IF EXISTS "Public read modifiers" ON public.modifiers;
DROP POLICY IF EXISTS "Authenticated users can insert modifiers" ON public.modifiers;
DROP POLICY IF EXISTS "Authenticated users can update modifiers" ON public.modifiers;
DROP POLICY IF EXISTS "Authenticated users can delete modifiers" ON public.modifiers;

CREATE POLICY "Shop members can read modifiers"
  ON public.modifiers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.modifier_groups mg
      WHERE mg.id = modifiers.group_id
        AND mg.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

CREATE POLICY "Shop members can insert modifiers"
  ON public.modifiers FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.modifier_groups mg
      WHERE mg.id = modifiers.group_id
        AND mg.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

CREATE POLICY "Shop members can update modifiers"
  ON public.modifiers FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.modifier_groups mg
      WHERE mg.id = modifiers.group_id
        AND mg.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

CREATE POLICY "Shop members can delete modifiers"
  ON public.modifiers FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.modifier_groups mg
      WHERE mg.id = modifiers.group_id
        AND mg.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

-- ============================================================
-- menu_item_modifier_groups：透過 modifier_groups 取得 shop_id
-- ============================================================
DROP POLICY IF EXISTS "Public read menu_item_modifier_groups" ON public.menu_item_modifier_groups;
DROP POLICY IF EXISTS "Authenticated users can insert menu_item_modifier_groups" ON public.menu_item_modifier_groups;
DROP POLICY IF EXISTS "Authenticated users can update menu_item_modifier_groups" ON public.menu_item_modifier_groups;
DROP POLICY IF EXISTS "Authenticated users can delete menu_item_modifier_groups" ON public.menu_item_modifier_groups;

CREATE POLICY "Shop members can read menu_item_modifier_groups"
  ON public.menu_item_modifier_groups FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.modifier_groups mg
      WHERE mg.id = menu_item_modifier_groups.modifier_group_id
        AND mg.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

CREATE POLICY "Shop members can insert menu_item_modifier_groups"
  ON public.menu_item_modifier_groups FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.modifier_groups mg
      WHERE mg.id = menu_item_modifier_groups.modifier_group_id
        AND mg.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

CREATE POLICY "Shop members can update menu_item_modifier_groups"
  ON public.menu_item_modifier_groups FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.modifier_groups mg
      WHERE mg.id = menu_item_modifier_groups.modifier_group_id
        AND mg.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

CREATE POLICY "Shop members can delete menu_item_modifier_groups"
  ON public.menu_item_modifier_groups FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.modifier_groups mg
      WHERE mg.id = menu_item_modifier_groups.modifier_group_id
        AND mg.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

-- ============================================================
-- tax_settings：shop_id 是 TEXT 型態
-- ============================================================
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.tax_settings;

CREATE POLICY "Shop members can access tax_settings"
  ON public.tax_settings FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()));

-- ============================================================
-- inventory_items：shop_id 是 UUID 型態
-- ============================================================
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.inventory_items;

CREATE POLICY "Shop members can access inventory_items"
  ON public.inventory_items FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- inventory_transactions：shop_id 是 TEXT 型態
-- ============================================================
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.inventory_transactions;

CREATE POLICY "Shop members can access inventory_transactions"
  ON public.inventory_transactions FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()));

-- ============================================================
-- shop_ezpay_settings：shop_id 是 UUID 型態
-- ============================================================
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.shop_ezpay_settings;

CREATE POLICY "Shop members can access shop_ezpay_settings"
  ON public.shop_ezpay_settings FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- 注意事項（手動在 Supabase Dashboard 補齊）
-- ============================================================
-- 以下核心 table 的 RLS 是在 Supabase Dashboard 設定的，
-- 本 migration 無法覆蓋，請手動確認它們也有正確的 shop_id 過濾：
--   - shops
--   - users / user_shop_map
--   - orders / order_items / order_groups
--   - sales_transactions / cash_opening
--   - menu_categories / menu_items
--   - printers / print_categories
--   - staff_members / shift_assignments
--   - payroll related tables
-- 建議做法：在 Supabase Dashboard > Authentication > Policies
-- 確認每個 table 的 SELECT policy 包含：
--   shop_id IN (SELECT shop_id FROM get_user_shop_ids())
-- ============================================================
