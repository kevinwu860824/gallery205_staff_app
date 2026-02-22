import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const { email, name, role_id, shop_id } = await req.json()

    if (!email || !role_id || !shop_id) {
      throw new Error('缺少必要參數')
    }

    console.log(`處理邀請: ${email} -> Shop: ${shop_id}`)

    // 1. 檢查 Auth 使用者是否存在
    const { data: { users }, error: searchError } = await supabaseAdmin.auth.admin.listUsers()
    if (searchError) throw searchError

    const existingUser = users.find(u => u.email?.toLowerCase() === email.toLowerCase())

    let targetUserId = ''
    let isNewUser = false

    if (existingUser) {
      // --- 情況 A: 老員工 ---
      console.log('使用者已存在 (Auth)')
      targetUserId = existingUser.id
      
      // 檢查是否已在店內
      const { data: checkMap } = await supabaseAdmin
        .from('user_shop_map')
        .select('id')
        .eq('user_id', targetUserId)
        .eq('shop_code', shop_id)
        .maybeSingle()
      
      if (checkMap) {
        return new Response(
          JSON.stringify({ message: '此員工已經在這間店裡了' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
      }

    } else {
      // --- 情況 B: 新員工 ---
      console.log('使用者不存在，發送邀請...')
      isNewUser = true
      
      const { data: inviteData, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(
        email,
        { data: { name: name } }
      )

      if (inviteError) throw inviteError
      targetUserId = inviteData.user.id
    }

    // ==========================================
    // ✅ 修正重點：先建立 public.users 資料
    // ==========================================
    
    // 檢查 public.users 是否已有資料 (避免老員工重複寫入報錯)
    const { data: checkPublicUser } = await supabaseAdmin
        .from('users')
        .select('user_id')
        .eq('user_id', targetUserId)
        .maybeSingle()

    if (!checkPublicUser) {
        console.log('建立 public.users 資料...')
        const { error: userError } = await supabaseAdmin.from('users').insert({
            user_id: targetUserId,
            shop_id: shop_id, // 這裡紀錄初始店鋪
            email: email,
            name: name,
            role: 'custom' 
        })
        if (userError) throw userError
    }

    // ==========================================
    // ✅ 然後才建立 user_shop_map (關聯)
    // ==========================================
    console.log('建立 user_shop_map 關聯...')
    const { error: mapError } = await supabaseAdmin
      .from('user_shop_map')
      .insert({
        user_id: targetUserId,
        shop_code: shop_id, 
        role_id: role_id,   
        role: 'custom',     
      })

    if (mapError) throw mapError

    return new Response(
      JSON.stringify({ message: '成功', isNewUser }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error(error)
    return new Response(
      JSON.stringify({ error: error.message || '伺服器錯誤' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})