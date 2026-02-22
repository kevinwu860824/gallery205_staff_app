import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create } from 'https://deno.land/x/djwt@v2.8/mod.ts'

// --- 輔助函式 ---
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
    const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountStr) throw new Error('Missing FIREBASE_SERVICE_ACCOUNT')
    const serviceAccount = JSON.parse(serviceAccountStr)
    const projectId = serviceAccount.project_id
    
    // 1. 準備資料
    const accessToken = await getAccessToken(serviceAccount)
    const payload = await req.json()
    console.log('Received payload:', JSON.stringify(payload))

    const { type, record, old_record } = payload
    const targetRecord = type === 'DELETE' ? old_record : record
    
    if (!targetRecord || !targetRecord.employee_id) {
      return new Response(JSON.stringify({ message: 'No employee_id found' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    const employeeId = targetRecord.employee_id
    const shopId = targetRecord.shop_id

    // 2. 初始化 Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' 
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 3. 決定通知內容
    let title = '班表異動通知'
    let body = '您的班表有新的變動。'
    const dateStr = targetRecord.shift_date ? targetRecord.shift_date.split('T')[0] : '未知日期'

    switch (type) {
        case 'INSERT': title = '📅 新增排班'; body = `您在 ${dateStr} 被安排了新的班別。`; break;
        case 'UPDATE': title = '✏️ 班表修改'; body = `您在 ${dateStr} 的排班已有更動。`; break;
        case 'DELETE': title = '🗑️ 班表取消'; body = `您在 ${dateStr} 的排班已被取消。`; break;
    }

    // 4. 將通知寫入資料庫
    const { error: dbError } = await supabase
      .from('notifications')
      .insert({
        user_id: employeeId,
        shop_id: shopId,
        title: title,
        body: body,
        route: '/scheduleView',
        is_read: false
      })

    if (dbError) {
      console.error('❌ Database Save Error:', dbError)
    } else {
      console.log(`✅ Saved notification to DB for user ${employeeId}`)
    }

    // 🔥 5. (新增) 計算該員工目前的未讀數量 (Badge Count)
    let badgeCount = 1; // 預設至少有 1 則 (剛剛新增的那則)
    const { count } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', employeeId)
      .eq('is_read', false)
    
    if (count !== null) {
      badgeCount = count;
    }

    // 6. 查詢 FCM Token 並發送推播
    const { data: tokens } = await supabase
      .from('user_fcm_tokens')
      .select('token')
      .eq('user_id', employeeId)

    if (!tokens || tokens.length === 0) {
      console.log(`No tokens for user ${employeeId}`)
      return new Response(JSON.stringify({ message: 'Saved to DB, but no tokens found' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    const FCM_V1_URL = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
    
    const sendPromises = tokens.map(t => {
      const messagePayload = {
        message: {
          token: t.token,
          notification: {
            title: title,
            body: body,
          },
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            route: '/scheduleView', 
          },
          // 🔥 (新增) iOS 專用設定：紅點、聲音、橫幅
          apns: {
            payload: {
              aps: {
                badge: badgeCount,
                sound: "default",
                alert: {
                  title: title,
                  body: body
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
      }).then(res => res.json())
    })

    const results = await Promise.allSettled(sendPromises)
    const successCount = results.filter(r => r.status === 'fulfilled' && r.value.name).length
    console.log(`Sent notifications: ${successCount} success`)

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