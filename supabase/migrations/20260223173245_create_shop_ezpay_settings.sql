-- Create updated_at function if it doesn't exist
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create shop_ezpay_settings table
CREATE TABLE IF NOT EXISTS public.shop_ezpay_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    merchant_id VARCHAR NOT NULL,
    hash_key VARCHAR NOT NULL,
    hash_iv VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(shop_id)
);

-- Enable RLS
ALTER TABLE public.shop_ezpay_settings ENABLE ROW LEVEL SECURITY;

-- Drop trigger if exists to prevent errors on re-run
DROP TRIGGER IF EXISTS handle_updated_at ON public.shop_ezpay_settings;

-- Add updated_at trigger
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.shop_ezpay_settings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Add RLS Policies
-- First drop existing policies to ensure clean slate
DROP POLICY IF EXISTS "Admins can view ezpay settings" ON public.shop_ezpay_settings;
DROP POLICY IF EXISTS "Admins can insert ezpay settings" ON public.shop_ezpay_settings;
DROP POLICY IF EXISTS "Admins can update ezpay settings" ON public.shop_ezpay_settings;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.shop_ezpay_settings;

-- Enable all for authenticated users (Authorization logic is handled in the server actions)
CREATE POLICY "Enable all for authenticated users" ON "public"."shop_ezpay_settings"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
