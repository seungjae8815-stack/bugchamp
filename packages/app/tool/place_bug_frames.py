"""곤충 전투 프레임 시트(가로 3칸)를 잘라 배치한다.

    python tool/place_bug_frames.py --from C:\\Users\\Lenovo\\Downloads --dry
    python tool/place_bug_frames.py --from C:\\Users\\Lenovo\\Downloads
    python tool/place_bug_frames.py --from ... --only stag_giant

파일명은 **종 id 그대로**(`stag_giant.png`). species.json 에 없는 이름이면 멈춘다 —
오타는 에러 없이 조용히 폴백되므로(§6) 여기서 잡아야 한다.

왜 split_sprite_sheet.py 를 안 쓰나
----------------------------------
그 도구는 캐릭터 걷기용이라 **정확히 1/N 로 자른다**. 곤충은 큰턱·더듬이가 옆 칸까지
뻗어서, 정확히 1/3 에서 자르면 **집게가 잘린다**(실측: 왕사슴벌레 대기 자세의 1/3
지점 알파합 6350 — 한복판이 큰턱). 그래서 여기서는 칸 사이 **빈 세로줄**을 찾아 자른다.

또 배경을 rembg 로 지운다. AI 가 "plain background" 를 요구해도 **바닥(이끼·흙)을
그려 넣기 때문에** 밝기 문턱으로는 못 지운다 — 갈색 곤충과 갈색 흙은 같은 색이다.
시트를 **통째로** 한 번에 지워야 한다. 칸을 먼저 자르고 지우면 벌어진 큰턱 안쪽에
배경색이 남는다(실측).

세 칸의 **크기와 발 높이를 맞추는 것**이 이 도구의 핵심이다. 칸마다 따로 맞추면
자세가 바뀔 때 곤충이 커졌다 작아졌다 하고 위아래로 튄다.
  · 배율   = 세 칸 공통 (제일 큰 칸에 맞춘다)
  · 발 높이 = 세 칸 공통 (제일 아래 픽셀)
  · 가로 기준 = **알파 무게중심** — 큰턱이 앞으로 뻗어도 몸통은 제자리에 있다.
    (칸의 좌우 중앙에 맞추면 큰턱이 벌어질 때 몸통이 뒤로 밀린다.)
"""

import argparse
import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(ROOT, "..", "assets", "images", "bugs"))
SPECIES_JSON = os.path.normpath(
    os.path.join(ROOT, "..", "assets", "data", "species.json")
)
MAX_SIDE = 640  # 아레나에서 96pt(고밀도 288px)로 그린다 — 넉넉하되 과하지 않게


def species_ids():
    with open(SPECIES_JSON, encoding="utf-8") as f:
        d = json.load(f)
    rows = d if isinstance(d, list) else d.get("species", d)
    return [s["id"] for s in rows]


def split_columns(alpha, w, h, frames=3):
    """칸 사이의 **가장 빈 세로줄**을 찾아 자를 위치를 돌려준다."""
    px = alpha.load()
    # 세로로 4픽셀씩 건너뛰며 훑는다 — 골짜기를 찾는 데는 충분하고 훨씬 빠르다.
    cols = [sum(px[x, y] for y in range(0, h, 4)) for x in range(w)]
    cuts = [0]
    for i in range(1, frames):
        c = w * i / frames
        lo, hi = int(c - w / frames * 0.25), int(c + w / frames * 0.25)
        cuts.append(min(range(lo, hi), key=lambda x: cols[x]))
    cuts.append(w)
    return cuts


def drop_fragments(img, keep_ratio=0.05):
    """옆 칸에서 넘어온 **부스러기**를 지운다.

    빈 세로줄에서 잘라도 다리·더듬이 끝이 조금씩 걸친다. 그대로 두면 화면에
    정체불명의 검은 조각이 떠 있고, bbox 까지 넓혀 곤충이 작아진다.
    가장 큰 덩어리의 [keep_ratio] 보다 작은 덩어리는 곤충이 아니다.
    """
    import numpy as np
    from scipy import ndimage

    a = np.array(img.getchannel("A"))
    lab, n = ndimage.label(a > 8)
    if n <= 1:
        return img
    sizes = ndimage.sum(a > 8, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * keep_ratio])
    a[~keep] = 0
    from PIL import Image

    out = img.copy()
    out.putalpha(Image.fromarray(a))
    return out


