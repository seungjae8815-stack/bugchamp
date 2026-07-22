// 곤충키우기(Bug Champ) 일일 사용자 통계 → 텔레그램 발송 (Supabase Edge Function / Deno)
//
// 매일 아침 9시(KST)에 pg_cron 이 이 함수를 호출한다.
// 설정·배포·크론 등록 방법은 docs/telegram_daily_report.md 참조.
//
// ⚠️ 같은 텔레그램 봇을 아스트레일 앱도 쓰므로, 메시지 맨 앞에 반드시
//    "🐛 곤충키우기 (Bug Champ)" 를 붙여 어느 앱 통계인지 구분한다.
//
// 시크릿(Edge Function Secrets):
//   TELEGRAM_BOT_TOKEN  봇 토큰(아스트레일과 공유하는 그 봇). 필수.
//   TELEGRAM_CHAT_ID    받는 사람 chat_id. 기본값 1025640548(강대표).
//   REPORT_SECRET       크론만 호출하도록 하는 공유 비밀. 필수.
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 는 Supabase 가 자동 주입.

import { createClient } from 'jsr:@supabase/supabase-js@2'

const BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN') ?? ''
const CHAT_ID = Deno.env.get('TELEGRAM_CHAT_ID') ?? '1025640548'
const SECRET = Deno.env.get('REPORT_SECRET') ?? ''

/** UTC → KST(+9) 로 보정한 YYYY-MM-DD */
function kstDate(): string {
  const kst = new Date(Date.now() + 9 * 3600 * 1000)
  return kst.toISOString().slice(0, 10)
}

/** 천단위 콤마 */
function fmt(n: unknown): string {
  return Number(n ?? 0).toLocaleString('ko-KR')
}

async function sendTelegram(text: string): Promise<void> {
  const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: CHAT_ID,
      text,
      disable_web_page_preview: true,
    }),
  })
  if (!res.ok) throw new Error(`telegram ${res.status}: ${await res.text()}`)
}

Deno.serve(async (req) => {
  // 1) 크론만 호출할 수 있도록 공유 비밀 확인(봇 스팸/무단 트리거 방지).
  //    비밀은 쿼리스트링(?secret=) 또는 POST 바디({"secret":...}) 로 받는다.
  let provided = new URL(req.url).searchParams.get('secret') ?? ''
  if (!provided && req.method === 'POST') {
    try {
      provided = String((await req.json()).secret ?? '')
    } catch {
      /* 바디 없음 무시 */
    }
  }
  if (!SECRET || provided !== SECRET) {
    return new Response('forbidden', { status: 403 })
  }

  if (!BOT_TOKEN) {
    console.error('TELEGRAM_BOT_TOKEN 미설정')
    return new Response('bot token missing', { status: 503 })
  }

  // 2) 통계 집계(service_role 로 RLS 우회 — auth.users 카운트 등).
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const { data, error } = await admin.rpc('bugchamp_daily_stats')
  if (error) {
    console.error('stats rpc failed', error)
    // 통계 실패해도 "실패했다"는 사실은 알려야 문제를 인지한다.
    await sendTelegram(
      `🐛 곤충키우기 (Bug Champ)\n⚠️ ${kstDate()} 통계 조회 실패\n${error.message}`,
    )
    return new Response('stats failed', { status: 500 })
  }

  const s = (data ?? {}) as Record<string, number>
  const msg =
    `🐛 곤충키우기 (Bug Champ)\n` +
    `📅 ${kstDate()} 리포트\n` +
    `\n` +
    `👥 총 사용자      ${fmt(s.total_users)}명\n` +
    `🆕 오늘 신규      ${fmt(s.new_today)}명\n` +
    `🎮 최근 24h 활동  ${fmt(s.active_24h)}명\n` +
    `⚔️ PvP 참여       ${fmt(s.pvp_players)}명\n` +
    `💰 누적 결제      ${fmt(s.purchases_total)}건`

  await sendTelegram(msg)
  return Response.json({ ok: true, stats: s })
})
