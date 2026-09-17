# -*- coding: utf-8 -*-
"""제미나이 스킬 효과 스트립(검정 배경, 4프레임) -> 낱장 투명 WebP 4장.

`docs/art_prompts_skills.md` 25~32번으로 뽑은 8장을 앱 애셋으로 넣는다.

    python tool/import_skill_fx.py            # 전부
    python tool/import_skill_fx.py crit_strike

## 아이콘과 처리가 다른 이유
아이콘은 **불투명한 물건**이라 배경을 오려 내면 되지만, 효과는 **빛**이다.
빛은 경계가 없고 반투명하게 겹쳐야 한다. 그래서 오려 내지 않고
**밝기를 그대로 알파로 삼는다**(검정 = 완전 투명, 밝은 곳 = 불투명).
게임에서 그냥 겹쳐 그리면 가산 합성(screen)처럼 보인다.

## 워터마크
효과 위에 겹친 것이 3장 있다(lure_sap·molting·queen_call). 워터마크는
**무채색 회색**이고 효과는 채도가 높아서, **채도로 가려낸다**. 지운 자리는
검정 = 투명이라 주변 불티가 그대로 남는다.
"""

import glob
import io
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

if (sys.stdout.encoding or '').lower().replace('-', '') != 'utf8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

SRC = os.environ.get('FX_SRC', r'C:\Users\Lenovo\Downloads\곤충키우기스킬이미지')
OUT = os.environ.get('FX_OUT', 'packages/app/assets/images/fx')
FRAMES = 4
CELL = 256          # 저장 크기(한 변). 화면에서 120~200논리px 로 쓴다.


def _lum_sat(a):
    mx = a.max(2)
    mn = a.min(2)
    sat = np.where(mx > 1, (mx - mn) / np.maximum(mx, 1), 0.0)
    return mx, sat


def strip_watermark(a):
    """무채색 ✦ 를 검정으로 지운다. 지운 픽셀 수를 돌려준다."""
    h, w, _ = a.shape
    lum, sat = _lum_sat(a)
    cand = (sat < 0.18) & (lum > 55) & (lum < 240)
    # 우하단 구역만 본다 — 효과 안의 흰 불티를 지우지 않기 위해.
    box = np.zeros((h, w), bool)
    box[int(h * 0.45):, int(w * 0.62):] = True
    cand &= box
    lab, n = ndimage.label(cand)
    wiped = 0
    for i in range(1, n + 1):
        m = lab == i
        ys, xs = np.nonzero(m)
        bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        area = len(ys)
        fill = area / (bw * bh)
        # ✦ 는 30~60px 정사각에 채움 0.25~0.6 인 별 모양이다.
        if 24 <= bw <= 64 and 24 <= bh <= 64 and abs(bw - bh) <= 10 \
                and 0.22 <= fill <= 0.62 and area > 250:
            grow = ndimage.binary_dilation(m, iterations=3)
            a[grow] = 0.0
            wiped += int(grow.sum())
    if wiped:
        return wiped
    # 채도로 못 찾은 경우 = 워터마크가 **효과 위에 겹쳐** 색이 섞인 것이다
    # (lure_sap·molting·queen_call). 위치는 모서리 기준으로 일정하다 —
    # 오른쪽·아래에서 각각 70~106px. 그 상자만 어둡게 눌러 지운다.
    # 효과 일부가 함께 지워지지만 1024px 중 44px 구석이라 눈에 안 띈다.
    bx0, bx1 = w - 112, w - 64
    by0, by1 = h - 112, h - 64
    if bx0 > 0 and by0 > 0:
        patch = np.zeros((h, w), np.float32)
        patch[by0:by1, bx0:bx1] = 1.0
        soft = np.clip(ndimage.gaussian_filter(patch, 3.0) * 1.7, 0, 1)
        a *= (1.0 - soft)[:, :, None]
        wiped = int((soft > 0.5).sum())
    return wiped


