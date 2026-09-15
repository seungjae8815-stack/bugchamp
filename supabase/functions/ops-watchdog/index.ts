// 운영 감시(Supabase Edge Function / Deno) — 10분마다 pg_cron 이 부른다(2026-09-15).
//
// 1. **서버 생존**: 권위 서버 /health 를 부른다. **연속 2번** 실패하면 알리고, 되살아나면 복구를 알린다.
//    서버가 죽으면 서버 스스로는 알릴 수 없다 — 그래서 바깥(Supabase)에서 본다.
// 2. **리포트 누락**: 9시 반(KST)이 지났는데 오늘 리포트 발송 기록이 없으면 하루 한 번 알린다.
//    2026-09 에 리포트 시크릿이 빠진 채 몇 주 동안 조용히 멈춰 있었다.
// 3. **채팅 요약**: 새 채팅이 기준(ops_settings.chat_summary_min, 기본 5)만큼 쌓이면 묶어서 보낸다.
//
// 상태는 `ops_heartbeat` 표에 둔다(연속 실패 수·마지막 알림 시각). 함수는 매번 새로 뜨므로 메모리에 못 둔다.
//
// 시크릿: REPORT_SECRET(daily-report 와 같은 값) · TELEGRAM_BOT_TOKEN · SERVER_URL(선택)

import { createClient } from 'jsr:@supabase/supabase-js@2'
import { kstDate, kstTodayStartIso, sendTelegram } from '../_shared/ops.ts'

const SECRET = Deno.env.get('REPORT_SECRET') ?? ''
const SERVER_URL =
  Deno.env.get('SERVER_URL') ?? 'https://bugchamp-server-867649520275.asia-northeast3.run.app'

/** 연속 몇 번 실패하면 알리나. 1번이면 Cloud Run 콜드 스타트 한 번에도 울린다. */
const FAILS_TO_ALERT = 2

type Beat = { name: string; last_ok_at: string | null; fail_count: number; alerted_at: string | null }

