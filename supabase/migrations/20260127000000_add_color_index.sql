-- 20260127000000_add_color_index.sql
-- Add color_index column to order_groups for smart color assignment

ALTER TABLE public.order_groups 
ADD COLUMN IF NOT EXISTS color_index INTEGER;

COMMENT ON COLUMN public.order_groups.color_index IS 'Explicitly assigned color index (0-19) for UI rendering';
