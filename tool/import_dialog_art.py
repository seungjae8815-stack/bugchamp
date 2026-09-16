# -*- coding: utf-8 -*-
"""제미나이 팝업 틀/버튼(마젠타 배경 .jpg) -> 9분할용 투명 WebP.

`docs/art_prompts_dialog.md` 로 뽑은 3장을 앱 애셋으로 넣는다.

    python tool/import_dialog_art.py

하는 일
 1. **마젠타(#FF00FF) 키잉** — 아이콘(세이지 배경)과 달리 배경이 아트에 없는
    색이라 색조 판별이 필요 없다. 다만 JPEG 라 경계가 번지므로 디스필한다.
 2. **떠 있는 조각 제거** — 가장 큰 덩어리만 남긴다. 제미나이 워터마크(✦)가
    배경 위에 떠 있으면 이걸로 사라진다(버튼 2장이 이 경우).
 3. **틀은 워터마크가 황동 브래킷 위에 겹친다** — 좌우 대칭이라 반대쪽에서
    거울로 떠 와 메운다. 단색으로 덮으면 브래킷에 구멍이 난다.
 4. 내용 경계로 자르고 무손실 WebP 로 저장 + **9분할 경계를 재서 출력**한다.
    이 숫자를 Dart 의 `centerSlice` 에 넣는다.

⚠️ 9분할은 **가운데가 평평할 때만** 성립한다. 새 그림을 받으면 아래가 찍어 주는
   '가운데 균일도'를 보고, 값이 크면(무늬가 있으면) 늘릴 때 뭉개진다.
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

SRC = os.environ.get('DIALOG_SRC', r'C:\Users\Lenovo\Downloads')
OUT = 'packages/app/assets/images/ui/dialog'

# 제미나이 워터마크 자리(1024 기준 비율). 아이콘 24장과 같은 위치다.
WM = (880 / 1024, 880 / 1024, 928 / 1024, 928 / 1024)


def _magenta(a):
    return (a[:, :, 0] > 140) & (a[:, :, 2] > 140) & (a[:, :, 1] < 120)


def cut(path, mirror_watermark=False):
    im = Image.open(path).convert('RGB')
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape

    if mirror_watermark:
        # 워터마크 자리를 좌우 거울로 메운다(틀은 좌우 대칭).
        x0, x1 = int(WM[0] * w) - 6, int(WM[2] * w) + 6
        y0, y1 = int(WM[1] * h) - 6, int(WM[3] * h) + 6
        a[y0:y1, x0:x1] = a[y0:y1, w - x1:w - x0][:, ::-1]

    mag = _magenta(a)
    lab, n = ndimage.label(mag)
    edges = set(lab[0]) | set(lab[-1]) | set(lab[:, 0]) | set(lab[:, -1])
    edges.discard(0)
    outside = np.isin(lab, list(edges))

    # 경계를 **안쪽으로 2px 깎는다.** JPEG 색번짐 때문에 알파가 0.92 인 채
    # 마젠타가 섞인 띠가 테두리 전체에 남는다(측정: 분홍 기미 0.78%) —
    # 디스필로는 안 지워진다(알파가 1 에 가까워 나눠도 그대로다).
    # 2px 잃는 건 990px 그림에서 안 보인다.
    inside = ndimage.binary_erosion(~outside, iterations=2)
    alpha = ndimage.gaussian_filter(inside.astype(np.float32), 0.8)
    alpha = np.clip((alpha - 0.35) / 0.45, 0.0, 1.0)

    # 떠 있는 조각(배경 위 워터마크) 제거 — 가장 큰 덩어리만 남긴다.
    solid = alpha > 0.5
    lab2, n2 = ndimage.label(solid)
    if n2 > 1:
        sizes = ndimage.sum(solid, lab2, range(1, n2 + 1))
        keep = int(np.argmax(sizes)) + 1
        alpha[(lab2 != keep) & (lab2 != 0)] = 0.0

    # 디스필 — 마젠타가 섞인 경계 픽셀에서 배경 기여분을 뺀다.
    mg = np.array([255.0, 0.0, 255.0], np.float32)
    rgb = a.copy()
    m = (alpha > 0.004) & (alpha < 0.996)
    if m.any():
        av = alpha[m][:, None]
        rgb[m] = np.clip((a[m] - (1.0 - av) * mg[None, :]) / av, 0, 255)
    # 남은 마젠타 기미 제거 — 초록이 유독 낮은 픽셀의 R·B 를 G 쪽으로 당긴다.
    tint = (rgb[:, :, 1] + 22 < rgb[:, :, 0]) & (rgb[:, :, 1] + 22 < rgb[:, :, 2])
    tint &= alpha < 0.999
    if tint.any():
        g = rgb[:, :, 1][tint]
        rgb[:, :, 0][tint] = np.minimum(rgb[:, :, 0][tint], g + 22)
        rgb[:, :, 2][tint] = np.minimum(rgb[:, :, 2][tint], g + 22)

    img = Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), 'RGBA')
    bbox = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    return (img.crop(bbox) if bbox else img)


def pill_insets(img):
    """버튼(둥근 알약)의 9분할 경계 — **가로로만** 늘린다.

    위아래 여백을 주면 안 된다. 버튼 높이(40px 쯤)가 원본 여백(70px)보다
    작아서 3x3 격자가 겹쳐 납작해진다(2026-09-16 에 실제로 그렇게 나왔다).
    끝의 둥근 부분만 고정하고 세로는 통째로 늘린다.
    """
    import numpy as np
    al = np.asarray(img)[:, :, 3] > 128
    w = img.width
    col = al.sum(0)
    full = col.max()
    left = int(np.argmax(col >= full * 0.99))
    right = w - 1 - int(np.argmax(col[::-1] >= full * 0.99))
    return left, 2, w - 1 - right, 2


def slice_insets(img, edge_frac=0.45):
    """9분할 경계 추정 — 가장자리에서 색이 안정되는 지점까지가 테두리다."""
    a = np.asarray(img).astype(np.float32)
    h, w, _ = a.shape
    cy, cx = h // 2, w // 2
    mid = a[cy, :, :3]
    ref = a[cy, cx, :3]

    def scan(seq, ref):
        for i in range(len(seq)):
            if np.abs(seq[i] - ref).max() < 14:
                return i
        return len(seq) // 3

    left = scan(mid, ref)
    right = w - 1 - scan(mid[::-1], ref)
    col = a[:, cx, :3]
    top = scan(col, ref)
    bottom = h - 1 - scan(col[::-1], ref)
    # 가운데가 정말 평평한지 — 9분할의 전제
    inner = a[top + 4:bottom - 3, left + 4:right - 3, :3]
    flat = float(inner.std()) if inner.size else 0.0
    return left, top, w - 1 - right, h - 1 - bottom, flat


# 저장 크기 — **3배 해상도**로 두고 Dart 에서 `scale: 3` 으로 읽는다.
#
# ⚠️ centerSlice 의 모서리는 **원본 픽셀 그대로** 그려진다. 1024px 원본을
#    그대로 쓰면 버튼 끝(88px)이 논리 88px 로 찍혀, 높이 40px 버튼이
#    타원이 된다(2026-09-16 에 그렇게 나왔다). 표시 크기의 3배로 줄여
#    저장하고 scale 3 을 주면 두께·둥근 끝이 맞는다.
#
# (이름, 기준 치수, 3배 저장 크기) — 프레임은 테두리 26논리px,
# 버튼은 높이 44논리px 을 노린다.
SIZES = {
    'frame': ('height', 573),        # 테두리 78px / 3 = 26논리px
    'btn_primary': ('height', 132),  # 44논리px * 3
    'btn_secondary': ('height', 132),
}


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    jobs = [('dialog_frame', 'frame', True),
            ('dialog_btn_primary', 'btn_primary', False),
            ('dialog_btn_secondary', 'btn_secondary', False)]
    for src, name, mirror in jobs:
        img = cut(os.path.join(SRC, src + '.jpg'), mirror_watermark=mirror)
        axis, target = SIZES[name]
        if axis == 'height' and img.height != target:
            w2 = max(1, round(img.width * target / img.height))
            img = img.resize((w2, target), Image.LANCZOS)
        out = os.path.join(OUT, name + '.webp')
        img.save(out, 'WEBP', lossless=True)
        if name == 'frame':
            l, t, r, b, flat = slice_insets(img)
        else:
            l, t, r, b = pill_insets(img)
            flat = slice_insets(img)[4]
        w, h = img.size
        print('%-14s %dx%d  %4.0f KB  가운데 균일도 %.1f' % (name, w, h, os.path.getsize(out) / 1024, flat))
        print('    Rect.fromLTRB(%d, %d, %d, %d)  // 여백 왼%d 위%d 오른%d 아래%d'
              % (l, t, w - r, h - b, l, t, r, b))
