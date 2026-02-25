import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// AES-256-CBC Encryption for ezPay
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

    // 1. Fetch Order Group & Items
    const { data: order, error: orderError } = await supabaseClient
      .from('order_groups')
      .select('*')
      .eq('id', order_id)
      .single()

    if (orderError || !order) throw new Error(`Order not found: ${orderError?.message}`)

    const { data: items, error: itemsError } = await supabaseClient
      .from('order_items')
      .select('*')
      .eq('order_group_id', order_id)
      .neq('status', 'cancelled')

    if (itemsError) throw new Error(`Failed to fetch items: ${itemsError.message}`)

    // 2. Fetch ezPay Settings
    const { data: ezpaySettings, error: settingsError } = await supabaseClient
      .from('shop_ezpay_settings')
      .select('*')
      .eq('shop_id', order.shop_id)
      .single()

    if (settingsError || !ezpaySettings) {
      throw new Error('ezPay settings not found for this shop. Please configure in web admin.')
    }

    // 3. Prepare ezPay Payload
    const totalAmt = Math.round(order.final_amount);
    const amt = Math.round(totalAmt / 1.05);
    const taxAmt = totalAmt - amt;

    let itemsSum = 0;
    const finalItems = items.map(i => {
      const price = Math.round(i.price);
      const qty = i.quantity;
      const itemAmt = price * qty;
      itemsSum += itemAmt;
      return {
        name: i.item_name.substring(0, 30).replace(/\|/g, ''),
        count: qty,
        unit: '份',
        price: price,
        amt: itemAmt
      };
    });

    const diff = totalAmt - itemsSum;
    if (diff > 0) {
      finalItems.push({
        name: '服務費',
        count: 1,
        unit: '式',
        price: diff,
        amt: diff
      });
    } else if (diff < 0) {
      finalItems.push({
        name: '折扣',
        count: 1,
        unit: '式',
        price: diff,
        amt: diff
      });
    }

    const itemNames = finalItems.map(i => i.name).join('|');
    const itemCount = finalItems.map(i => i.count).join('|');
    const itemUnit = finalItems.map(i => i.unit).join('|');
    const itemPrice = finalItems.map(i => i.price).join('|');
    const itemAmt = finalItems.map(i => i.amt).join('|');

    const params: Record<string, string> = {
      RespondType: 'JSON',
      Version: '1.5',
      TimeStamp: Math.floor(Date.now() / 1000).toString(),
      MerchantOrderNo: order.id.replace(/-/g, '_').substring(0, 20), // Shortened to 20 for safety
      Status: '1', // 1: Issue directly
      Category: order.buyer_ubn ? 'B2B' : 'B2C',
      BuyerName: order.buyer_ubn ? (order.buyer_name || 'Customer') : 'Customer',
      BuyerUBN: order.buyer_ubn || '',
      PrintFlag: (order.buyer_ubn || !order.carrier_num) ? 'Y' : 'N',
      CarrierType: order.carrier_num ? '0' : '', // '0' for Mobile Barcode
      CarrierNum: order.carrier_num || '',
      TaxType: '1', // 1: With Tax
      TaxRate: '5',
      Amt: amt.toString(),
      TaxAmt: taxAmt.toString(),
      TotalAmt: totalAmt.toString(),
      ItemName: itemNames,
      ItemCount: itemCount,
      ItemUnit: itemUnit,
      ItemPrice: itemPrice,
      ItemAmt: itemAmt,
    };

    console.log('ezPay Prepared Params:', JSON.stringify(params));

    const queryString = Object.entries(params)
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join('&');

    // 4. Encrypt
    const aesEncrypted = await encrypt(queryString, ezpaySettings.hash_key, ezpaySettings.hash_iv);
    // ezPay E-Invoice CheckValue is HashKey + PostData + HashIV -> SHA256
    const checkValue = await sha256(`${ezpaySettings.hash_key}${aesEncrypted}${ezpaySettings.hash_iv}`);

    // 5. Call ezPay API
    // IMPORTANT: In production, ensure EZPAY_URL is set to https://einvoice.ezpay.com.tw/Api/invoice_issue
    const ezpayUrl = Deno.env.get('EZPAY_URL') || 'https://cinv.ezpay.com.tw/Api/invoice_issue';
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
    console.log('ezPay Raw Result:', resultText);
    const result = JSON.parse(resultText);

    if (result.Status !== 'SUCCESS') {
      throw new Error(`ezPay Error: ${result.Message} (Code: ${result.Status})`);
    }

    const invData = JSON.parse(result.Result);

    // 6. Update order_groups
    const { error: updateError } = await supabaseClient
      .from('order_groups')
      .update({
        ezpay_invoice_number: invData.InvoiceNumber,
        ezpay_random_num: invData.RandomNum,
        ezpay_trans_no: invData.InvoiceTransNo,
        ezpay_invoice_status: '1', // Success
        ezpay_qr_left: invData.QRcodeL,
        ezpay_qr_right: invData.QRcodeR,
        updated_at: new Date().toISOString(),
      })
      .eq('id', order_id);

    if (updateError) throw new Error(`Failed to update order with invoice: ${updateError.message}`);

    return new Response(JSON.stringify({ success: true, data: invData }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Invoice Error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
