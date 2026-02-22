import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create } from 'https://deno.land/x/djwt@v2.8/mod.ts'

// --- 輔助函式：PEM 轉 Binary ---
function pemToBinary(pem: string): ArrayBuffer {
  const base64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

// --- Google Auth ---
const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'
const GOOGLE_TOKEN_URL = 'https://www.googleapis.com/oauth2/v4/token'

async function getAccessToken(serviceAccount: any): Promise<string> {
  const iat = Math.floor(Date.now() / 1000)
  const exp = iat + 3600 
  const jwtPayload = {
    iss: serviceAccount.client_email,
    scope: FCM_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: iat,
    exp: exp,
    jti: crypto.randomUUID(), 
  }

  const keyBuffer = pemToBinary(serviceAccount.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: { name: 'SHA-256' } },
    false,
    ['sign']
  )

  const jwt = await create({ alg: 'RS256', typ: 'JWT' }, jwtPayload, cryptoKey)

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const data = await response.json()
  if (data.error) {
    throw new Error(`Failed to get access token: ${data.error_description || data.error}`)
  }
  return data.access_token
}

// --- 主邏輯 ---
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. 初始化環境變數與 Supabase
    const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountStr) throw new Error('Missing FIREBASE_SERVICE_ACCOUNT')
    const serviceAccount = JSON.parse(serviceAccountStr)
    const projectId = serviceAccount.project_id
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' 
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 2. 解析請求
    const payload = await req.json()
    console.log('Received payload:', JSON.stringify(payload))
    const { title, body, target_user_ids, route, shop_id } = payload
    
    if (!target_user_ids || !Array.isArray(target_user_ids) || target_user_ids.length === 0) {
      return new Response(JSON.stringify({ message: 'No target_user_ids provided' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    // ✅ 步驟 3 (新增): 先把通知存入資料庫 (notifications table)
    const notificationRecords = target_user_ids.map((userId: string) => ({
      user_id: userId,
      shop_id: shop_id,
      title: title || '新通知',
      body: body || '',
      route: route || '/todoList',
      is_read: false
    }))

    const { error: dbError } = await supabase
      .from('notifications')
      .insert(notificationRecords)

    if (dbError) {
      console.error('❌ Database Save Error:', dbError)
      // 資料庫存失敗不中斷流程，繼續嘗試發送推播
    } else {
      console.log(`✅ Saved ${notificationRecords.length} notifications to DB`)
    }

    // 4. 準備發送 FCM
    const accessToken = await getAccessToken(serviceAccount)

    const { data: tokens } = await supabase
      .from('user_fcm_tokens')
      .select('token, user_id')
      .in('user_id', target_user_ids)

    if (!tokens || tokens.length === 0) {
      console.log(`No tokens found for targets`)
      // 雖然沒發推播，但資料庫已存，所以視為成功
      return new Response(JSON.stringify({ message: 'Saved to DB, but no devices found' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    const FCM_V1_URL = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
    
    const sendPromises = tokens.map(async t => {
      
      // 🔥 關鍵修正 1：查詢該用戶的未讀數量 (為了 Icon Badge)
      let badgeCount = 1;
      const { count } = await supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', t.user_id)
        .eq('is_read', false)
      
      if (count !== null) {
        badgeCount = count; // 直接使用正確的未讀數量
      }

      // 🔥 關鍵修正 2：加入 iOS APNs 專用設定 (apns 欄位)
      const messagePayload = {
        message: {
          token: t.token,
          notification: {
            title: title || '新通知',
            body: body || '您有一則新通知',
          },
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            route: route || '/todoList', 
          },
          // ⚠️ 這一段是 iOS 顯示通知與紅點的關鍵！
          apns: {
            payload: {
              aps: {
                badge: badgeCount, // 設定 Icon 紅點數字
                sound: "default",  // 確保會發出聲音
                alert: {
                  title: title || '新通知',
                  body: body || '您有一則新通知'
                }
              }
            }
          }
        }
      }

      return fetch(FCM_V1_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify(messagePayload),
      }).then(async res => {
        const json = await res.json();
        return { token: t.token, user_id: t.user_id, status: res.status, response: json };
      })
    })

    const results = await Promise.all(sendPromises)
    const successCount = results.filter(r => r.response.name).length
    console.log(`Sent FCM: ${successCount} success / ${results.length} total`)

    return new Response(JSON.stringify({ message: `Saved to DB & Sent ${successCount} notifications` }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Function error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})