"""결투(곤충 배틀 스타디움) 그림을 앱 애셋으로 넣는다.

    python tool/import_duel_art.py --from "C:\\Users\\Lenovo\\Downloads\\곤충키우기 결투이미지"
    python tool/import_duel_art.py --from ... --only duel_stag_giant

프롬프트는 `docs/art_prompts_duel.md`. 파일명 = 애셋 이름(확장자만 .jpg/.png).

묶음마다 처리가 다르다
--------------------
- `duel_{종}`   곤충 위에서 본 한 장 → **누끼**(테두리 플러드필) · 여백 없이 잘라 정사각 512.
                배경이 단색 파스텔이라 rembg 보다 플러드필이 안전하다(창백한 곤충에 구멍을 안 낸다).
- `arena_{오행}` / `arena_{오행}_side`  경기장 → 배경째 쓴다. 워터마크만 주변 색으로 메운다.
- `fx_*`        효과(어두운 배경의 빛) → **밝기 = 알파**(import_skill_fx 와 같은 규칙).

⚠️ 같은 그림을 두 이름으로 저장한 실수를 잡는다(내용이 같은 파일이 있으면 둘 다 건너뛴다) —
실측 2026-09-29: 참나무하늘소 자리에 미야마 사슴벌레가 들어왔다.
"""

import argparse
import glob
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
from place_bug_frames import (  # noqa: E402
    drop_fragments,
    erase_corner_mark,
    flood_cut,
    punch_holes,
)
from strip_watermark import find_mark, inpaint  # noqa: E402

DEST = os.path.normpath(os.path.join(ROOT, "..", "assets", "images", "duel"))
SPECIES_JSON = os.path.normpath(
    os.path.join(ROOT, "..", "assets", "data", "species.json")
)
ELEMENTS = ("wood", "fire", "earth", "metal", "water")
FX = ("clash", "dust", "ringout", "dizzy")
# 결투 탭(2026-09-29, docs/art_prompts_battle_hub.md): 배경 · 출정 칸 틀 · 회복실 · 훈련소.
HUB = ("battle_hub_bg", "squad_slot", "hub_recovery", "hub_training", "event_entry_stage")
BUG_SIDE = 512  # 던지는 장면에서 경기장 폭의 1/4 안팎(고밀도 ~300px)
ARENA_SIDE = 768
SIDE_W = 1024
FX_SIDE = 256


def species_ids():
    with open(SPECIES_JSON, encoding="utf-8") as f:
        d = json.load(f)
    rows = d if isinstance(d, list) else d.get("species", d)
    return [s["id"] for s in rows]


def expected():
    out = ["duel_" + s for s in species_ids()]
    out += ["arena_" + e for e in ELEMENTS]
    out += ["arena_%s_side" % e for e in ELEMENTS]
    out += ["fx_" + f for f in FX]
    out += list(HUB)
    return out


def save_webp(img, name, quality=86):
    os.makedirs(DEST, exist_ok=True)
    path = os.path.join(DEST, name + ".webp")
    img.save(path, "WEBP", quality=quality, method=6)
    return os.path.getsize(path) // 1024


