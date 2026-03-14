-- ============================================================
-- Performance Indexes
-- 依據實際查詢模式新增 index，涵蓋訂單、薪資、庫存
-- ============================================================

-- ============================================================
-- order_groups（最高頻查詢 table）
-- ============================================================

-- shop_id 單獨（RLS + shop 過濾基礎）
CREATE INDEX IF NOT EXISTS idx_order_groups_shop_id
  ON public.order_groups(shop_id);

-- shop_id + status 複合（點餐畫面查詢 dining/pending 訂單）
CREATE INDEX IF NOT EXISTS idx_order_groups_shop_status
  ON public.order_groups(shop_id, status);

-- shop_id + status + created_at（帶排序的查詢）
CREATE INDEX IF NOT EXISTS idx_order_groups_shop_status_created
  ON public.order_groups(shop_id, status, created_at DESC);

-- open_id（結帳/班次統計，已存在則跳過）
CREATE INDEX IF NOT EXISTS idx_order_groups_open_id
  ON public.order_groups(open_id);

-- ============================================================
-- order_items（第二高頻）
-- ============================================================

-- order_group_id（取得訂單內所有品項的基礎查詢）
CREATE INDEX IF NOT EXISTS idx_order_items_order_group_id
  ON public.order_items(order_group_id);

-- order_group_id + print_status（廚房票印製查詢）
CREATE INDEX IF NOT EXISTS idx_order_items_group_print_status
  ON public.order_items(order_group_id, print_status);

-- ============================================================
-- work_logs（薪資計算 — 日期範圍查詢）
-- ============================================================

-- user_id + shop_id + date 複合（薪資計算核心查詢）
CREATE INDEX IF NOT EXISTS idx_work_logs_user_shop_date
  ON public.work_logs(user_id, shop_id, date);

-- shop_id + date（店家維度的出勤查詢）
CREATE INDEX IF NOT EXISTS idx_work_logs_shop_date
  ON public.work_logs(shop_id, date);

-- ============================================================
-- leave_records（薪資假勤計算）
-- ============================================================

-- user_id + start_time（用戶假勤日期範圍查詢）
CREATE INDEX IF NOT EXISTS idx_leave_records_user_start_time
  ON public.leave_records(user_id, start_time);

-- shop_id + start_time（店家維度的假勤查詢）
CREATE INDEX IF NOT EXISTS idx_leave_records_shop_start_time
  ON public.leave_records(shop_id, start_time);

-- ============================================================
-- payroll_records（薪資記錄）
-- ============================================================

-- shop_id + user_id + period 複合（薪資查詢唯一定位）
CREATE INDEX IF NOT EXISTS idx_payroll_records_shop_user_period
  ON public.payroll_records(shop_id, user_id, period);

-- ============================================================
-- inventory_items（庫存查詢）
-- ============================================================

-- shop_id + category_id（分類篩選）
CREATE INDEX IF NOT EXISTS idx_inventory_items_shop_category
  ON public.inventory_items(shop_id, category_id);
