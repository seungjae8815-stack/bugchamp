// 운영 알림 공용 — 텔레그램 발송 · 상품 가격 · 한국 날짜.
//
// 봇은 **곤충키우기 전용 봇(@bugchamp_bot)** 이다(2026-09-15). 예전엔 아스트레일 봇을 같이 썼는데,
// 그 봇을 UGC 서버가 getUpdates 로 받고 있어서 곤충키우기 웹훅을 거는 순간 UGC 가 멈췄다.
//
// 시크릿: TELEGRAM_BOT_TOKEN(필수) · TELEGRAM_CHAT_ID(기본 1025640548)

export const BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN') ?? ''
export const CHAT_ID = Deno.env.get('TELEGRAM_CHAT_ID') ?? '1025640548'

/** 상품 id → 원화 가격. ⚠️ `packages/app/assets/data/iap.json` 과 같아야 한다 —
 *  앱 테스트(`ops_prices_test.dart`)가 두 파일을 대조한다. iOS 전용 id(iosId)도 같은 가격으로 둔다. */
export const PRICE_KRW: Record<string, number> = {
  starter_pack: 5500,
  idle_pass: 9900,
  idle_pass_c: 9900,
  jelly_s: 1200,
  jelly_m: 5500,
  jelly_l: 11000,
  jelly_xl: 29000,
  jelly_xxl: 59000,
  skin_gold_rhino: 3300,
  skin_albino_stag: 3300,
  theme_arena: 2200,
  buff_pass: 6600,
  remove_ads: 0,
}

export const priceOf = (productId: string): number => PRICE_KRW[productId] ?? 0

export const won = (n: number): string => `₩${Math.round(n).toLocaleString('ko-KR')}`

/** 한국 시간 기준 오늘 00:00 의 UTC ISO 문자열. */
export function kstTodayStartIso(now = new Date()): string {
  const kst = new Date(now.getTime() + 9 * 3600 * 1000)
  const start = Date.UTC(kst.getUTCFullYear(), kst.getUTCMonth(), kst.getUTCDate()) - 9 * 3600 * 1000
  return new Date(start).toISOString()
}

export function kstDate(now = new Date()): string {
  return new Date(now.getTime() + 9 * 3600 * 1000).toISOString().slice(0, 10)
}

/** 텔레그램 발송. **실패해도 던지지 않는다** — 알림 때문에 결제·리포트 본 작업이 깨지면 안 된다.
 *  성공 여부만 돌려준다. */
export async function sendTelegram(text: string): Promise<boolean> {
  if (!BOT_TOKEN) {
    console.error('[ops] TELEGRAM_BOT_TOKEN 미설정')
    return false
  }
  try {
    const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      // 유저가 쓴 글(닉네임)이 섞이므로 서식 해석(parse_mode)을 쓰지 않는다.
      body: JSON.stringify({ chat_id: CHAT_ID, text, disable_web_page_preview: true }),
    })
    if (!res.ok) console.error('[ops] telegram', res.status, await res.text())
    return res.ok
  } catch (e) {
    console.error('[ops] telegram exception', e)
    return false
  }
}