def find_frames(a):
    """가로로 늘어선 4프레임의 (x중심, y범위)를 찾는다."""
    lum, _ = _lum_sat(a)
    h, w = lum.shape
    colmax = lum.max(0)
    on = colmax > 22
    # 연속 구간 묶기
    runs, start = [], None
    for x in range(w):
        if on[x] and start is None:
            start = x
        elif not on[x] and start is not None:
            if x - start > w * 0.02:
                runs.append((start, x - 1))
            start = None
    if start is not None:
        runs.append((start, w - 1))
    if len(runs) != FRAMES:
        return None, None, runs
    # ⚠️ `max > 22` 로 잡으면 JPEG 노이즈 한 점 때문에 세로 범위가 이미지
    #    전체가 된다(lure_sap 이 0~470 으로 잡혔다). **밝은 픽셀이 어느 정도
    #    있는 줄**만 내용으로 본다.
    rows = (lum > 30).sum(1) > max(3, int(w * 0.002))
    ys = np.nonzero(rows)[0]
    if len(ys) == 0:
        return None, None, runs
    return runs, (int(ys.min()), int(ys.max())), runs


def convert(name):
    path = os.path.join(SRC, 'fx_%s.jpg' % name)
    if not os.path.exists(path):
        print('%-14s 파일 없음' % name)
        return
    a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    wiped = strip_watermark(a)
    runs, yband, raw = find_frames(a)
    if runs is None:
        print('%-14s 프레임 %d개로 잡힘 — 4개가 아니라 건너뜀 %s'
              % (name, len(raw), raw))
        return
    y0, y1 = yband
    # 네 프레임이 **같은 크기**여야 애니메이션이 안 튄다 — 가장 큰 칸에 맞춘다.
    half = max((b - a0) for a0, b in runs) // 2 + 6
    ch = y1 - y0 + 1
    # ⚠️ **칸 간격보다 크게 자르지 않는다.** 크게 자르면 옆 프레임이 딸려 들어와
    #    한 칸에 고리가 두 개 보인다(2026-09-18 lure_sap·sap_drink 가 그랬다).
    centers = [(x + b) // 2 for x, b in runs]
    pitch = int(np.median([centers[i + 1] - centers[i]
                           for i in range(len(centers) - 1)]))
    side = min(pitch - 4, max(half * 2, ch))
    os.makedirs(OUT, exist_ok=True)
    for i, (xa, xb) in enumerate(runs, 1):
        cx = (xa + xb) // 2
        cy = (y0 + y1) // 2
        x0 = cx - side // 2
        yy0 = cy - side // 2
        sub = np.zeros((side, side, 3), np.float32)
        sx0, sy0 = max(0, x0), max(0, yy0)
        sx1 = min(a.shape[1], x0 + side)
        sy1 = min(a.shape[0], yy0 + side)
        sub[sy0 - yy0:sy1 - yy0, sx0 - x0:sx1 - x0] = a[sy0:sy1, sx0:sx1]
        lum = sub.max(2)
        # 밝기 = 알파. 아주 어두운 바닥은 잘라 낸다(JPEG 노이즈가 뿌옇게 남는다).
        alpha = np.clip((lum / 255.0 - 0.055) * 1.22, 0.0, 1.0)
        img = Image.fromarray(
            np.dstack([sub, alpha * 255]).astype(np.uint8), 'RGBA')
        if side != CELL:
            img = img.resize((CELL, CELL), Image.LANCZOS)
        img.save(os.path.join(OUT, '%s_%d.webp' % (name, i)), 'WEBP',
                 lossless=False, quality=88)
    total = sum(os.path.getsize(os.path.join(OUT, '%s_%d.webp' % (name, i)))
                for i in range(1, FRAMES + 1)) / 1024
    print('%-14s 프레임 4장 · %3.0f KB · 워터마크 지움 %d px' % (name, total, wiped))


if __name__ == '__main__':
    args = [x for x in sys.argv[1:] if not x.startswith('--')]
    names = args or [os.path.basename(f)[3:-4]
                     for f in sorted(glob.glob(os.path.join(SRC, 'fx_*.jpg')))]
    for nm in names:
        convert(nm)
