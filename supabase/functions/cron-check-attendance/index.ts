// supabase/functions/cron-check-attendance/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";

// --- 1. Google Auth 輔助函式 ---
function pemToBinary(pem: string): ArrayBuffer {
  const base64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_URL = "https://www.googleapis.com/oauth2/v4/token";

async function getAccessToken(serviceAccount: any): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  const jwtPayload = {
    iss: serviceAccount.client_email,
    scope: FCM_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat,
    exp,
    jti: crypto.randomUUID(),
  };

  const keyBuffer = pemToBinary(serviceAccount.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const jwt = await create({ alg: "RS256", typ: "JWT" }, jwtPayload, cryptoKey);

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await response.json();
  if (data.error) {
    throw new Error(
      `Failed to get access token: ${data.error_description || data.error}`
    );
  }

  return data.access_token;
}

// --- 2. 發送推播（含寫入 notifications + shop_id）---
async function sendFCM(
  userIds: string[],
  title: string,
  body: string,
  route: string,
  supabase: any,
  projectId: string,
  accessToken: string,
  shopId: string
) {
  if (!userIds || userIds.length === 0) return;

  // A. 寫入 notifications（含 shop_id）
  const notifyRecords = userIds.map((uid) => ({
    user_id: uid,
    shop_id: shopId,
    title,
    body,
    route,
    is_read: false,
  }));

  const { error: notifyError } = await supabase
    .from("notifications")
    .insert(notifyRecords);

  if (notifyError) {
    console.error("❌ insert notifications failed", notifyError);
  }

  // B. 查詢 FCM tokens
  const { data: tokens, error: tokenError } = await supabase
    .from("user_fcm_tokens")
    .select("token, user_id")
    .in("user_id", userIds);

  if (tokenError || !tokens || tokens.length === 0) return;

  const FCM_V1_URL = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const sendPromises = tokens.map(async (t: any) => {
    // badge（只算該店鋪）
    let badgeCount = 1;
    const { count } = await supabase
      .from("notifications")
      .select("*", { count: "exact", head: true })
      .eq("user_id", t.user_id)
      .eq("shop_id", shopId)
      .eq("is_read", false);

    if (count !== null) badgeCount = count;

    const messagePayload = {
      message: {
        token: t.token,
        notification: { title, body },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          route,
        },
        apns: {
          payload: {
            aps: {
              badge: badgeCount,
              sound: "default",
              alert: { title, body },
            },
          },
        },
      },
    };

    return fetch(FCM_V1_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(messagePayload),
    });
  });

  await Promise.allSettled(sendPromises);
}

// --- 主邏輯 ---
serve(async () => {
  try {
    const serviceAccountStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountStr) throw new Error("Missing FIREBASE_SERVICE_ACCOUNT");

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const serviceAccount = JSON.parse(serviceAccountStr);
    const accessToken = await getAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    console.log("⏰ Cron Job Started");

    const { data: activeLogs, error } = await supabase
      .from("work_logs")
      .select(
        "id, user_id, shop_id, clock_in, notified_12h, notified_48h, notified_72h"
      )
      .is("clock_out", null);

    if (error || !activeLogs) throw error;

    const now = new Date();

    for (const log of activeLogs) {
      if (!log.shop_id) continue;

      const diffHours =
        (now.getTime() - new Date(log.clock_in).getTime()) /
        (1000 * 60 * 60);

      if (diffHours >= 12 && !log.notified_12h) {
        await sendFCM(
          [log.user_id],
          "⏰ 打卡提醒",
          "您已上班超過 12 小時尚未打卡，請記得補打下班卡。",
          "/punchIn",
          supabase,
          projectId,
          accessToken,
          log.shop_id
        );
        await supabase
          .from("work_logs")
          .update({ notified_12h: true })
          .eq("id", log.id);
      }

      if (diffHours >= 48 && !log.notified_48h) {
        await sendFCM(
          [log.user_id],
          "⚠️ 考勤異常提醒",
          "您有超過 48 小時的未結案打卡紀錄，請盡速補單。",
          "/punchIn",
          supabase,
          projectId,
          accessToken,
          log.shop_id
        );
        await supabase
          .from("work_logs")
          .update({ notified_48h: true })
          .eq("id", log.id);
      }

      if (diffHours >= 72 && !log.notified_72h) {
        const { data: roles } = await supabase
          .from("shop_role_permissions")
          .select("role_id")
          .eq("permission_key", "back_view_all_clock_in");

        if (roles?.length) {
          const roleIds = roles.map((r: any) => r.role_id);

          const { data: managers } = await supabase
            .from("user_shop_map")
            .select("user_id")
            .eq("shop_id", log.shop_id)
            .in("role_id", roleIds);

          if (managers?.length) {
            const managerIds = managers.map((m: any) => m.user_id);
            const { data: user } = await supabase
              .from("users")
              .select("name")
              .eq("user_id", log.user_id)
              .maybeSingle();

            await sendFCM(
              managerIds,
              "🚨 員工考勤異常",
              `${user?.name ?? "員工"} 已超過 72 小時未打下班卡，請協助手動結算。`,
              "/clockInReport",
              supabase,
              projectId,
              accessToken,
              log.shop_id
            );
          }
        }

        await supabase
          .from("work_logs")
          .update({ notified_72h: true })
          .eq("id", log.id);
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("Cron job error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
    });
  }
});
