import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { shop_id } = await req.json()

    if (!shop_id) {
      return new Response(JSON.stringify({ error: 'Missing shop_id' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    // Check ezPay settings
    const { data: ezpayData, error: ezpayError } = await supabaseClient
      .from('shop_ezpay_settings')
      .select('merchant_id, hash_key, hash_iv')
      .eq('shop_id', shop_id)
      .maybeSingle()

    if (ezpayError) {
      console.error('Error fetching EZPay settings:', ezpayError)
      return new Response(JSON.stringify({ error: 'Failed to fetch ezPay settings.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      })
    }

    if (!ezpayData || !ezpayData.merchant_id || !ezpayData.hash_key || !ezpayData.hash_iv) {
      return new Response(JSON.stringify({ error: 'ezPay credentials not configured', code: 'MISSING_CREDENTIALS' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // Success - credentials exist. The web admin handles the actual connectivity test. 
    // This is simply a presence check before saving Tax Profile.
    return new Response(JSON.stringify({ success: true, message: 'ezPay is configured.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Verify error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
