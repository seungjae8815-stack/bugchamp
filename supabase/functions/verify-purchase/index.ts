// 구글 플레이 영수증 서버 검증 (Supabase Edge Function / Deno)
//
// 앱이 보낸 purchaseToken 이 **진짜 구글이 발급한 것인지**를 서버에서 확인한다.
// 클라이언트만으로 구매를 인정하면 결제 후킹 앱(Lucky Patcher 류)이 만든
// 가짜 영수증으로 상품을 공짜로 받을 수 있다.
//
// 요청 (POST, 사용자 JWT 필요):
//   { "productId": "jelly_m", "purchaseToken": "..." }
// 응답:
//   { "ok": true }                        → 지급해도 됨
//   { "ok": false, "reason": "invalid" }  → 가짜/취소/환불 — 지급 금지(재시도 무의미)
//   { "ok": false, "reason": "owned_by_other" } → 다른 계정이 이미 사용한 영수증
//   HTTP 5xx                              → 일시적 오류. 앱은 **지급도 완료통보도 하지 말고** 재시도.

import { createClient } from 'jsr:@supabase/supabase-js@2'

const PACKAGE_NAME = 'com.bugchamp.app'

// 서비스 계정 키(JSON 전체)는 Edge Function 시크릿으로만 넣는다. 앱에는 절대 넣지 않는다.
const SERVICE_ACCOUNT_JSON = Deno.env.get('PLAY_SERVICE_ACCOUNT_JSON') ?? ''

/** base64url 인코딩(패딩 제거) */
function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

/** PEM(PKCS#8) → CryptoKey */
async function importKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0))
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

/** 서비스 계정으로 Play Developer API 액세스 토큰 발급 */
async function getAccessToken(): Promise<string> {
  const sa = JSON.parse(SERVICE_ACCOUNT_JSON)
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }
  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claim))}`
  const key = await importKey(sa.private_key)
  const sig = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)),
  )
  const jwt = `${unsigned}.${b64url(sig)}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  if (!res.ok) throw new Error(`token exchange failed: ${res.status} ${await res.text()}`)
  return (await res.json()).access_token as string
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 })

  // 1) 호출자 인증 — 로그인한 사용자만.
  const authHeader = req.headers.get('Authorization') ?? ''
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  )
  const { data: userData } = await supabase.auth.getUser()
  const uid = userData?.user?.id
  if (!uid) return Response.json({ ok: false, reason: 'unauthenticated' }, { status: 401 })

  let productId: string, purchaseToken: string
  try {
    const body = await req.json()
    productId = String(body.productId ?? '')
    purchaseToken = String(body.purchaseToken ?? '')
    if (!productId || !purchaseToken) throw new Error('missing fields')
  } catch {
    return Response.json({ ok: false, reason: 'bad_request' }, { status: 400 })
  }

  if (!SERVICE_ACCOUNT_JSON) {
    // 시크릿 미설정 — 검증 불가. 통과시키면 검증이 없는 것과 같으므로 실패로 둔다.
    console.error('PLAY_SERVICE_ACCOUNT_JSON 미설정')
    return Response.json({ ok: false, reason: 'server_misconfigured' }, { status: 503 })
  }

  // 2) 구글에 영수증 확인
  let purchase: Record<string, unknown>
  try {
    const token = await getAccessToken()
    const url =
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
      `${PACKAGE_NAME}/purchases/products/${encodeURIComponent(productId)}/tokens/` +
      `${encodeURIComponent(purchaseToken)}`
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } })

    if (res.status === 404 || res.status === 400) {
      // 구글이 모르는 영수증 = 위조. 재시도해도 결과가 바뀌지 않는다.
      return Response.json({ ok: false, reason: 'invalid' })
    }
    if (!res.ok) {
      // 5xx·권한 문제 등 일시적일 수 있는 오류 → 앱이 재시도하도록 5xx 로 돌려준다.
      console.error('play api error', res.status, await res.text())
      return Response.json({ ok: false, reason: 'upstream_error' }, { status: 502 })
    }
    purchase = await res.json()
  } catch (e) {
    console.error('verify failed', e)
    return Response.json({ ok: false, reason: 'exception' }, { status: 500 })
  }

  // 3) 상태 확인. purchaseState: 0=구매완료, 1=취소, 2=보류
  const state = Number(purchase.purchaseState ?? -1)
  if (state !== 0) {
    return Response.json({ ok: false, reason: state === 2 ? 'pending' : 'invalid' })
  }

  // 4) 재사용 방지 — 같은 영수증을 여러 계정이 쓰지 못하게 서버에 못박는다.
  //    (앱 로컬 원장은 기기별이라 계정 간 재사용을 막지 못한다.)
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )
  const { data: existing } = await admin
    .from('verified_purchases')
    .select('user_id')
    .eq('purchase_token', purchaseToken)
    .maybeSingle()

  if (existing && existing.user_id !== uid) {
    return Response.json({ ok: false, reason: 'owned_by_other' })
  }
  if (!existing) {
    const { error } = await admin.from('verified_purchases').insert({
      purchase_token: purchaseToken,
      user_id: uid,
      product_id: productId,
      order_id: purchase.orderId ?? null,
    })
    // 동시 요청으로 unique 충돌이 나면 이미 기록된 것이므로 성공으로 본다.
    if (error && !String(error.message).includes('duplicate')) {
      console.error('record failed', error)
      return Response.json({ ok: false, reason: 'record_failed' }, { status: 500 })
    }
  }

  return Response.json({ ok: true })
})
