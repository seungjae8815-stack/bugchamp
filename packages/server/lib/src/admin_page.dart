/// 운영 관리 패널(단일 HTML).
///
/// **서버가 직접 서빙한다.** 이 화면이 다루는 테이블(notices·user_mail·
/// gift_codes)은 RLS 로 클라이언트 직접 접근이 막혀 있고, 쓰려면 `service_role`
/// 키가 필요하다. 그 키는 DB 전체 권한이라 브라우저(정적 호스팅·Vercel)에
/// 두면 모든 유저의 세이브가 노출된다. 서버가 키를 쥐고 있으므로 여기서
/// 서빙하면 키가 브라우저로 나갈 일이 없다.
///
/// 파일이 아니라 **문자열 상수**인 이유: 컨테이너 이미지에 정적 파일 경로를
/// 하나 더 의존하지 않기 위해서다(배포 형태가 바뀌어도 깨지지 않는다).
library;

const String adminHtml = r'''<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>벌레챔프 운영</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin:0; background:#0B1206; color:#E9E4D6;
         font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }
  header { position:sticky; top:0; background:#141F0E; border-bottom:1px solid #2A3A22;
           padding:12px 16px; display:flex; align-items:center; gap:10px; z-index:5; }
  header h1 { font-size:15px; margin:0; font-weight:800; color:#EBA52F; }
  main { padding:14px; max-width:720px; margin:0 auto; }
  .tabs { display:flex; gap:6px; margin-bottom:14px; }
  .tabs button { flex:1; padding:9px 0; border:1px solid #2A3A22; background:#141F0E;
                 color:#BFC4B8; border-radius:9px; font-weight:700; font-size:13px; }
  .tabs button.on { background:#25401C; color:#fff; border-color:#3E7D4F; }
  section { display:none; } section.on { display:block; }
  .card { background:#141F0E; border:1px solid #2A3A22; border-radius:12px;
          padding:13px; margin-bottom:12px; }
  .card h2 { font-size:13px; margin:0 0 10px; color:#EBA52F; font-weight:800; }
  label { display:block; font-size:11.5px; color:#9AA893; margin:9px 0 3px; }
  input, textarea, select { width:100%; padding:9px 10px; background:#0B1206; color:#E9E4D6;
          border:1px solid #2A3A22; border-radius:8px; font-size:14px; font-family:inherit; }
  textarea { min-height:64px; resize:vertical; }
  .row { display:flex; gap:8px; } .row > * { flex:1; }
  button.act { width:100%; margin-top:12px; padding:11px; border:0; border-radius:9px;
               background:#3E7D4F; color:#fff; font-weight:800; font-size:14px; }
  button.act.warn { background:#B4552E; }
  button.act:disabled { opacity:.5; }
  .item { border-top:1px solid #22301B; padding:9px 0; display:flex; gap:10px;
          align-items:flex-start; }
  .item:first-of-type { border-top:0; }
  .item .body { flex:1; min-width:0; }
  .item b { font-size:13px; } .item .sub { font-size:11px; color:#8D9A86; word-break:break-all; }
  .item button { background:#3A211B; color:#E9A08A; border:1px solid #5A3128;
                 border-radius:7px; padding:5px 9px; font-size:11.5px; }
  .pill { display:inline-block; background:#25401C; color:#BFE3A6; border-radius:99px;
          padding:1px 7px; font-size:10.5px; margin-right:4px; }
  .hint { font-size:11.5px; color:#8D9A86; margin-top:6px; }
  #toast { position:fixed; left:50%; bottom:22px; transform:translateX(-50%);
           background:#000A; border:1px solid #ffffff33; padding:10px 16px; border-radius:10px;
           font-size:13px; opacity:0; transition:opacity .2s; pointer-events:none; max-width:90%; }
  #toast.on { opacity:1; }
  #gate { padding:40px 16px; max-width:360px; margin:0 auto; text-align:center; }
</style>
</head>
<body>
<div id="gate">
  <h1 style="color:#EBA52F;font-size:17px">벌레챔프 운영</h1>
  <p class="hint">관리 키를 입력하세요.</p>
  <input id="key" type="password" placeholder="ADMIN KEY" autocomplete="off">
  <button class="act" onclick="login()">들어가기</button>
</div>

<div id="app" style="display:none">
<header>
  <h1>벌레챔프 운영</h1>
  <span class="hint" id="who"></span>
  <span style="flex:1"></span>
  <button class="item-btn" onclick="logout()"
     style="background:#22301B;color:#BFC4B8;border:1px solid #2A3A22;border-radius:7px;padding:5px 9px">나가기</button>
</header>
<main>
  <div class="tabs">
    <button id="t-user" onclick="tab('user')">유저</button>
    <button id="t-notice" class="on" onclick="tab('notice')">공지</button>
    <button id="t-mail" onclick="tab('mail')">우편</button>
    <button id="t-code" onclick="tab('code')">선물코드</button>
    <button id="t-chat" onclick="tab('chat')">채팅</button>
    <button id="t-grant" onclick="tab('grant')">지급</button>
  </div>

  <section id="s-user">
    <div class="card">
      <h2>유저 상태 보기</h2>
      <p class="hint">닉네임이나 uuid 로 찾습니다. 문의를 받으면 여기부터 보세요.</p>
      <div class="row">
        <div><label>닉네임</label><input id="u-nick" placeholder="크론병"></div>
        <div><label>또는 uuid</label><input id="u-uid" placeholder="00000000-0000-..."></div>
      </div>
      <button class="act" onclick="findUser()">찾기</button>
      <div id="u-result"></div>
    </div>
  </section>

  <section id="s-notice" class="on">
    <div class="card">
      <h2>공지 쓰기</h2>
      <label>제목</label><input id="n-title" maxlength="100">
      <label>본문</label><textarea id="n-body" maxlength="1000"></textarea>
      <div class="row">
        <div><label>고정</label>
          <select id="n-pinned"><option value="false">아니오</option><option value="true">예</option></select></div>
        <div><label>종료일 (비우면 무기한)</label><input id="n-ends" type="date"></div>
      </div>
      <button class="act" onclick="createNotice()">공지 올리기</button>
    </div>
    <div class="card"><h2>올라간 공지</h2><div id="list-notice"></div></div>
  </section>

  <section id="s-mail">
    <div class="card">
      <h2>우편 보내기</h2>
      <label>받는 사람</label>
      <select id="m-target">
        <option value="">전체 유저</option>
        <option value="one">특정 유저(uuid)</option>
      </select>
      <div id="m-uid-wrap" style="display:none">
        <label>유저 uuid</label><input id="m-uid" placeholder="00000000-0000-...">
      </div>
      <label>제목</label><input id="m-title" maxlength="100" value="점검 보상">
      <label>본문</label><textarea id="m-body" maxlength="1000">불편을 드려 죄송합니다.</textarea>
      <div class="row">
        <div><label>골드</label><input id="m-gold" type="number" value="0" min="0"></div>
        <div><label>젤리</label><input id="m-jelly" type="number" value="0" min="0"></div>
      </div>
      <div class="row">
        <div><label>키틴</label><input id="m-chitin" type="number" value="0" min="0"></div>
        <div><label>미네랄</label><input id="m-mineral" type="number" value="0" min="0"></div>
        <div><label>수액</label><input id="m-sap" type="number" value="0" min="0"></div>
      </div>
      <label>수령 기한 (비우면 무기한)</label><input id="m-ends" type="date">
      <button class="act warn" onclick="createMail()">우편 보내기</button>
      <p class="hint">전체 발송은 되돌릴 수 없습니다. 이미 받은 유저의 재화는 회수되지 않습니다.</p>
    </div>
    <div class="card"><h2>보낸 우편</h2><div id="list-mail"></div></div>
  </section>

  <section id="s-code">
    <div class="card">
      <h2>선물코드 만들기</h2>
      <label>코드 (영문 대문자·숫자)</label><input id="c-code" maxlength="32" placeholder="BUGCHAMP100">
      <div class="row">
        <div><label>골드</label><input id="c-gold" type="number" value="0" min="0"></div>
        <div><label>젤리</label><input id="c-jelly" type="number" value="0" min="0"></div>
      </div>
      <div class="row">
        <div><label>키틴</label><input id="c-chitin" type="number" value="0" min="0"></div>
        <div><label>미네랄</label><input id="c-mineral" type="number" value="0" min="0"></div>
        <div><label>수액</label><input id="c-sap" type="number" value="0" min="0"></div>
      </div>
      <div class="row">
        <div><label>수량 (비우면 무제한)</label><input id="c-max" type="number" min="1"></div>
        <div><label>종료일</label><input id="c-ends" type="date"></div>
      </div>
      <button class="act" onclick="createCode()">코드 만들기</button>
      <p class="hint">계정당 1회만 사용할 수 있습니다.</p>
    </div>
    <div class="card"><h2>만든 코드</h2><div id="list-code"></div></div>
  </section>

  <section id="s-grant">
    <div class="card">
      <h2>상품 지급</h2>
      <p class="hint">결제와 <b>같은 경로</b>로 넣습니다 — 패스 연장·스타터 1회 제한이 결제와 똑같이 적용됩니다.</p>
      <label>유저 uuid</label><input id="g-uid" placeholder="00000000-0000-...">
      <label>상품</label><select id="g-product"></select>
      <label>사유 (중복 지급을 막는 열쇠)</label>
      <input id="g-reason" maxlength="48" placeholder="2026-09-보상">
      <button class="act warn" onclick="grantProduct()">지급하기</button>
      <p class="hint">
        같은 유저 · 같은 상품 · 같은 사유로 두 번 누르면 두 번째는 무시됩니다(중복 방지).
        일부러 더 주려면 사유를 바꾸세요 — 예: <b>2026-09-보상2</b>.
      </p>
      <div id="g-result" class="sub"></div>
    </div>
  </section>

  <section id="s-chat">
    <div class="card">
      <h2>운영자로 보내기</h2>
      <label>표시 이름</label><input id="h-nick" maxlength="20" value="운영자">
      <label>메시지 (100자)</label><textarea id="h-body" maxlength="100"></textarea>
      <button class="act" onclick="sendChat()">채팅에 보내기</button>
      <p class="hint">전체 채팅에 바로 나갑니다. 지우려면 아래 목록에서 삭제하세요.</p>
    </div>
    <div class="card"><h2>최근 채팅</h2><div id="list-chat"></div></div>
  </section>
</main>
</div>
<div id="toast"></div>

<script>
let KEY = sessionStorage.getItem('adminKey') || '';

function toast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg; t.className = 'on';
  setTimeout(() => t.className = '', 2200);
}
function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"]/g,
    c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
}
async function api(path, body) {
  const res = await fetch(path, {
    method: body ? 'POST' : 'GET',
    headers: { 'x-admin-key': KEY, 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = {};
  try { json = await res.json(); } catch (e) {}
  if (!res.ok) throw new Error(json.error || ('HTTP ' + res.status));
  return json;
}
async function login() {
  KEY = document.getElementById('key').value.trim();
  if (!KEY) return;
  try {
    await api('/admin/data');
    sessionStorage.setItem('adminKey', KEY);
    document.getElementById('gate').style.display = 'none';
    document.getElementById('app').style.display = 'block';
    refresh();
  } catch (e) { toast('키가 올바르지 않습니다'); }
}
function logout() { sessionStorage.removeItem('adminKey'); location.reload(); }
function tab(name) {
  if (name === 'grant') loadProducts();
  for (const n of ['user','notice','mail','code','chat','grant']) {
    document.getElementById('s-' + n).className = n === name ? 'on' : '';
    document.getElementById('t-' + n).className = n === name ? 'on' : '';
  }
}
document.getElementById('m-target').onchange = e => {
  document.getElementById('m-uid-wrap').style.display = e.target.value ? 'block' : 'none';
};
function day(v) { return v ? new Date(v + 'T23:59:59Z').toISOString() : null; }
function fmt(v) { return v ? new Date(v).toISOString().slice(0, 10) : '무기한'; }
function rewardPills(r) {
  const p = [];
  if (r.gold > 0) p.push('골드 ' + r.gold.toLocaleString());
  if (r.jelly > 0) p.push('젤리 ' + r.jelly);
  if (r.chitin > 0) p.push('키틴 ' + r.chitin);
  if (r.mineral > 0) p.push('미네랄 ' + r.mineral);
  if (r.sap > 0) p.push('수액 ' + r.sap);
  return p.map(x => '<span class="pill">' + esc(x) + '</span>').join('');
}

async function refresh() {
  const d = await api('/admin/data');
  document.getElementById('list-notice').innerHTML = (d.notices || []).map(n =>
    '<div class="item"><div class="body"><b>' + (n.pinned ? '📌 ' : '') + esc(n.title) +
    '</b><div class="sub">' + esc(n.body) + '</div>' +
    '<div class="sub">종료 ' + fmt(n.ends_at) + '</div></div>' +
    '<button onclick="del(\'notice\',\'' + n.id + '\')">삭제</button></div>'
  ).join('') || '<div class="sub">없음</div>';

  document.getElementById('list-mail').innerHTML = (d.mail || []).map(m =>
    '<div class="item"><div class="body"><b>' + esc(m.title) + '</b> ' +
    '<span class="sub">' + (m.user_id ? '개인' : '전체') + '</span>' +
    '<div>' + rewardPills(m) + '</div>' +
    '<div class="sub">기한 ' + fmt(m.ends_at) + '</div></div>' +
    '<button onclick="del(\'mail\',\'' + m.id + '\')">삭제</button></div>'
  ).join('') || '<div class="sub">없음</div>';

  document.getElementById('list-code').innerHTML = (d.codes || []).map(c =>
    '<div class="item"><div class="body"><b>' + esc(c.code) + '</b>' +
    '<div>' + rewardPills(c) + '</div>' +
    '<div class="sub">사용 ' + c.used_count + (c.max_uses ? ' / ' + c.max_uses : '') +
    ' · 종료 ' + fmt(c.ends_at) + '</div></div>' +
    '<button onclick="del(\'code\',\'' + esc(c.code) + '\')">삭제</button></div>'
  ).join('') || '<div class="sub">없음</div>';

  document.getElementById('list-chat').innerHTML = (d.chat || []).map(c =>
    '<div class="item"><div class="body"><b>' + esc(c.nickname) + '</b>' +
    (c.is_admin ? ' <span class="pill">운영자</span>' : '') +
    '<div class="sub">' + esc(c.body) + '</div>' +
    '<div class="sub">' + esc((c.created_at || '').replace('T', ' ').slice(0, 16)) +
    '</div></div>' +
    '<button onclick="del(\'chat\',\'' + c.id + '\')">삭제</button></div>'
  ).join('') || '<div class="sub">없음</div>';
}

async function sendChat() {
  const body = val('h-body');
  if (!body) return toast('메시지를 입력하세요');
  try {
    await api('/admin/chat', { nickname: val('h-nick') || '운영자', body: body });
    document.getElementById('h-body').value = '';
    toast('채팅에 보냈습니다'); refresh();
  } catch (e) {
    toast(e.message === 'admin_chat_user_id_missing'
      ? 'ADMIN_CHAT_USER_ID 가 설정되지 않았습니다' : e.message);
  }
}

function ago(iso) {
  if (!iso) return '기록 없음';
  const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (m < 1) return '방금';
  if (m < 60) return m + '분 전';
  if (m < 1440) return Math.floor(m / 60) + '시간 전';
  return Math.floor(m / 1440) + '일 전';
}
function n(v) { return (v == null) ? '-' : Number(v).toLocaleString(); }
function row(k, v) {
  return '<div class="item"><div class="body"><span class="sub">' + esc(k) +
         '</span><div><b>' + v + '</b></div></div></div>';
}

async function findUser() {
  const uid = val('u-uid'), nick = val('u-nick');
  if (!uid && !nick) return toast('닉네임이나 uuid 를 입력하세요');
  const box = document.getElementById('u-result');
  box.innerHTML = '<div class="sub">찾는 중...</div>';
  try {
    const r = await api('/admin/user', uid ? { userId: uid } : { nickname: nick });
    // 닉네임이 겹치면 고르게 한다 — 임의로 하나를 집으면 엉뚱한 계정을 본다.
    if (r.ambiguous) {
      box.innerHTML = '<div class="sub">같은 닉네임이 여럿입니다 — 고르세요</div>' +
        r.candidates.map(c =>
          '<div class="item"><div class="body"><b>' + esc(c.nickname) + '</b>' +
          '<div class="sub">Lv ' + n(c.level) + ' · 스테이지 ' + n(c.stage) +
          ' · 트로피 ' + n(c.trophies) + '</div>' +
          '<div class="sub">' + esc(c.id) + '</div></div>' +
          '<button onclick="pickUser(\'' + c.id + '\')">보기</button></div>'
        ).join('');
      return;
    }
    const pass = r.passActive ? '켜짐 (' + r.passExpiresAt.slice(0,10) + ' 까지)'
                              : (r.passExpiresAt ? '만료됨' : '없음');
    const bpass = r.buffPassActive ? '켜짐 (' + r.buffPassExpiresAt.slice(0,10) + ' 까지)'
                                   : (r.buffPassExpiresAt ? '만료됨' : '없음');
    box.innerHTML =
      row('닉네임', esc(r.nickname) + ' <span class="sub">' + esc(r.id) + '</span>') +
      row('진행', '회차 ' + n(r.tier) + ' · 스테이지 ' + n(r.stage) + ' · Lv ' + n(r.level)) +
      row('재화', '골드 ' + n(r.gold) + ' · 젤리 ' + n(r.jelly)) +
      row('재료', '키틴 ' + n(r.chitin) + ' · 미네랄 ' + n(r.mineral) + ' · 수액 ' + n(r.sap)) +
      row('채집함', n(r.bugs) + ' / ' + n(r.storage) + ' 마리') +
      row('결투', '트로피 ' + n(r.trophies) + ' · 티켓 ' + n(r.tickets) +
          (r.eventTickets == null ? '' : ' · 대회 참가권 ' + n(r.eventTickets))) +
      row('곤충학자 패스', pass) +
      row('무한 버프 패스', bpass) +
      row('스타터', r.starterBought ? '구매함' : '없음') +
      row('결제 건수', n(r.purchases) + '건') +
      row('마지막 접속', ago(r.lastSeen)) +
      '<button class="act" onclick="toGrant(\'' + r.id + '\')">이 유저에게 지급하기</button>' +
      '<div class="card" style="margin-top:10px">' +
      '<h2>재화 정상화</h2>' +
      '<p class="hint">지난 규칙에서 쌓여 <b>지금은 도달 불가능한</b> 값을 맞춥니다. ' +
      '비운 칸은 <b>건드리지 않습니다</b>. 지금보다 큰 값은 무시됩니다 — ' +
      '정상화 도구지 지급 도구가 아닙니다.</p>' +
      '<p class="hint" style="color:#FFD98A"><b>원하는 최종 값</b>을 그대로 넣으세요 — 그 값이 그대로 저장됩니다.<br>' +
      '⚠ 유저가 <b>지금 접속 중</b>이면, 앱에 남은 옛 값이 업로드 1회 상한만큼 되올라간 뒤 멈춥니다 ' +
      '(젤리 +1,000 · 재료 +2,000만 · 골드 +20만). 결과에 그 상한선이 함께 표시됩니다.</p>' +
      (r.purchases > 0
        ? '<p class="hint" style="color:#FFB4A2"><b>결제 이력 ' + r.purchases +
          '건</b> — 산 젤리를 깎으면 환불 사유입니다. 젤리 칸은 비워 두세요.</p>'
        : '<p class="hint">결제 이력 없음</p>') +
      '<div class="row">' +
      '<div><label>골드 (지금 ' + n(r.gold) + ')</label><input id="cur-gold" type="number" min="0"></div>' +
      '<div><label>젤리 (지금 ' + n(r.jelly) + ')</label><input id="cur-jelly" type="number" min="0"></div>' +
      '</div><div class="row">' +
      '<div><label>키틴 (' + n(r.chitin) + ')</label><input id="cur-chitin" type="number" min="0"></div>' +
      '<div><label>미네랄 (' + n(r.mineral) + ')</label><input id="cur-mineral" type="number" min="0"></div>' +
      '<div><label>수액 (' + n(r.sap) + ')</label><input id="cur-sap" type="number" min="0"></div>' +
      '</div>' +
      '<p class="hint">입력 예: 젤리 <b>1500</b> · 재료 <b>20000000</b> (골드는 비워 두기)</p>' +
      '<p class="hint">⚠ 이 도구는 <b>낮추기만</b> 합니다. 되돌리려면 우편으로 차액을 보내세요.</p>' +
      '<label>사유 (서버 로그에 남습니다)</label>' +
      '<input id="cur-reason" maxlength="64" placeholder="2026-09-01 구버전 수도꼭지 정상화">' +
      '<button class="act warn" onclick="normalizeCurrency(\'' + r.id + '\')">정상화</button>' +
      '<div id="cur-result" class="sub"></div>' +
      '</div>';
    document.getElementById('u-uid').value = r.id;
  } catch (e) {
    box.innerHTML = '';
    toast(e.message === 'not_found' ? '그 닉네임의 유저가 없습니다'
        : e.message === 'no_save' ? '세이브가 없습니다'
        : e.message);
  }
}
function pickUser(id) {
  document.getElementById('u-uid').value = id;
  document.getElementById('u-nick').value = '';
  findUser();
}
// 상태를 보고 바로 지급으로 넘어간다 — uuid 를 손으로 옮기면 오타가 난다.
function toGrant(id) {
  document.getElementById('g-uid').value = id;
  tab('grant');
}

async function normalizeCurrency(id) {
  const reason = val('cur-reason');
  if (!reason) return toast('사유를 입력하세요');
  const body = { userId: id, reason: reason };
  // 비운 칸은 **보내지 않는다** — 0 으로 보내면 그 재화를 0 으로 만든다.
  const fields = [['gold','cur-gold'],['jelly','cur-jelly'],['chitin','cur-chitin'],
                  ['mineral','cur-mineral'],['sap','cur-sap']];
  for (const f of fields) {
    const v = document.getElementById(f[1]).value.trim();
    if (v !== '') body[f[0]] = parseInt(v, 10);
  }
  if (Object.keys(body).length <= 2) return toast('맞출 값을 하나 이상 입력하세요');
  if (!confirm('이 유저의 재화를 줄입니다. 되돌릴 수 없습니다. 계속할까요?')) return;
  try {
    const r = await api('/admin/currency', body);
    const box = document.getElementById('cur-result');
    if (!r.changed) { box.textContent = '바뀐 것이 없습니다(지금 값보다 크거나 같음)'; return; }
    let html = '<b>정상화 완료</b>';
    for (const k in r.changes) {
      const c = r.changes[k];
      html += '<div>' + esc(k) + ': ' + n(c.from) + ' → <b>' + n(c.to) +
              '</b> <span class="sub">(접속 중이면 최대 ' + n(c.mayRiseTo) + ' 까지 되올라감)</span></div>';
    }
    box.innerHTML = html;
    toast('정상화했습니다');
  } catch (e) { toast(e.message); }
}

async function loadProducts() {
  const sel = document.getElementById('g-product');
  if (sel.options.length) return;              // 한 번만 채운다
  try {
    const d = await api('/admin/products');
    sel.innerHTML = (d.products || []).map(p =>
      '<option value="' + esc(p.id) + '">' + esc(p.name) +
      ' (' + esc(p.id) + ')' + (p.hidden ? ' · 판매중단' : '') + '</option>'
    ).join('');
  } catch (e) { toast(e.message); }
}

async function grantProduct() {
  const uid = val('g-uid');
  if (!uid) return toast('유저 uuid 를 입력하세요');
  const pid = document.getElementById('g-product').value;
  const reason = val('g-reason');
  if (!reason) return toast('사유를 입력하세요');
  if (!confirm(pid + ' 를 이 유저에게 지급합니다. 계속할까요?')) return;
  try {
    const r = await api('/admin/grant', { userId: uid, productId: pid, reason: reason });
    // "이미 줬음"과 "방금 줬음"을 구분해서 보여준다 — 같은 초록 토스트로
    // 뭉치면 두 번 눌러 놓고 두 배로 들어간 줄 안다.
    document.getElementById('g-result').innerHTML =
      (r.alreadyGranted
        ? '<b>이미 지급된 건입니다</b> (같은 사유 — 새로 들어가지 않았습니다)'
        : '<b>지급 완료</b>') +
      // 소모품(젤리·골드·재료)은 세이브에 쓰면 앱 업로드에 덮인다 —
      // 우편으로 보냈고, 유저가 **받기를 눌러야** 들어간다.
      (r.consumable
        ? (r.mailed
            ? '<div style="color:#8FE08F">젤리·재화는 <b>우편</b>으로 보냈습니다 — 유저가 받기를 눌러야 들어갑니다</div>'
            : '<div style="color:#FFB4A2">⚠ 우편 발송 실패 — 젤리·재화가 안 갔습니다. 우편 탭에서 수동으로 보내세요</div>')
        : '') +
      (r.incubatorSlotsNeedsCheck
        ? '<div class="sub">부화기 슬롯은 앱 세이브가 이깁니다 — 안 늘었으면 우편/젤리로 처리하세요</div>'
        : '') +
      '<div>곤충학자 패스: ' + esc(r.passExpiresAt ? r.passExpiresAt.slice(0,10) + ' 까지' : '없음') + '</div>' +
      '<div>무한 버프 패스: ' + esc(r.buffPassExpiresAt ? r.buffPassExpiresAt.slice(0,10) + ' 까지' : '없음') + '</div>' +
      '<div>스타터 구매됨: ' + (r.starterBought ? '예' : '아니오') + '</div>';
    toast(r.alreadyGranted ? '이미 지급된 건입니다' : '지급했습니다');
  } catch (e) {
    toast(e.message === 'no_save' ? '그 uuid 의 세이브가 없습니다'
        : e.message === 'already_owned' ? '스타터는 계정당 1회입니다'
        : e.message);
  }
}

async function del(kind, id) {
  if (!confirm('삭제할까요?')) return;
  try { await api('/admin/delete', { kind: kind, id: id }); toast('삭제했습니다'); refresh(); }
  catch (e) { toast(e.message); }
}
function num(id) { return Math.max(0, parseInt(document.getElementById(id).value || '0', 10) || 0); }
function val(id) { return document.getElementById(id).value.trim(); }

async function createNotice() {
  if (!val('n-title')) return toast('제목을 입력하세요');
  try {
    await api('/admin/notice', {
      title: val('n-title'), body: val('n-body'),
      pinned: val('n-pinned') === 'true', endsAt: day(val('n-ends')),
    });
    document.getElementById('n-title').value = '';
    document.getElementById('n-body').value = '';
    toast('공지를 올렸습니다'); refresh();
  } catch (e) { toast(e.message); }
}

async function createMail() {
  const one = document.getElementById('m-target').value === 'one';
  const uid = val('m-uid');
  if (one && !uid) return toast('유저 uuid 를 입력하세요');
  if (!val('m-title')) return toast('제목을 입력하세요');
  const who = one ? '이 유저' : '전체 유저';
  if (!confirm(who + '에게 보냅니다. 되돌릴 수 없습니다. 계속할까요?')) return;
  try {
    await api('/admin/mail', {
      userId: one ? uid : null, title: val('m-title'), body: val('m-body'),
      gold: num('m-gold'), jelly: num('m-jelly'), chitin: num('m-chitin'),
      mineral: num('m-mineral'), sap: num('m-sap'), endsAt: day(val('m-ends')),
    });
    toast('보냈습니다'); refresh();
  } catch (e) { toast(e.message); }
}

async function createCode() {
  const code = val('c-code').toUpperCase();
  if (!code) return toast('코드를 입력하세요');
  try {
    await api('/admin/code', {
      code: code, gold: num('c-gold'), jelly: num('c-jelly'), chitin: num('c-chitin'),
      mineral: num('c-mineral'), sap: num('c-sap'),
      maxUses: val('c-max') ? num('c-max') : null, endsAt: day(val('c-ends')),
    });
    document.getElementById('c-code').value = '';
    toast('코드를 만들었습니다'); refresh();
  } catch (e) { toast(e.message); }
}

if (KEY) {
  api('/admin/data').then(() => {
    document.getElementById('gate').style.display = 'none';
    document.getElementById('app').style.display = 'block';
    refresh();
  }).catch(() => sessionStorage.removeItem('adminKey'));
}
</script>
</body>
</html>
''';
