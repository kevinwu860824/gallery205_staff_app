-- ============================================================
-- FIX: RLS for remaining tables (migration 3/3)
-- 覆蓋所有尚未設定 shop isolation 的 tables
-- 前置條件：20260314000000 / 000001 已執行
-- ============================================================

-- ============================================================
-- UUID shop_id tables（使用 get_user_shop_ids()）
-- ============================================================

-- calendar_groups
ALTER TABLE public.calendar_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access calendar_groups"
  ON public.calendar_groups FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- daily_cost_summary
ALTER TABLE public.daily_cost_summary ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access daily_cost_summary"
  ON public.daily_cost_summary FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- deposits
ALTER TABLE public.deposits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access deposits"
  ON public.deposits FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- expense_categories
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access expense_categories"
  ON public.expense_categories FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- expense_logs
ALTER TABLE public.expense_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access expense_logs"
  ON public.expense_logs FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- leave_records
ALTER TABLE public.leave_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access leave_records"
  ON public.leave_records FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- payroll_records
ALTER TABLE public.payroll_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access payroll_records"
  ON public.payroll_records FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- printer_settings
ALTER TABLE public.printer_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access printer_settings"
  ON public.printer_settings FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- shift_schedules
ALTER TABLE public.shift_schedules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access shift_schedules"
  ON public.shift_schedules FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- shop_punch_in_data
ALTER TABLE public.shop_punch_in_data ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access shop_punch_in_data"
  ON public.shop_punch_in_data FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- stock_categories
ALTER TABLE public.stock_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access stock_categories"
  ON public.stock_categories FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- stock_items
ALTER TABLE public.stock_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access stock_items"
  ON public.stock_items FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- table_area
ALTER TABLE public.table_area ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access table_area"
  ON public.table_area FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- tables
ALTER TABLE public.tables ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access tables"
  ON public.tables FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- todos
ALTER TABLE public.todos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access todos"
  ON public.todos FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- work_logs
ALTER TABLE public.work_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access work_logs"
  ON public.work_logs FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- work_reports
ALTER TABLE public.work_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access work_reports"
  ON public.work_reports FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids()));

-- ============================================================
-- TEXT shop_id tables（使用 get_user_shop_ids_text()）
-- ============================================================

-- calendar_events
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access calendar_events"
  ON public.calendar_events FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()));

-- chat_history
ALTER TABLE public.chat_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access chat_history"
  ON public.chat_history FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()));

-- menu_item_recipes
ALTER TABLE public.menu_item_recipes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access menu_item_recipes"
  ON public.menu_item_recipes FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()));

-- notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop members can access notifications"
  ON public.notifications FOR ALL
  USING (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()))
  WITH CHECK (shop_id IN (SELECT shop_id FROM public.get_user_shop_ids_text()));
