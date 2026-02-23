-- Add ezPay invoice tracking fields to order_groups table
ALTER TABLE public.order_groups
ADD COLUMN IF NOT EXISTS ezpay_invoice_number VARCHAR,
ADD COLUMN IF NOT EXISTS ezpay_random_num VARCHAR,
ADD COLUMN IF NOT EXISTS ezpay_trans_no VARCHAR,
ADD COLUMN IF NOT EXISTS ezpay_invoice_status VARCHAR;

-- Add description comments to columns
COMMENT ON COLUMN public.order_groups.ezpay_invoice_number IS '電子發票號碼 (例：AB12345678)';
COMMENT ON COLUMN public.order_groups.ezpay_random_num IS '發票防偽隨機碼 (4碼數字)';
COMMENT ON COLUMN public.order_groups.ezpay_trans_no IS 'ezPay 發票開立序號 (InvoiceTransNo)';
COMMENT ON COLUMN public.order_groups.ezpay_invoice_status IS '發票狀態 (1: 開立成功, 2: 已作廢, null: 未開立/失敗)';
