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
    <button id="t-notice" class="on" onclick="tab('notice')">공지</button>
    <button id="t-mail" onclick="tab('mail')">우편</button>
    <button id="t-code" onclick="tab('code')">선물코드</button>
  </div>

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
  for (const n of ['notice','mail','code']) {
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
