-- Add QR code fields for ezPay invoice printing
ALTER TABLE public.order_groups
ADD COLUMN IF NOT EXISTS ezpay_qr_left TEXT,
ADD COLUMN IF NOT EXISTS ezpay_qr_right TEXT;

-- Add description comments
COMMENT ON COLUMN public.order_groups.ezpay_qr_left IS '電子發票 QR Code 左側資料';
COMMENT ON COLUMN public.order_groups.ezpay_qr_right IS '電子發票 QR Code 右側資料';
