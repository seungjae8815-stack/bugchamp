"""생성기가 찍은 **워터마크(반짝이 ✦)** 를 찾아 지운다.

    python tool/strip_watermark.py --scan          # 어디에 있는지만 본다
    python tool/strip_watermark.py --fix           # 실제로 지운다(백업 후)
    python tool/strip_watermark.py --fix --only assets/images/biomes/wood.webp

Gemini 로 뽑은 그림은 **오른쪽 아래에 밝은 네 꼭짓점 별**이 박혀 나온다. 배경으로
깔면 그대로 화면에 보인다(실기 지적: "결투 배경화면에 워터마크가 그대로").

지우는 방식
----------
잘라내면 구도가 바뀌므로 **주변으로 메운다**(inpaint). 워터마크는 주변보다 확실히
밝고 채도가 낮아서, 오른쪽 아래 구석에서 "국소 중앙값보다 밝은 덩어리"로
잡힌다. 그 자리를 마스크 밖 픽셀의 평균으로 여러 번 번지게 해 채운다.

⚠️ 원본은 `_raw_backup/` 에 남긴다 — 잘못 지우면 되돌릴 방법이 없다.
"""

import argparse
import glob
import os
import shutil
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.abspath(__file__))
IMAGES = os.path.normpath(os.path.join(ROOT, "..", "assets", "images"))
BACKUP = os.path.join(IMAGES, "_raw_backup", "prewatermark")


def find_mark(im):
    """워터마크 마스크와 픽셀 수를 돌려준다. 없으면 (None, 0)."""
    import numpy as np
    from scipy import ndimage

    rgb = np.array(im.convert("RGB")).astype(float)
    h, w = rgb.shape[:2]
    v = rgb.mean(axis=2)

    # 오른쪽 아래 구석만 본다 — 그림 한복판의 밝은 부분을 건드리면 안 된다.
    win = np.zeros((h, w), bool)
    win[int(h * 0.62) :, int(w * 0.62) :] = True

    # 국소 중앙값보다 뚜렷하게 밝고, 색기가 옅은 곳.
    med = ndimage.median_filter(v, size=max(9, int(min(h, w) * 0.05)) | 1)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    cand = win & (v - med > 26) & (sat < 46)

    # 조각나 있으면 하나로 잇는다(별의 네 꼭짓점이 가늘어 끊기기 쉽다).
    cand = ndimage.binary_closing(cand, iterations=2)
    lab, n = ndimage.label(cand)
    if n == 0:
        return None, 0

    # 워터마크의 **생김새**로 거른다. 이게 없으면 아이콘의 하이라이트까지
    # 전부 워터마크로 잡힌다(실측: 전체 스캔에서 170개 오검출).
    #   · 네 꼭짓점 별이라 바운딩박스가 거의 **정사각**
    #   · 별이라 박스를 꽉 채우지 않는다(30% 안팎)
    #   · 항상 **오른쪽 아래 구석**의 같은 자리
    #   · 그림 크기 대비 작다
    best, best_size = None, 0
    for i in range(1, n + 1):
        m = lab == i
        cnt = int(m.sum())
        if cnt < 40:
            continue
        ys, xs = np.where(m)
        bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        if not (0.7 < bw / bh < 1.4):
            continue
        if not (0.15 < cnt / (bw * bh) < 0.5):
            continue
        if not (0.008 < bw / w < 0.09):
            continue
        if xs.mean() / w < 0.84 or ys.mean() / h < 0.62:
            continue
        if cnt > best_size:
            best, best_size = m, cnt
    if best is None:
        return None, 0
    return ndimage.binary_dilation(best, iterations=4), best_size


def inpaint(im, mask):
    """마스크 자리를 주변 색으로 번지게 채운다."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage

    arr = np.array(im.convert("RGBA")).astype(float)
    rgb = arr[..., :3].copy()
    m = mask.copy()
    rgb[m] = 0
    known = (~m).astype(float)
    # 바깥에서 안쪽으로 여러 번 평균을 밀어 넣는다.
    for _ in range(48):
        if not m.any():
            break
        blur = np.stack(
            [ndimage.uniform_filter(rgb[..., c], size=7) for c in range(3)],
            axis=2,
        )
        wsum = ndimage.uniform_filter(known, size=7)
        edge = m & (wsum > 0.02)
        if not edge.any():
            break
        with np.errstate(invalid="ignore", divide="ignore"):
            filled = blur / np.maximum(wsum, 1e-6)[..., None]
        rgb[edge] = filled[edge]
        known[edge] = 1
        m[edge] = False
    arr[..., :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(arr.astype("uint8"), "RGBA")


def targets(only):
    if only:
        return [os.path.normpath(only)]
    out = []
    for ext in ("webp", "png", "jpg"):
        out += glob.glob(os.path.join(IMAGES, "**", "*." + ext), recursive=True)
    # `_` 로 시작하는 폴더는 번들에 안 들어간다(원본 백업 등).
    return [
        p
        for p in out
        if not any(s.startswith("_") for s in p.split(os.sep))
    ]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scan", action="store_true")
    ap.add_argument("--fix", action="store_true")
    ap.add_argument("--only")
    a = ap.parse_args()
    if not (a.scan or a.fix):
        a.scan = True

    from PIL import Image

    hits = []
    for p in targets(a.only):
        try:
            im = Image.open(p)
        except Exception:
            continue
        mask, size = find_mark(im)
        if mask is None:
            continue
        hits.append((p, im, mask, size))
        print(f"  워터마크 {size:5d}px  {os.path.relpath(p, IMAGES)}")

    if not hits:
        print("워터마크를 못 찾았습니다.")
        return
    print(f"\n{len(hits)}개 발견")
    if not a.fix:
        print("(--scan 이라 지우지 않았습니다. --fix 로 실행하세요)")
        return

    os.makedirs(BACKUP, exist_ok=True)
    for p, im, mask, _ in hits:
        rel = os.path.relpath(p, IMAGES).replace(os.sep, "__")
        dst = os.path.join(BACKUP, rel)
        if not os.path.exists(dst):
            shutil.copy(p, dst)
        out = inpaint(im, mask)
        if p.lower().endswith(".webp"):
            out.save(p, "WEBP", quality=92, method=6)
        else:
            out.save(p)
        print(f"  지움 → {os.path.relpath(p, IMAGES)}")
    print(f"\n원본은 {os.path.relpath(BACKUP, IMAGES)} 에 백업했습니다.")


if __name__ == "__main__":
    main()
