"""그림 생성(Gemini) 프롬프트 작업 페이지를 만든다.

    python tool/make_prompt_page.py <spec.json> <out.html>

카드 한 장 = 그림 한 장: 첨부할 기준 그림 + [그림 복사] [프롬프트 복사] [파일명 복사] + 완료 체크.
사장님이 버튼을 누르고 Gemini 입력창에 Ctrl+V 하면 되도록 프롬프트는 **완성된 한 덩어리**로 넣는다
(자리표시를 남기지 않는다). 본보기: 펫 이미지초안 뼈대시험_4단계.html.

spec.json:
    {"title": "...", "saveDir": "C:\\\\Users\\\\...\\\\Downloads\\\\...",
     "intro": "(선택) 맨 위 안내 한 줄 더",
     "items": [{"title": "...", "ref": "기준 그림 경로(선택)", "note": "(선택)",
                "prompt": "...", "file": "저장 파일명",
                "photo": "(선택) 두 번째로 붙일 실물 사진 경로", "photoNote": "(선택)", "photoCredit": "(선택) 출처"}]}

photo 가 있으면 [사진 복사] 버튼이 생긴다 — Gemini 에 그림 → 사진 → 프롬프트 순서로 붙여 넣는다.
"""

import base64
import html
import io
import json
import sys
from pathlib import Path

from PIL import Image


def data_uri(path: str, max_side: int = 1024) -> str:
    im = Image.open(path)
    im.thumbnail((max_side, max_side))
    buf = io.BytesIO()
    if path.lower().endswith((".jpg", ".jpeg")):  # 사진은 JPEG 그대로(PNG 로 바꾸면 페이지가 몇 배 커진다)
        im.convert("RGB").save(buf, "JPEG", quality=88)
        return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
    im.convert("RGBA").save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


CSS = """body{font-family:'Malgun Gothic',sans-serif;margin:24px;background:#faf8f5;color:#222}
.card{background:#fff;border:1px solid #ddd;border-radius:10px;padding:16px;margin:0 0 16px;display:flex;gap:16px}
.imgs{width:280px;flex:none;display:flex;flex-direction:column;gap:8px}
.imgs img{width:280px;border:1px solid #eee;border-radius:6px;background:#f4f1ec}
.cap{font-size:12px;color:#666;margin:-4px 0 4px} .credit{font-size:11px;color:#888;word-break:break-all}
.body{flex:1;min-width:0} h2{margin:0 0 8px;font-size:18px} .note{color:#7a4b00;font-size:14px;margin:0 0 8px}
pre{white-space:pre-wrap;background:#f4f1ec;padding:8px;border-radius:6px;font-size:13px}
button{font-size:15px;padding:8px 14px;margin:0 8px 8px 0;border-radius:6px;border:1px solid #bbb;background:#fff;cursor:pointer}
button.done{background:#d9f2d9;border-color:#6b6} label{font-size:15px}"""

JS = """async function copyImage(id, btn) {
  const img = document.getElementById(id);
  const c = document.createElement('canvas');
  c.width = img.naturalWidth; c.height = img.naturalHeight;
  c.getContext('2d').drawImage(img, 0, 0);
  const blob = await new Promise(r => c.toBlob(r, 'image/png'));
  await navigator.clipboard.write([new ClipboardItem({'image/png': blob})]);
  mark(btn);
}
async function copyText(id, btn) {
  await navigator.clipboard.writeText(document.getElementById(id).textContent);
  mark(btn);
}
function mark(btn) {
  document.querySelectorAll('button.done').forEach(b => b.classList.remove('done'));
  btn.classList.add('done');
}
document.querySelectorAll('input[type=checkbox]').forEach(cb => {
  try { cb.checked = localStorage.getItem(cb.id) === '1'; } catch (e) {}
  cb.addEventListener('change', () => { try { localStorage.setItem(cb.id, cb.checked ? '1' : '0'); } catch (e) {} });
});"""


def build(spec: dict, base: Path) -> str:
    e = html.escape
    out = [
        '<!doctype html>\n<html lang="ko"><head><meta charset="utf-8">',
        f"<title>{e(spec['title'])}</title>\n<style>\n{CSS}\n</style></head><body>",
        f"<h1>{e(spec['title'])}</h1>",
        "<p>버튼을 누르면 바로 클립보드에 복사. Gemini 입력창에서 <b>Ctrl+V</b> "
        "(사진이 있는 카드는 그림 → 사진 → 프롬프트 순서로 붙여 넣기). "
        f"결과는 <b>{e(spec['saveDir'])}</b> 에 아래 파일명 그대로 저장한다. "
        "다 만든 카드는 체크해 두면 새로고침해도 남는다.</p>",
    ]
    if spec.get("intro"):
        out.append(f"<p>{e(spec['intro'])}</p>")
    def resolve(p: str) -> str:
        q = Path(p)
        return str(q if q.is_absolute() else base / q)

    for i, it in enumerate(spec["items"]):
        out.append('<div class="card">')
        if it.get("ref") or it.get("photo"):
            out.append('<div class="imgs">')
            if it.get("ref"):
                out.append(f'<img id="img{i}" src="{data_uri(resolve(it["ref"]))}" alt="">')
                out.append('<div class="cap">① 그림(화풍)</div>')
            if it.get("photo"):
                out.append(f'<img id="pho{i}" src="{data_uri(resolve(it["photo"]))}" alt="">')
                out.append(f'<div class="cap">② 실물 사진 — {e(it.get("photoNote", ""))}</div>')
                if it.get("photoCredit"):
                    out.append(f'<div class="credit">{e(it["photoCredit"])}</div>')
            out.append("</div>")
        out.append(f'<div class="body"><h2>{i + 1}. {e(it["title"])}</h2>')
        if it.get("note"):
            out.append(f'<p class="note">{e(it["note"])}</p>')
        if it.get("ref"):
            out.append(f"<button onclick=\"copyImage('img{i}', this)\">그림 복사</button>")
        if it.get("photo"):
            out.append(f"<button onclick=\"copyImage('pho{i}', this)\">사진 복사</button>")
        out.append(f"<button onclick=\"copyText('p{i}', this)\">프롬프트 복사</button>")
        out.append(f"<button onclick=\"copyText('f{i}', this)\">파일명 복사</button>")
        out.append(f'<label><input type="checkbox" id="done-{e(it["file"])}"> 완료</label>')
        out.append(f'<pre id="p{i}">{e(it["prompt"])}</pre>')
        out.append(f'<div>파일명: <code id="f{i}">{e(it["file"])}</code></div></div></div>')
    out.append(f"<script>\n{JS}\n</script></body></html>")
    return "\n".join(out)


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    spec_path = Path(sys.argv[1])
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    missing = [it["file"] for it in spec["items"] if "<" in it["prompt"]]
    if missing:
        sys.exit(f"자리표시가 남은 프롬프트: {missing}")
    page = build(spec, spec_path.parent)
    Path(sys.argv[2]).parent.mkdir(parents=True, exist_ok=True)
    Path(sys.argv[2]).write_text(page, encoding="utf-8")
    print(f"{len(spec['items'])}장 → {sys.argv[2]} ({len(page) // 1024}KB)")


if __name__ == "__main__":
    main()
