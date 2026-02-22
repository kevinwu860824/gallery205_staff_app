CREATE TABLE IF NOT EXISTS public.tax_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    shop_id TEXT NOT NULL,
    rate NUMERIC DEFAULT 0,
    is_tax_included BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(shop_id)
);

ALTER TABLE public.tax_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all for authenticated users" ON "public"."tax_settings"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