def do_bug(src, name):
    sheet = Image.open(src).convert("RGBA")
    sheet = erase_corner_mark(sheet)
    cut = flood_cut(sheet)
    # 다리와 몸 사이에 **갇힌 배경**은 테두리에서 번지지 않아 남는다 — 따로 뚫는다.
    # 배경에 옅은 그라데이션이 있어 문턱을 조금 넓힌다.
    cut = drop_fragments(punch_holes(cut, sheet, tol=30, min_abs=150, rim_guard=False))
    bbox = cut.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if bbox is None:
        return "누끼 실패(전부 지워짐)"
    cut = cut.crop(bbox)
    w, h = cut.size
    side = max(w, h)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(cut, ((side - w) // 2, (side - h) // 2))
    sq = sq.resize((BUG_SIDE, BUG_SIDE), Image.LANCZOS)
    cover = (np.array(cut.getchannel("A")) > 24).mean()
    kb = save_webp(sq, name)
    return "%d KB · 몸 채움 %.0f%%" % (kb, cover * 100)


def do_arena(src, name, side_view):
    im = Image.open(src).convert("RGBA")
    mask, n = find_mark(im)
    if mask is not None:
        im = inpaint(im, mask)
    if side_view:
        w, h = im.size
        im = im.resize((SIDE_W, round(h * SIDE_W / w)), Image.LANCZOS)
    else:
        im = im.resize((ARENA_SIDE, ARENA_SIDE), Image.LANCZOS)
    kb = save_webp(im.convert("RGB"), name, quality=82)
    return "%d KB · 워터마크 %s" % (kb, "지움 %dpx" % n if n else "없음")


def do_fx(src, name):
    a = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    h, w, _ = a.shape
    # 배경(짙은 회색)을 0 으로 끌어내린다 — 순검정이 아니라 밝기 문턱을 배경색에 맞춘다.
    bg = np.median(np.concatenate([a[:8].reshape(-1, 3), a[:, :8].reshape(-1, 3)]), 0)
    lum = a.max(2)
    base = float(bg.max()) + 6
    alpha = np.clip((lum - base) / (255 - base) * 1.35, 0, 1)
    # 워터마크 ✦ = 오른쪽 아래 구석의 **무채색** 덩어리. 효과는 따뜻한 색이라 채도로 가른다.
    mx, mn = a.max(2), a.min(2)
    sat = (mx - mn) / np.maximum(mx, 1)
    cand = (sat < 0.2) & (alpha > 0.05)
    box = np.zeros((h, w), bool)
    box[int(h * 0.8):, int(w * 0.8):] = True
    lab, n = ndimage.label(cand & box)
    wiped = 0
    for i in range(1, n + 1):
        m = lab == i
        ys, xs = np.nonzero(m)
        bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        if bw < 90 and bh < 90:
            grow = ndimage.binary_dilation(m, iterations=4)
            alpha[grow] = 0
            wiped += int(grow.sum())
    # 효과 둘레로 자른다(여백은 조금 남긴다) → 정사각.
    ys, xs = np.nonzero(alpha > 0.04)
    if len(ys) == 0:
        return "효과가 안 잡힘"
    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    half = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2 * 1.06
    x0, y0 = int(cx - half), int(cy - half)
    side = int(half * 2)
    rgba = np.dstack([a, alpha * 255]).astype(np.uint8)
    img = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    img.paste(Image.fromarray(rgba, "RGBA").crop((x0, y0, x0 + side, y0 + side)))
    img = img.resize((FX_SIDE, FX_SIDE), Image.LANCZOS)
    kb = save_webp(img, name, quality=88)
    return "%d KB · 워터마크 %s" % (kb, "지움 %dpx" % wiped if wiped else "없음")


def do_hub(src, name):
    im = Image.open(src).convert("RGBA")
    if name in ("battle_hub_bg", "event_entry_stage"):
        # 배경째 쓴다 — 워터마크만 메우고 폭 720 으로.
        mask, n = find_mark(im)
        if mask is not None:
            im = inpaint(im, mask)
        w, h = im.size
        im = im.resize((720, round(h * 720 / w)), Image.LANCZOS)
        kb = save_webp(im.convert("RGB"), name, quality=80)
        return "%d KB · 워터마크 %s" % (kb, "지움 %dpx" % n if n else "없음")
    # 틀·아이콘 — 테두리에서 번지는 누끼(안쪽 어두운 판은 갇혀 있어 남는다).
    cut = drop_fragments(flood_cut(erase_corner_mark(im)))
    bbox = cut.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    cut = cut.crop(bbox)
    side = 384 if name == "squad_slot" else 256
    w, h = cut.size
    k = side / max(w, h)
    cut = cut.resize((round(w * k), round(h * k)), Image.LANCZOS)
    kb = save_webp(cut, name)
    return "%d KB · %dx%d" % (kb, cut.size[0], cut.size[1])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", required=True)
    ap.add_argument("--only")
    a = ap.parse_args()

    files = {}
    for ext in ("jpg", "jpeg", "png", "webp"):
        for p in glob.glob(os.path.join(a.src, "*." + ext)):
            files[os.path.splitext(os.path.basename(p))[0]] = p
    want = expected()
    unknown = sorted(set(files) - set(want))
    if unknown:
        print("모르는 이름(건너뜀):", ", ".join(unknown))

    digest = {}
    for n, p in files.items():
        with open(p, "rb") as f:
            digest.setdefault(hashlib.md5(f.read()).hexdigest(), []).append(n)
    dup = {n for names in digest.values() if len(names) > 1 for n in names}
    for names in digest.values():
        if len(names) > 1:
            print("⚠️ 같은 그림이 두 이름으로 있음(둘 다 건너뜀):", ", ".join(sorted(names)))

    missing = []
    for name in want:
        if a.only and name != a.only:
            continue
        if name not in files:
            missing.append(name)
            continue
        if name in dup and not a.only:  # --only 로 콕 집으면 사람이 확인한 것으로 본다
            continue
        src = files[name]
        if name.startswith("duel_"):
            msg = do_bug(src, name)
        elif name in HUB:
            msg = do_hub(src, name)
        elif name.startswith("arena_"):
            msg = do_arena(src, name, name.endswith("_side"))
        else:
            msg = do_fx(src, name)
        print("%-32s %s" % (name, msg))
    if missing:
        print("없음(%d):" % len(missing), ", ".join(missing))


if __name__ == "__main__":
    main()