def fill_speckles(cut, max_px=4000):
    """rembg 가 곤충 몸 안에 남긴 **자잘한 투명 구멍**을 메운다.

    다리가 몸통을 가로지르는 곳에서 곧잘 뚫린다(실측: 톱사슴벌레 피격 자세의
    딱지날개). 화면에서는 배경이 비쳐 **몸에 구멍이 난 것처럼** 보인다.

    바깥과 안 이어진 작은 섬만 메운다 — 다리 사이 진짜 틈은 바깥과 이어져 있고,
    벌어진 큰턱 사이는 이 문턱보다 훨씬 넓다.
    """
    import numpy as np
    from PIL import Image
    from scipy import ndimage

    a = np.array(cut.getchannel("A"))
    holes = a <= 8
    lab, n = ndimage.label(holes)
    if n == 0:
        return cut
    edge = set(lab[0].tolist()) | set(lab[-1].tolist())
    edge |= set(lab[:, 0].tolist()) | set(lab[:, -1].tolist())
    fill = np.zeros_like(holes)
    for i in range(1, n + 1):
        if i in edge:
            continue
        m = lab == i
        if m.sum() <= max_px:
            fill |= m
    if not fill.any():
        return cut
    a[fill] = 255
    out = cut.copy()
    out.putalpha(Image.fromarray(a))
    return out


def punch_holes(cut, sheet, tol=20):
    """곤충 **안에 갇힌 배경**을 뚫는다(벌어진 큰턱 사이 등).

    rembg 는 곤충을 하나의 덩어리로 잡아서, 큰턱이 벌어진 자세면 그 사이의 배경도
    곤충으로 친다(실측: 톱사슴벌레 대기 자세의 집게 안쪽이 크림색으로 찼다).

    배경색과 닮은 픽셀 중 **바깥(투명)에 닿지 않는 덩어리**만 뚫는다. 곤충 가장자리의
    크림색 림라이트는 바깥에 닿아 있으므로 살아남는다 — 이 구분이 없으면 테두리가
    갉아 먹힌다.
    """
    import numpy as np
    from PIL import Image
    from scipy import ndimage

    src = np.array(sheet.convert("RGB")).astype(int)
    bg = np.median(np.concatenate([src[:6].reshape(-1, 3), src[:, :6].reshape(-1, 3)]), axis=0)

    rgb = np.array(cut.convert("RGB")).astype(int)
    a = np.array(cut.getchannel("A"))
    inside = a > 8
    like_bg = inside & (abs(rgb - bg).max(axis=2) < tol)

    lab, n = ndimage.label(like_bg)
    if n == 0:
        return cut
    outside = ~inside
    # 벌어진 큰턱 사이는 **넓다**. 작은 덩어리는 곤충 몸의 밝은 부분이지 구멍이
    # 아니다 — 문턱이 낮으면 등껍질에 구멍이 뚫린다(실측: 톱사슴벌레 피격 자세).
    min_px = max(600, int(inside.sum() * 0.005))
    kill = np.zeros_like(like_bg)
    for i in range(1, n + 1):
        m = lab == i
        if m.sum() < min_px:
            continue
        # 바깥(투명)에 닿으면 림라이트다 — 건드리지 않는다.
        if (ndimage.binary_dilation(m, iterations=2) & outside).any():
            continue
        kill |= m
    if not kill.any():
        return cut
    a[kill] = 0
    out = cut.copy()
    out.putalpha(Image.fromarray(a))
    return out


def frame_metrics(img):
    """(bbox, 무게중심 x). 알파가 있는 픽셀 기준."""
    box = img.getbbox()
    if box is None:
        return None, None
    a = img.getchannel("A").load()
    l, t, r, b = box
    total = 0
    acc = 0
    for x in range(l, r):
        s = sum(a[x, y] for y in range(t, b, 3))
        acc += s * x
        total += s
    return box, (acc / total if total else (l + r) / 2)


