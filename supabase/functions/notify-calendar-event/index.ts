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
    
    // 初始化 Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' 
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 1. 解析 Payload
    const payload = await req.json()
    console.log('Received payload:', JSON.stringify(payload))

    const { title, body, target_user_ids, route, shop_id } = payload
    
    if (!target_user_ids || !Array.isArray(target_user_ids) || target_user_ids.length === 0) {
      return new Response(JSON.stringify({ message: 'No target_user_ids provided' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    // 2. 取得 Access Token (這步很關鍵，放前面避免後面邏輯白跑)
    const serviceAccount = JSON.parse(serviceAccountStr)
    const accessToken = await getAccessToken(serviceAccount)
    const projectId = serviceAccount.project_id

    // 3. 寫入 notifications 資料表
    const notificationRecords = target_user_ids.map((userId: string) => ({
      user_id: userId,
      shop_id: shop_id,
      title: title || '新行程通知',
      body: body || '您有一個新的行事曆活動',
      route: route || '/personalSchedule',
      is_read: false
    }))

    const { error: dbError } = await supabase
      .from('notifications')
      .insert(notificationRecords)

    if (dbError) {
      console.error('❌ Database Save Error:', dbError)
      // 資料庫存失敗不應該中斷推播發送，除非您希望嚴格一致性
    } else {
      console.log(`✅ Saved ${notificationRecords.length} notifications to DB`)
    }

    // 4. 查詢 FCM Tokens
    const { data: tokens, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('token, user_id')
      .in('user_id', target_user_ids)

    if (tokenError) {
      console.error('Fetch Token Error:', tokenError)
      throw new Error('Failed to fetch tokens')
    }

    if (!tokens || tokens.length === 0) {
      console.log(`No tokens found for targets`)
      return new Response(JSON.stringify({ message: 'Saved to DB, but no devices found' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    const FCM_V1_URL = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
    
    // 5. 發送推播 (並查詢 Badge)
    // ⚠️ 使用 Promise.all 確保所有 async 操作都被等待
    const sendPromises = tokens.map(async (t) => {
      try {
        // 🔥 查詢該用戶未讀數量
        let badgeCount = 1;
        
        // 這裡加上 try-catch 防止單一查詢失敗拖累所有人
        try {
          const { count } = await supabase
            .from('notifications')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', t.user_id)
            .eq('is_read', false)
          
          if (count !== null) badgeCount = count;
        } catch (badgeErr) {
          console.error(`Badge fetch error for user ${t.user_id}:`, badgeErr)
        }

        const messagePayload = {
          message: {
            token: t.token,
            notification: {
              title: title,
              body: body,
            },
            data: {
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              route: route || '/personalSchedule', 
            },
            // 🔥 iOS 專用設定
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

        const res = await fetch(FCM_V1_URL, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${accessToken}`,
          },
          body: JSON.stringify(messagePayload),
        })
        
        return await res.json()

      } catch (err) {
        // 回傳錯誤物件，讓 allSettled 捕獲
        return { error: err.message }
      }
    })

    // 等待所有發送完成
    const results = await Promise.allSettled(sendPromises)
    
    // 解析結果
    let successCount = 0
    results.forEach((result, index) => {
      if (result.status === 'fulfilled') {
        const val = result.value
        // 如果 FCM 回傳錯誤 (例如 token 無效)，也會在 value 裡
        if (val.error) {
           console.error(`Token ${index} FCM/Fetch Error:`, JSON.stringify(val))
        } else if (val.name) {
           successCount++
           console.log(`Token ${index} Success: ${val.name}`)
        } else {
           console.log(`Token ${index} Unknown response:`, JSON.stringify(val))
        }
      } else {
        console.error(`Token ${index} Promise Rejected:`, result.reason)
      }
    })
    
    console.log(`Sent notifications complete. Success: ${successCount} / ${tokens.length}`)

    return new Response(JSON.stringify({ success: true, sent: successCount }), {
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