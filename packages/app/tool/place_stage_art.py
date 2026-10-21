"""알·애벌레·번데기 그림(한 장짜리)을 배경 제거 → 여백 정리 → 512px webp 로 배치한다.

    python tool/place_stage_art.py --from C:\\Users\\Lenovo\\Downloads\\곤충고증 --dry
    python tool/place_stage_art.py --from C:\\Users\\Lenovo\\Downloads\\곤충고증
    python tool/place_stage_art.py --from ... --only stage_rhino_larva

파일명 = 저장할 이름 그대로(`stage_rhino_larva.jpg` → `assets/images/bugs/stage_rhino_larva.webp`).
받는 이름: `stage_<무리>_<egg|larva|pupa>` 또는 `<종 id>_<egg|larva|pupa>`(그 종만 바꾼다, art.dart 가 먼저 찾는다).

왜 rembg 가 아니라 배경색인가
-------------------------
프롬프트가 **평평한 연한 세이지색 배경**을 요구하고(art_prompts_bug_accuracy), 애벌레·번데기는
크림색이라 rembg 가 몸 일부를 배경으로 지운다. 그래서 테두리에서 배경색으로 이어진 곳만
지우고(flood fill — 몸 안의 비슷한 색은 남는다), **가장 큰 덩어리 하나만** 남긴다.
Gemini 워터마크(오른쪽 아래 ✦)는 배경 위에 따로 떠 있어 이 단계에서 같이 사라진다.
"""

import argparse
import json
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parent.parent
BUGS = ROOT / "assets" / "images" / "bugs"
STAGES = ("egg", "larva", "pupa")
OUT_SIDE = 512


def valid_name(name: str, species: set) -> bool:
    head, _, stage = name.rpartition("_")
    if stage not in STAGES:
        return False
    return head.startswith("stage_") or head in species


def cut(img: Image.Image, tol: int, hole_min: int = 0) -> Image.Image:
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = tuple(sorted(c[i] for c in corners)[1] for i in range(3))  # 모서리 중간값(워터마크 모서리 하나는 버린다)

    def near(c):
        return sum((c[i] - bg[i]) ** 2 for i in range(3)) <= tol * tol

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.extend([(x, 0), (x, h - 1)])
    for y in range(h):
        q.extend([(0, y), (w - 1, y)])
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i] or not near(px[x, y]):
            continue
        seen[i] = 1
        if x > 0: q.append((x - 1, y))
        if x < w - 1: q.append((x + 1, y))
        if y > 0: q.append((x, y - 1))
        if y < h - 1: q.append((x, y + 1))

    # 몸에 **갇힌 배경**도 지운다(방아깨비 뒷다리 사이 삼각형 — 바깥과 이어지지 않아 번짐이 못 닿는다).
    # 배경색과 아주 가까운(tol/2) 덩어리 중 hole_min 화소 이상만 — 몸의 밝은 반점은 남는다.
    # 기본은 끔 — 애벌레의 회청색 배가 배경색과 닮아 뚫린다. 다리 사이가 갇히는 그림만 --holes.
    tight = tol // 2
    hole = bytearray(w * h)
    for s in range(w * h if hole_min else 0):
        if seen[s] or hole[s]:
            continue
        c = px[s % w, s // w]
        if sum((c[i] - bg[i]) ** 2 for i in range(3)) > tight * tight:
            continue
        comp, st = [], [s]
        hole[s] = 1
        while st:
            i = st.pop()
            comp.append(i)
            x, y = i % w, i // w
            for j in (i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1):
                if j >= 0 and not seen[j] and not hole[j]:
                    cc = px[j % w, j // w]
                    if sum((cc[k] - bg[k]) ** 2 for k in range(3)) <= tight * tight:
                        hole[j] = 1
                        st.append(j)
        if len(comp) >= hole_min:
            for i in comp:
                seen[i] = 1

    # 가장 큰 덩어리만(워터마크·티끌 제거)
    label = [0] * (w * h)
    best, best_n, cur = 0, 0, 0
    for s in range(w * h):
        if seen[s] or label[s]:
            continue
        cur += 1
        n = 0
        st = [s]
        label[s] = cur
        while st:
            i = st.pop()
            n += 1
            x, y = i % w, i // w
            for j in (i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1):
                if j >= 0 and not seen[j] and not label[j]:
                    label[j] = cur
                    st.append(j)
        if n > best_n:
            best, best_n = cur, n
    alpha = Image.new("L", (w, h), 0)
    ap = alpha.load()
    for i in range(w * h):
        if label[i] == best:
            ap[i % w, i // w] = 255
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.8))  # 가장자리 계단만 누그러뜨린다
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def fit(img: Image.Image) -> Image.Image:
    box = img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    img = img.crop(box)
    pad = max(img.size) // 20
    side = max(img.size) + pad * 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)
    return canvas.resize((OUT_SIDE, OUT_SIDE), Image.LANCZOS)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", required=True)
    ap.add_argument("--only")
    ap.add_argument("--tol", type=int, default=38)
    ap.add_argument("--holes", type=int, default=0, help="이 화소 수 이상 갇힌 배경을 뚫는다(예: 400, 방아깨비)")
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    species = {s["id"] for s in json.loads((ROOT / "assets" / "data" / "species.json").read_text(encoding="utf-8"))["species"]}
    files = sorted(p for p in Path(a.src).iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"))
    done = 0
    for p in files:
        name = p.stem
        if a.only and name != a.only:
            continue
        if not valid_name(name, species):
            continue
        dest = BUGS / f"{name}.webp"
        if a.dry:
            print(f"{p.name} → {dest.relative_to(ROOT)}")
            continue
        fit(cut(Image.open(p), a.tol, a.holes)).save(dest, "WEBP", quality=92, method=6)
        print(f"{p.name} → {dest.relative_to(ROOT)}")
        done += 1
    if not a.dry:
        print(f"{done}장 배치")


if __name__ == "__main__":
    main()
