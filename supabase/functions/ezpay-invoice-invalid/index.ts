import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// AES-256-CBC Encryption
async function encrypt(text: string, key: string, iv: string): Promise<string> {
    const keyData = new TextEncoder().encode(key);
    const ivData = new TextEncoder().encode(iv);

    const cryptoKey = await crypto.subtle.importKey(
        "raw",
        keyData,
        { name: "AES-CBC" },
        false,
        ["encrypt"]
    );

    const encrypted = await crypto.subtle.encrypt(
        { name: "AES-CBC", iv: ivData },
        cryptoKey,
        new TextEncoder().encode(text)
    );

    return Array.from(new Uint8Array(encrypted))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('')
        .toUpperCase();
}

async function sha256(text: string): Promise<string> {
    const msgUint8 = new TextEncoder().encode(text);
    const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('').toUpperCase();
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

        const { order_id } = await req.json()
        if (!order_id) throw new Error('Missing order_id')

        // 1. Fetch Order Group
        const { data: order, error: orderError } = await supabaseClient
            .from('order_groups')
            .select('*')
            .eq('id', order_id)
            .single()

        if (orderError || !order) throw new Error('Order not found')
        if (!order.ezpay_invoice_number) throw new Error('No invoice found for this order')
        if (order.ezpay_invoice_status === '2') throw new Error('Invoice is already voided')

        // 2. Fetch ezPay Settings
        const { data: ezpaySettings, error: settingsError } = await supabaseClient
            .from('shop_ezpay_settings')
            .select('*')
            .eq('shop_id', order.shop_id)
            .single()

        if (settingsError || !ezpaySettings) throw new Error('ezPay settings not found')

        // 3. Prepare Payload
        const params: Record<string, string> = {
            RespondType: 'JSON',
            Version: '1.0',
            TimeStamp: Math.floor(Date.now() / 1000).toString(),
            InvoiceNumber: order.ezpay_invoice_number,
            InvalidReason: '店家取消訂單',
        };

        const queryString = Object.entries(params)
            .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
            .join('&');

        // 4. Encrypt
        const aesEncrypted = await encrypt(queryString, ezpaySettings.hash_key, ezpaySettings.hash_iv);
        const checkValue = await sha256(`HashKey=${ezpaySettings.hash_key}&${aesEncrypted}&HashIV=${ezpaySettings.hash_iv}`);

        // 5. Call ezPay API
        // IMPORTANT: In production, ensure EZPAY_INVALID_URL is set to https://einvoice.ezpay.com.tw/Api/invoice_invalid
        const ezpayUrl = Deno.env.get('EZPAY_INVALID_URL') || 'https://cinv.ezpay.com.tw/Api/invoice_invalid';
        const postData = new URLSearchParams();
        postData.append('MerchantID_', ezpaySettings.merchant_id);
        postData.append('PostData_', aesEncrypted);
        postData.append('CheckValue_', checkValue);

        const response = await fetch(ezpayUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: postData.toString(),
        });

        const resultText = await response.text();
        console.log('ezPay Invalidation Result:', resultText);
        const result = JSON.parse(resultText);

        if (result.Status !== 'SUCCESS') {
            throw new Error(`ezPay Error: ${result.Message} (Code: ${result.Status})`);
        }

        // 6. Update order_groups status
        await supabaseClient
            .from('order_groups')
            .update({
                ezpay_invoice_status: '2', // Voided
                updated_at: new Date().toISOString(),
            })
            .eq('id', order_id);

        return new Response(JSON.stringify({ success: true, message: 'Invoice voided successfully' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        console.error('Invalidation Error:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
