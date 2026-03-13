-- ============================================================
-- FIX: RLS for all remaining tables
-- 覆蓋範圍：
--   1. RLS 完全關閉的 table → Enable RLS + 建正確 policy
--   2. RLS 已開但 policy 缺 shop_id 過濾的 table → 補齊
-- 前置條件：20260314000000_fix_rls_shop_isolation.sql 已執行
--           (get_user_shop_ids / get_user_shop_ids_text functions 已存在)
-- ============================================================

-- ============================================================
-- user_shop_map：啟用 RLS，清除舊 policy，重建正確版本
-- 用戶只能看到自己參與的 shop mapping
-- ============================================================
ALTER TABLE public.user_shop_map ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read roles" ON public.user_shop_map;
DROP POLICY IF EXISTS "allow delete for service role" ON public.user_shop_map;
DROP POLICY IF EXISTS "allow delete for service_role" ON public.user_shop_map;
DROP POLICY IF EXISTS "allow delete own mapping" ON public.user_shop_map;
DROP POLICY IF EXISTS "allow insert self mappings" ON public.user_shop_map;
DROP POLICY IF EXISTS "Allow select own shop mapping" ON public.user_shop_map;

-- 只能看到同 shop 的 mapping（自己能確認同事也在這家店）
CREATE POLICY "Shop members can read user_shop_map"
  ON public.user_shop_map FOR SELECT
  USING (
    shop_code IN (SELECT shop_id FROM public.get_user_shop_ids())
    OR user_id = auth.uid()
  );

-- 只能插入自己的 mapping（加入店家）
CREATE POLICY "Users can insert own mapping"
  ON public.user_shop_map FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- 只能刪除自己的 mapping
CREATE POLICY "Users can delete own mapping"
  ON public.user_shop_map FOR DELETE
  USING (user_id = auth.uid());

-- Update 由 Admin 透過 service role 處理，一般用戶不需要

-- ============================================================
-- users：啟用 RLS
-- 用戶可以看到同 shop 的其他成員
-- ============================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin/Manager insert role-limited" ON public.users;
DROP POLICY IF EXISTS "Admin/Manager update role-limited" ON public.users;
DROP POLICY IF EXISTS "Allow delete for same shop by email" ON public.users;
DROP POLICY IF EXISTS "allow insert all" ON public.users;
DROP POLICY IF EXISTS "allow select all" ON public.users;
DROP POLICY IF EXISTS "allow update all" ON public.users;

-- 看到同 shop 的所有成員（包括自己）
CREATE POLICY "Shop members can view each other"
  ON public.users FOR SELECT
  USING (
    user_id = auth.uid()
    OR user_id IN (
      SELECT usm.user_id FROM public.user_shop_map usm
      WHERE usm.shop_code IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

-- 只能更新自己
CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- INSERT / DELETE 由 service role 處理（新增/刪除員工為管理操作）
-- 如果前端有直接 INSERT，請在 Dashboard 手動加：
--   INSERT WITH CHECK (id = auth.uid())

-- ============================================================
-- order_groups：啟用 RLS + shop_id 過濾
-- ============================================================
ALTER TABLE public.order_groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop members can access order_groups"
  ON public.order_groups FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- order_items：啟用 RLS，透過 order_groups 取得 shop_id
-- ============================================================
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop members can access order_items"
  ON public.order_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.order_groups og
      WHERE og.id = order_items.order_group_id
        AND og.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.order_groups og
      WHERE og.id = order_items.order_group_id
        AND og.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

-- ============================================================
-- order_payments：啟用 RLS，透過 order_groups 取得 shop_id
-- ============================================================
ALTER TABLE public.order_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop members can access order_payments"
  ON public.order_payments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.order_groups og
      WHERE og.id = order_payments.order_group_id
        AND og.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.order_groups og
      WHERE og.id = order_payments.order_group_id
        AND og.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

-- ============================================================
-- shop_roles：啟用 RLS + shop_id 過濾
-- ============================================================
ALTER TABLE public.shop_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop members can read shop_roles"
  ON public.shop_roles FOR SELECT
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

CREATE POLICY "Shop members can manage shop_roles"
  ON public.shop_roles FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- shop_role_permissions：啟用 RLS，透過 shop_roles 取得 shop_id
-- ============================================================
ALTER TABLE public.shop_role_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop members can access shop_role_permissions"
  ON public.shop_role_permissions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.shop_roles sr
      WHERE sr.id = shop_role_permissions.role_id
        AND sr.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.shop_roles sr
      WHERE sr.id = shop_role_permissions.role_id
        AND sr.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

-- ============================================================
-- shop_shift_settings：啟用 RLS + shop_id 過濾（shop_id 是 TEXT）
-- ============================================================
ALTER TABLE public.shop_shift_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop members can access shop_shift_settings"
  ON public.shop_shift_settings FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()));

