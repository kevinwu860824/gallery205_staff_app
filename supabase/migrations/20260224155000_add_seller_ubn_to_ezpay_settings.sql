-- Migration to add missing seller_ubn to shop_ezpay_settings
ALTER TABLE public.shop_ezpay_settings
ADD COLUMN IF NOT EXISTS seller_ubn VARCHAR(8);

COMMENT ON COLUMN public.shop_ezpay_settings.seller_ubn IS '賣方統一編號 (8碼數字，用於發票證明聯列印)';
