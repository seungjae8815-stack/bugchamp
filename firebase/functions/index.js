// Crashlytics 알림 → 텔레그램(곤충키우기 전용 봇 @bugchamp_bot) 중계 — 2026-09-15.
//
// Firebase 는 크래시 알림을 이메일로만 보낸다. 운영 알림(결제·서버·리포트)은 전부 텔레그램에
// 모이므로, 크래시만 메일함에 따로 있으면 놓친다. Firebase Alerts 이벤트를 받아 봇으로 넘긴다.
//
// 시크릿(Secret Manager): TELEGRAM_BOT_TOKEN — Cloud Run 서버와 같은 전용 봇 토큰.
// 배포: firebase/ 폴더에서 `firebase deploy --only functions:ops`
const {
  onNewFatalIssuePublished,
  onNewAnrIssuePublished,
  onRegressionAlertPublished,
  onVelocityAlertPublished,
} = require('firebase-functions/v2/alerts/crashlytics');
const { defineSecret } = require('firebase-functions/params');

const BOT_TOKEN = defineSecret('TELEGRAM_BOT_TOKEN');
const CHAT_ID = '1025640548';
const CONSOLE = 'https://console.firebase.google.com/project/bugchamp/crashlytics';

async function send(text) {
  try {
    const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN.value()}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: CHAT_ID, text, disable_web_page_preview: true }),
    });
    if (!res.ok) console.error('telegram', res.status, await res.text());
  } catch (e) {
    console.error('telegram exception', e);
  }
}

/** 어느 앱(스토어/개발자)인지 — appId 끝자리로 구분한다. */
function appLabel(event) {
  const id = String(event.appId || '');
  return id.includes('22c2fe9c7318e4ce') ? '개발자 앱' : '스토어 앱';
}

function issueLines(issue) {
  return [
    `${issue.title || '(제목 없음)'}`,
    issue.subtitle ? `${issue.subtitle}` : null,
    issue.appVersion ? `버전 ${issue.appVersion}` : null,
    `확인: ${CONSOLE}`,
  ].filter(Boolean);
}

const opts = { secrets: [BOT_TOKEN] };

exports.crashNewFatal = onNewFatalIssuePublished(opts, async (event) => {
  const { issue } = event.data.payload;
  await send([`💥 새 크래시(앱 종료) · ${appLabel(event)}`, ...issueLines(issue)].join('\n'));
});

exports.crashNewAnr = onNewAnrIssuePublished(opts, async (event) => {
  const { issue } = event.data.payload;
  await send([`🧊 새 멈춤(ANR) · ${appLabel(event)}`, ...issueLines(issue)].join('\n'));
});

exports.crashRegression = onRegressionAlertPublished(opts, async (event) => {
  const { issue } = event.data.payload;
  await send([`↩️ 고쳤던 크래시 재발 · ${appLabel(event)}`, ...issueLines(issue)].join('\n'));
});

exports.crashVelocity = onVelocityAlertPublished(opts, async (event) => {
  const p = event.data.payload;
  const pct = p.crashPercentage != null ? `${Number(p.crashPercentage).toFixed(1)}%` : '?';
  await send(
    [
      `🔥 크래시 급증 · ${appLabel(event)}`,
      `최근 사용자 중 ${pct} 가 같은 크래시(${p.crashCount ?? '?'}건)`,
      ...issueLines(p.issue || {}),
    ].join('\n'),
  );
});
