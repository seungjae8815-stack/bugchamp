// 곤충키우기(Bug Champ) 일일 사용자 통계 → 텔레그램 발송 (Supabase Edge Function / Deno)
//
// 매일 아침 9시(KST)에 pg_cron 이 이 함수를 호출한다.
// 설정·배포·크론 등록 방법은 docs/telegram_daily_report.md 참조.
//
// 봇은 곤충키우기 전용 봇(@bugchamp_bot)이다(2026-09-15 분리 — `_shared/ops.ts` 참조).
//
// 시크릿(Edge Function Secrets):
//   TELEGRAM_BOT_TOKEN  전용 봇 토큰. 필수.
//   TELEGRAM_CHAT_ID    받는 사람 chat_id. 기본값 1025640548(강대표).
//   REPORT_SECRET       크론만 호출하도록 하는 공유 비밀. 필수(ops-watchdog 과 같은 값).
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 는 Supabase 가 자동 주입.
//
// 발송에 성공하면 `ops_heartbeat('daily_report')` 에 시각을 남긴다 — 감시 함수(ops-watchdog)가
// 9시 반까지 이 기록이 없으면 "리포트가 안 갔다"고 알린다. 2026-09 에 시크릿이 빠진 채
// 몇 주 동안 조용히 멈춰 있었다.

import { createClient } from 'jsr:@supabase/supabase-js@2'
import { BOT_TOKEN, kstDate, priceOf, sendTelegram, won } from '../_shared/ops.ts'

const SECRET = Deno.env.get('REPORT_SECRET') ?? ''

/** 천단위 콤마 */
function fmt(n: unknown): string {
  return Number(n ?? 0).toLocaleString('ko-KR')
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
    await sendTelegram(`🐛 곤충키우기 (Bug Champ)\n⚠️ ${kstDate()} 통계 조회 실패\n${error.message}`)
    return new Response('stats failed', { status: 500 })
  }

  const s = (data ?? {}) as Record<string, number>

  // 3) 매출 — 가격은 상품 id 로 계산한다(`_shared/ops.ts` PRICE_KRW, iap.json 과 대조 테스트).
  //    실결제만 더한다. 테스트·프로모션은 건수만.
  let revenueLines = ''
  try {
    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString()
    const { data: all } = await admin
      .from('verified_purchases')
      .select('product_id, environment, verified_at')
    const rows = (all ?? []) as Array<{ product_id: string; environment: string; verified_at: string }>
    const real = rows.filter((r) => r.environment === 'production')
    const realToday = real.filter((r) => r.verified_at >= since)
    const sum = (xs: typeof rows) => xs.reduce((a, r) => a + priceOf(r.product_id), 0)
    const byProduct = new Map<string, number>()
    for (const r of realToday) byProduct.set(r.product_id, (byProduct.get(r.product_id) ?? 0) + 1)
    const detail = [...byProduct.entries()].map(([id, n]) => `${id} ${n}`).join(' · ')
    const testToday = rows.filter((r) => r.environment !== 'production' && r.verified_at >= since).length
    revenueLines =
      `💰 매출(24h): ${won(sum(realToday))} · ${fmt(realToday.length)}건` +
      (detail ? `\n   ${detail}` : '') +
      (testToday > 0 ? `\n   (테스트 결제 ${fmt(testToday)}건 제외)` : '') +
      `\n💵 누적 매출: ${won(sum(real))} · ${fmt(real.length)}건`
  } catch (e) {
    console.error('revenue failed', e)
    revenueLines = `💰 매출: 조회 실패`
  }

  // D1 리텐션 — 어제 신규 중 오늘 돌아온 비율. 분모가 0이면 표시하지 않는다.
  const d1 = s.d1_new > 0 ? Math.round((s.d1_returned / s.d1_new) * 100) : null

  const msg =
    `🐛 곤충키우기 (Bug Champ)\n` +
    `📅 ${kstDate()} 리포트\n` +
    `\n` +
    `🎮 실사용(24h): ${fmt(s.dau)}명\n` +
    `📆 주간(7일): ${fmt(s.wau)}명\n` +
    `🗓 월간(30일): ${fmt(s.mau)}명\n` +
    `🌱 정착 사용자: ${fmt(s.retained)}명\n` +
    (d1 === null
      ? `🔁 D1 리텐션: -\n`
      : `🔁 D1 리텐션: ${d1}% (${fmt(s.d1_new)}명 중 ${fmt(s.d1_returned)}명)\n`) +
    `\n` +
    `🔑 로그인 유저: ${fmt(s.linked)}명 ` +
    `(구글 ${fmt(s.linked_google)}·애플 ${fmt(s.linked_apple)})\n` +
    `💾 세이브 보유자: ${fmt(s.saves_total)}명\n` +
    `👥 누적 계정(익명포함): ${fmt(s.installs)}명\n` +
    `🆕 오늘 신규: ${fmt(s.new_today)}명\n` +
    `\n` +
    revenueLines

  const ok = await sendTelegram(msg)
  if (ok) {
    // 감시 함수가 읽는 발송 기록. 실패해도 리포트는 이미 갔으므로 응답은 성공.
    const { error: hbErr } = await admin
      .from('ops_heartbeat')
      .upsert({ name: 'daily_report', last_ok_at: new Date().toISOString(), fail_count: 0 })
    if (hbErr) console.error('heartbeat failed', hbErr)
  }
  return Response.json({ ok, stats: s })
})
