ALTER TABLE public.order_groups 
ADD COLUMN IF NOT EXISTS tax_snapshot JSONB DEFAULT NULL;

COMMENT ON COLUMN public.order_groups.tax_snapshot IS 'Snapshot of tax settings at the time of order creation (rate, is_tax_included)';
