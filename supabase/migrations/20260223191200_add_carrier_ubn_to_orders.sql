-- Add ezPay Carrier and UBN tracking fields to order_groups table
ALTER TABLE public.order_groups
ADD COLUMN IF NOT EXISTS buyer_ubn VARCHAR(8),
ADD COLUMN IF NOT EXISTS carrier_type VARCHAR(1),
ADD COLUMN IF NOT EXISTS carrier_num VARCHAR;

-- Add description comments to columns
COMMENT ON COLUMN public.order_groups.buyer_ubn IS '買方統一編號 (8碼數字，如有帶入則為 B2B 開立)';
COMMENT ON COLUMN public.order_groups.carrier_type IS '載具類別 (0: 手機條碼, 1: 自然人憑證, 2: ezPay 會員載具)';
COMMENT ON COLUMN public.order_groups.carrier_num IS '載具顯碼/隱碼 (例如 /ABC1234)';