def process(src, sid, dry):
    from PIL import Image
    from rembg import remove

    sheet = Image.open(src).convert("RGBA")
    # 시트를 **통째로** 지운다(칸을 먼저 자르면 큰턱 안쪽에 배경이 남는다).
    cut = punch_holes(fill_speckles(remove(sheet)), sheet)
    w, h = cut.size
    cuts = split_columns(cut.getchannel("A"), w, h)

    frames = []
    for i in range(3):
        f = drop_fragments(cut.crop((cuts[i], 0, cuts[i + 1], h)))
        box, cx = frame_metrics(f)
        if box is None:
            return f"  ! {sid}: {i + 1}번 칸이 비었습니다 — 자른 위치를 확인하세요"
        frames.append((f, box, cx))

    # 세 칸 공통 기준. 발(바닥)과 배율을 맞춰야 자세가 바뀔 때 안 튄다.
    base_y = max(b[3] for _, b, _ in frames)
    top_y = min(b[1] for _, b, _ in frames)
    need_h = base_y - top_y
    # 가로는 무게중심을 가운데 두고도 안 잘리도록 잡는다.
    need_w = max(
        2 * max(cx - b[0], b[2] - cx) for _, b, cx in frames
    )
    scale = min(MAX_SIDE / need_w, MAX_SIDE / need_h, 1.0)
    cw, ch = max(1, round(need_w * scale)), max(1, round(need_h * scale))

    out = []
    for i, (f, box, cx) in enumerate(frames):
        strip = f.crop((0, top_y, f.width, base_y))
        sw, sh = max(1, round(strip.width * scale)), max(1, round(strip.height * scale))
        strip = strip.resize((sw, sh), Image.LANCZOS)
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.alpha_composite(strip, (round(cw / 2 - cx * scale), 0))
        dst = os.path.join(DEST, f"{sid}_adult_{i + 1}.webp")
        out.append(dst)
        if not dry:
            # 무손실은 60장에 8.4MB — 번들이 감당 못 한다. 화면에서 96pt(고밀도
            # 288px)로 그리므로 q92 와 육안 차이가 없다(§0 규격과도 같다).
            canvas.save(dst, "WEBP", quality=92, method=6)
    # 채집함·도감·펫 화면은 자세가 없다(`bugStageImage`). 거기에 프레임 캔버스를
    # 그대로 주면 **위쪽이 텅 비어** 곤충이 작게 보인다 — 공격 자세가 위로 솟은
    # 만큼 캔버스가 높기 때문이다. 그래서 대기 프레임을 **딱 맞게 잘라** 따로 낸다.
    idle = frames[0][0]
    idle = idle.crop(idle.getbbox())
    idle.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    if not dry:
        idle.save(os.path.join(DEST, f"{sid}_adult.webp"), "WEBP", quality=92, method=6)

    return f"  {sid:24s} {cw}x{ch}  자른 위치 {cuts[1]},{cuts[2]} (1/3={w // 3},{2 * w // 3})"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", required=True, help="시트가 든 폴더")
    ap.add_argument("--only", help="종 id 하나만")
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    ids = species_ids()
    if a.only:
        if a.only not in ids:
            sys.exit(f"species.json 에 없는 id 입니다: {a.only}")
        ids = [a.only]

    found = [(i, os.path.join(a.src, i + ".png")) for i in ids]
    found = [(i, p) for i, p in found if os.path.exists(p)]
    missing = [i for i in ids if not any(i == j for j, _ in found)]
    if not found:
        sys.exit(f"{a.src} 에 종 id 이름의 png 가 없습니다")

    os.makedirs(DEST, exist_ok=True)
    print(f"{len(found)}종 처리{' (--dry: 저장 안 함)' if a.dry else ''}\n")
    for sid, path in found:
        print(process(path, sid, a.dry))
    if missing:
        print(f"\n아직 없는 종({len(missing)}): {', '.join(missing)}")
        print("  → 그 종은 예전 한 장짜리 그림으로 폴백됩니다(화면은 안 깨집니다).")


if __name__ == "__main__":
    main()