Deno.serve(async (req) => {
  let provided = new URL(req.url).searchParams.get('secret') ?? ''
  if (!provided && req.method === 'POST') {
    try {
      provided = String((await req.json()).secret ?? '')
    } catch {
      /* 바디 없음 */
    }
  }
  if (!SECRET || provided !== SECRET) return new Response('forbidden', { status: 403 })

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { data } = await admin.from('ops_heartbeat').select('*')
  const beats = new Map<string, Beat>(((data ?? []) as Beat[]).map((b) => [b.name, b]))
  const now = new Date()
  const report: Record<string, unknown> = {}

  // ── 1. 서버 생존 ──
  const prev = beats.get('server_health') ?? { name: 'server_health', last_ok_at: null, fail_count: 0, alerted_at: null }
  let healthy = false
  let why = ''
  try {
    const res = await fetch(`${SERVER_URL}/health`, { signal: AbortSignal.timeout(15000) })
    healthy = res.ok
    if (!healthy) why = `HTTP ${res.status}`
  } catch (e) {
    why = String(e).slice(0, 120)
  }
  if (healthy) {
    if (prev.fail_count >= FAILS_TO_ALERT) {
      await sendTelegram(`✅ 곤충키우기 서버 복구\n${prev.fail_count * 10}분가량 응답이 없었습니다.`)
    }
    await admin.from('ops_heartbeat').upsert({
      name: 'server_health',
      last_ok_at: now.toISOString(),
      fail_count: 0,
      alerted_at: null,
    })
  } else {
    const fails = prev.fail_count + 1
    if (fails === FAILS_TO_ALERT) {
      await sendTelegram(
        `🚨 곤충키우기 서버 응답 없음\n10분 간격으로 ${fails}번 연속 실패 · ${why}\n` +
          `확인: gcloud run services logs read bugchamp-server --region asia-northeast3 --limit 50`,
      )
    }
    await admin.from('ops_heartbeat').upsert({
      name: 'server_health',
      last_ok_at: prev.last_ok_at,
      fail_count: fails,
      alerted_at: fails >= FAILS_TO_ALERT ? now.toISOString() : prev.alerted_at,
    })
  }
  report.server = healthy ? 'ok' : `fail(${why})`

  // ── 2. 리포트 누락(09:30 KST 이후) ──
  const kstMinutes = ((now.getUTCHours() + 9) % 24) * 60 + now.getUTCMinutes()
  const todayStart = kstTodayStartIso(now)
  const nineKst = new Date(new Date(todayStart).getTime() + 9 * 3600 * 1000).toISOString()
  if (kstMinutes >= 9 * 60 + 30) {
    const rb = beats.get('daily_report')
    const sentToday = !!rb?.last_ok_at && rb.last_ok_at >= nineKst
    const alertedToday = !!rb?.alerted_at && rb.alerted_at >= todayStart
    if (!sentToday && !alertedToday) {
      await sendTelegram(
        `⚠️ ${kstDate(now)} 일일 리포트가 발송되지 않았습니다\n` +
          `마지막 발송: ${rb?.last_ok_at ?? '기록 없음'}\n` +
          `확인: SQL Editor → select * from cron.job_run_details order by start_time desc limit 5;`,
      )
      await admin.from('ops_heartbeat').upsert({
        name: 'daily_report',
        last_ok_at: rb?.last_ok_at ?? null,
        fail_count: (rb?.fail_count ?? 0) + 1,
        alerted_at: now.toISOString(),
      })
    }
    report.dailyReport = sentToday ? 'sent' : 'missing'
  }

  // ── 3. 채팅 요약(2026-09-15) ──
  // 마지막으로 보낸 뒤 새 채팅이 기준(기본 5건, 텔레그램 `/chatmin`)만큼 쌓이면 묶어서 보낸다.
  // 기준보다 적으면 **기다렸다가** 다음 확인 때 이어서 센다(보내지 않은 채팅은 사라지지 않는다).
  // 커서가 없으면(첫 실행) 지금부터 센다 — 옛날 채팅을 한꺼번에 쏟지 않는다.
  try {
    const setting = async (key: string) => {
      const { data } = await admin.from('ops_settings').select('value').eq('key', key).maybeSingle()
      return (data as { value?: string } | null)?.value ?? null
    }
    const min = Math.max(1, Number(await setting('chat_summary_min')) || 5)
    const cursor = await setting('chat_summary_cursor')
    if (!cursor) {
      await admin.from('ops_settings').upsert({ key: 'chat_summary_cursor', value: now.toISOString() })
      report.chat = 'cursor-init'
    } else {
      const { data: rows } = await admin
        .from('chat_messages')
        .select('id, nickname, body, created_at, is_admin')
        .gt('created_at', cursor)
        .order('created_at', { ascending: true })
        .limit(300)
      const chats = (rows ?? []) as Array<{
        id: number
        nickname: string
        body: string
        created_at: string
        is_admin?: boolean
      }>
      report.chat = chats.length
      if (chats.length >= min) {
        const hm = (iso: string) => {
          const k = new Date(new Date(iso).getTime() + 9 * 3600 * 1000)
          return `${String(k.getUTCHours()).padStart(2, '0')}:${String(k.getUTCMinutes()).padStart(2, '0')}`
        }
        const people = new Set(chats.map((c) => c.nickname)).size
        const lines = chats.map(
          (c) => `#${c.id} ${hm(c.created_at)} ${c.is_admin ? '📢' : ''}${c.nickname}: ${c.body}`,
        )
        const head =
          `💬 채팅 요약 ${hm(chats[0].created_at)}~${hm(chats[chats.length - 1].created_at)} · ` +
          `${chats.length}건 · ${people}명\n(삭제: /del 번호 · 기준 바꾸기: /chatmin 숫자)`
        // 텔레그램 한도(4096자) 안으로 나눠 보낸다.
        let chunk = head
        for (const line of lines) {
          if (chunk.length + line.length + 1 > 3900) {
            await sendTelegram(chunk)
            chunk = ''
          }
          chunk += (chunk ? '\n' : '') + line
        }
        if (chunk) await sendTelegram(chunk)
        await admin
          .from('ops_settings')
          .upsert({ key: 'chat_summary_cursor', value: chats[chats.length - 1].created_at })
      }
    }
  } catch (e) {
    console.error('chat summary failed', e)
  }

  return Response.json({ ok: true, ...report })
})