-- ============================================================
-- schedule_assignments：啟用 RLS + shop_id 過濾
-- ============================================================
ALTER TABLE public.schedule_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop members can access schedule_assignments"
  ON public.schedule_assignments FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- print_categories：啟用 RLS + shop_id 過濾（shop_id 是 TEXT）
-- ============================================================
ALTER TABLE public.print_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop members can access print_categories"
  ON public.print_categories FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()));

-- ============================================================
-- print_tasks：啟用 RLS，透過 order_group_id → order_groups 取得 shop_id
-- ============================================================
ALTER TABLE public.print_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop members can access print_tasks"
  ON public.print_tasks FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.order_groups og
      WHERE og.id = print_tasks.order_group_id
        AND og.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.order_groups og
      WHERE og.id = print_tasks.order_group_id
        AND og.shop_id IN (SELECT shop_id FROM public.get_user_shop_ids())
    )
  );

-- ============================================================
-- expert_knowledge_base：啟用 RLS
-- 若是全局知識庫（所有店共用），設定為所有登入用戶可讀；
-- 若有 shop_id 欄位，換成 shop_id 過濾
-- ============================================================
ALTER TABLE public.expert_knowledge_base ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated insert" ON public.expert_knowledge_base;
DROP POLICY IF EXISTS "Allow authenticated select" ON public.expert_knowledge_base;
DROP POLICY IF EXISTS "Allow authenticated update" ON public.expert_knowledge_base;

-- 假設為共用知識庫，只要登入就能讀/寫
-- 如果有 shop_id 欄位，請改成 shop_id IN (SELECT shop_id FROM get_user_shop_ids())
CREATE POLICY "Authenticated users can read expert_knowledge_base"
  ON public.expert_knowledge_base FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert expert_knowledge_base"
  ON public.expert_knowledge_base FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update expert_knowledge_base"
  ON public.expert_knowledge_base FOR UPDATE
  USING (auth.role() = 'authenticated');

-- ============================================================
-- group_event_colors：啟用 RLS
-- ⚠️  查詢結果未找到 user_id / shop_id 欄位，執行前請先確認：
--   SELECT column_name, data_type FROM information_schema.columns
--   WHERE table_name = 'group_event_colors';
-- 確認後依欄位調整下方 policy，目前先用 authenticated 作為暫時保護
-- ============================================================
ALTER TABLE public.group_event_colors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can access group_event_colors"
  ON public.group_event_colors FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- ============================================================
-- menu_categories：修正現有 policy，加入 shop_id 過濾
-- ============================================================
DROP POLICY IF EXISTS "Allow all for authenticated" ON public.menu_categories;

CREATE POLICY "Shop members can access menu_categories"
  ON public.menu_categories FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- menu_items：修正現有 policy，加入 shop_id 過濾
-- ============================================================
DROP POLICY IF EXISTS "Allow all for authenticated" ON public.menu_items;

CREATE POLICY "Shop members can access menu_items"
  ON public.menu_items FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- cash_opening：修正 "Enable read access for authenticated users"
-- ============================================================
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.cash_opening;
DROP POLICY IF EXISTS "Allow shop members to manage cash opening" ON public.cash_opening;

CREATE POLICY "Shop members can access cash_opening"
  ON public.cash_opening FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- sales_transactions：修正現有 policy
-- ============================================================
DROP POLICY IF EXISTS "Allow manager to modify transactions" ON public.sales_transactions;
DROP POLICY IF EXISTS "Allow shop members to view transactions" ON public.sales_transactions;

CREATE POLICY "Shop members can access sales_transactions"
  ON public.sales_transactions FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- inventory_categories：修正 policy（shop_id 為 UUID）
-- ============================================================
DROP POLICY IF EXISTS "Allow read/write for own shop" ON public.inventory_categories;

CREATE POLICY "Shop members can access inventory_categories"
  ON public.inventory_categories FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- inventory_logs：修正 policy（shop_id 為 UUID）
-- ============================================================
DROP POLICY IF EXISTS "Allow authenticated users to insert logs" ON public.inventory_logs;
DROP POLICY IF EXISTS "Allow shop members to view all logs" ON public.inventory_logs;

CREATE POLICY "Shop members can access inventory_logs"
  ON public.inventory_logs FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- shop_payment_settings：修正 policy
-- ============================================================
DROP POLICY IF EXISTS "Allow manager to WRITE payment settings" ON public.shop_payment_settings;
DROP POLICY IF EXISTS "Allow members to READ payment settings" ON public.shop_payment_settings;

CREATE POLICY "Shop members can access shop_payment_settings"
  ON public.shop_payment_settings FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- cash_register_settings：修正 policy
-- ============================================================
DROP POLICY IF EXISTS "Allow manager to WRITE cash settings" ON public.cash_register_settings;
DROP POLICY IF EXISTS "Allow shop members to READ cash settings" ON public.cash_register_settings;

CREATE POLICY "Shop members can access cash_register_settings"
  ON public.cash_register_settings FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));
