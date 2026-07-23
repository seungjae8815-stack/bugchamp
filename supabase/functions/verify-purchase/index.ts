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

// ── Apple(App Store) 영수증 검증 ──────────────────────────────────
// App-Specific Shared Secret 으로 verifyReceipt 에 조회한다(StoreKit1 영수증).
// 앱은 iOS 에서 base64 영수증을 purchaseToken 자리에 실어 보낸다(수천 자).
const APPLE_SHARED_SECRET = Deno.env.get('APPLE_SHARED_SECRET') ?? ''

/** iOS 영수증인지 대략 판별 — App Store 영수증은 매우 긴 base64. */
function looksLikeAppleReceipt(token: string): boolean {
  return token.length > 900
}

type AppleResult =
  | { ok: true; reuseKey: string; orderId: string | null }
  | { ok: false; reason: string; status?: number }

async function verifyApple(receipt: string, productId: string): Promise<AppleResult> {
  if (!APPLE_SHARED_SECRET) {
    console.error('APPLE_SHARED_SECRET 미설정')
    return { ok: false, reason: 'server_misconfigured' }
  }
  const body = JSON.stringify({
    'receipt-data': receipt,
    password: APPLE_SHARED_SECRET,
    'exclude-old-transactions': false,
  })
  const call = async (url: string) => {
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
    })
    return (await r.json()) as Record<string, unknown>
  }

  // 프로덕션 먼저 → 21007(샌드박스 영수증)이면 샌드박스로 재시도(테스트/심사 대응).
  let data = await call('https://buy.itunes.apple.com/verifyReceipt')
  console.log('[apple] prod status', data.status, 'productId', productId)
  if (data.status === 21007) {
    data = await call('https://sandbox.itunes.apple.com/verifyReceipt')
    console.log('[apple] sandbox status', data.status)
  } else if (data.status === 21008) {
    data = await call('https://buy.itunes.apple.com/verifyReceipt')
    console.log('[apple] prod-retry status', data.status)
  }

  const status = Number(data.status ?? -1)
  if (status !== 0) {
    // 21010/21003 등 = 위조·무효. 21005(서버 일시 오류)는 재시도 여지.
    // 21004 = 공유암호 불일치(서버 설정 문제) → 재시도 대상으로 둔다(지급 보류).
    const retryable = status === 21005 || status === 21009 || status === 21004
    console.error('[apple] verify failed status', status, 'retryable', retryable)
    return {
      ok: false,
      reason: retryable ? 'upstream_error' : 'invalid',
      status,
    }
  }

  // in_app + latest_receipt_info 를 합쳐 해당 상품의 최신 거래를 찾는다.
  const receiptObj = (data.receipt ?? {}) as Record<string, unknown>
  const inApp = [
    ...((receiptObj.in_app as unknown[]) ?? []),
    ...((data.latest_receipt_info as unknown[]) ?? []),
  ] as Array<Record<string, string>>

  const matches = inApp
    .filter((t) => t.product_id === productId)
    .sort((a, b) => Number(b.purchase_date_ms ?? 0) - Number(a.purchase_date_ms ?? 0))
  const match = matches[0]

  if (!match) {
    // 영수증에 이 상품 없음 — 진단용으로 영수증에 담긴 product_id 들을 남긴다.
    const ids = inApp.map((t) => t.product_id).join(',')
    console.error('[apple] productId not in receipt. want', productId, 'have', ids)
    return { ok: false, reason: 'invalid' }
  }
  if (match.cancellation_date || match.cancellation_date_ms) {
    return { ok: false, reason: 'invalid' } // 환불·취소됨
  }

  // 재사용 방지 키 = transaction_id(거래 고유). 소비형 재구매도 매번 다르다.
  const reuseKey = String(match.transaction_id ?? match.original_transaction_id ?? '')
  if (!reuseKey) return { ok: false, reason: 'invalid' }
  return { ok: true, reuseKey, orderId: match.original_transaction_id ?? null }
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

  // 2) 플랫폼별 영수증 확인 → 재사용방지 키(reuseKey)·주문번호(orderId) 확정.
  let reuseKey: string
  let orderId: string | null = null

  console.log('[verify] platform', looksLikeAppleReceipt(purchaseToken) ? 'ios' : 'android',
    'productId', productId, 'tokenLen', purchaseToken.length)

  if (looksLikeAppleReceipt(purchaseToken)) {
    // ── iOS(App Store) ──
    const r = await verifyApple(purchaseToken, productId)
    if (!r.ok) {
      const httpStatus = r.reason === 'server_misconfigured'
        ? 503
        : r.reason === 'upstream_error'
        ? 502
        : 200
      return Response.json({ ok: false, reason: r.reason }, { status: httpStatus })
    }
    reuseKey = r.reuseKey
    orderId = r.orderId
  } else {
    // ── Android(Google Play) ──
    if (!SERVICE_ACCOUNT_JSON) {
      // 시크릿 미설정 — 검증 불가. 통과시키면 검증이 없는 것과 같으므로 실패로 둔다.
      console.error('PLAY_SERVICE_ACCOUNT_JSON 미설정')
      return Response.json({ ok: false, reason: 'server_misconfigured' }, { status: 503 })
    }
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
        const errText = await res.text()
        console.error('play api error', res.status, errText)
        return Response.json({ ok: false, reason: 'upstream_error' }, { status: 502 })
      }
      purchase = await res.json()
    } catch (e) {
      console.error('verify failed', e)
      return Response.json({ ok: false, reason: 'exception' }, { status: 500 })
    }

    // 상태 확인. purchaseState: 0=구매완료, 1=취소, 2=보류
    const state = Number(purchase.purchaseState ?? -1)
    if (state !== 0) {
      return Response.json({ ok: false, reason: state === 2 ? 'pending' : 'invalid' })
    }
    reuseKey = purchaseToken
    orderId = (purchase.orderId as string) ?? null
  }

  // 3) 재사용 방지 — 같은 거래를 여러 계정이 쓰지 못하게 서버에 못박는다.
  //    (앱 로컬 원장은 기기별이라 계정 간 재사용을 막지 못한다.)
  //    Android=purchaseToken, iOS=transaction_id 를 키로 쓴다.
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )
  const { data: existing } = await admin
    .from('verified_purchases')
    .select('user_id')
    .eq('purchase_token', reuseKey)
    .maybeSingle()

  if (existing && existing.user_id !== uid) {
    return Response.json({ ok: false, reason: 'owned_by_other' })
  }
  if (!existing) {
    const { error } = await admin.from('verified_purchases').insert({
      purchase_token: reuseKey,
      user_id: uid,
      product_id: productId,
      order_id: orderId,
    })
    // 동시 요청으로 unique 충돌이 나면 이미 기록된 것이므로 성공으로 본다.
    if (error && !String(error.message).includes('duplicate')) {
      console.error('record failed', error)
      return Response.json({ ok: false, reason: 'record_failed' }, { status: 500 })
    }
  }

  return Response.json({ ok: true })
})
