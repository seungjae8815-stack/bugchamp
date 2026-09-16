"""제미나이 아이콘(평평한 세이지 배경 .jpg) -> 게임용 투명 WebP 514.

`docs/art_prompts_skills.md` 로 뽑은 32장을 앱 애셋으로 넣는다.

쓰는 법(워크스페이스 루트에서):
    python tool/import_skill_icons.py <원본.jpg> <나갈파일.webp> [미리보기.png]

하는 일
 1. 제미나이 워터마크(✦) 제거 — 배경색으로 덮는다. **그림이 겹치면 멈춘다.**
 2. 평평한 배경을 **바깥에서 flood fill** 로 지운다(아이콘 안쪽 같은 색은 남긴다 —
    이 그림들은 이끼가 배경과 같은 초록이다).
 3. 경계 픽셀 디스필 — 안 하면 어두운 배경에서 **초록 헤일로**가 보인다.
 4. 내용 경계로 자르고 정사각 + 여백 -> 514 (기존 아이콘 규격, upgrades/attack.webp 와 같다).

⚠️ 효과 그림(fx_*)은 **검정 배경**이라 이 스크립트를 쓰지 않는다 — 가산 합성으로 올린다.
⚠️ 새 그림을 받으면 워터마크가 그림과 겹치는지 먼저 확인한다(겹치면 이 스크립트가 멈춘다).
"""

import sys
import numpy as np
from PIL import Image
from collections import deque

TARGET = 514
MARGIN = 0.035          # 정사각 여백 비율
LO, HI = 10.0, 46.0     # 배경 거리: 이하=완전투명, 이상=완전불투명


def cut(path, target=TARGET):
    im = Image.open(path).convert('RGB')
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape

    # 배경색 = 테두리 중앙값
    edge = np.concatenate([a[0], a[h - 1], a[:, 0], a[:, w - 1]])
    bg = np.median(edge, axis=0)

    # ⓪ 제미나이 워터마크(✦) 제거 — 배경색으로 덮는다.
    #    24장 전부 x=880~927 y=880~927 (1024px 기준)에 48x48 로 찍혀 있고,
    #    주변 6px 안에 그림이 하나도 없다(확인 스캔 wm_scan2). 여백 4px 을 더 준다.
    #    ⚠️ 배경 위에만 있을 때 안전하다 — 새 이미지를 넣을 땐 겹침을 먼저 확인한다.
    wm = np.array([880, 880, 927, 927], float) / 1024.0
    wx0, wy0 = int(wm[0] * w) - 4, int(wm[1] * h) - 4
    wx1, wy1 = int(wm[2] * w) + 5, int(wm[3] * h) + 5
    patch = a[max(0, wy0):wy1, max(0, wx0):wx1]
    strong = np.sqrt(((patch - bg) ** 2).sum(2)) > 70
    if strong.any():
        raise SystemExit('워터마크 자리에 그림이 있다(%d픽셀) — 손으로 확인할 것: %s'
                         % (strong.sum(), path))
    a[max(0, wy0):wy1, max(0, wx0):wx1] = bg

    dist = np.sqrt(((a - bg) ** 2).sum(2))

    # ① 바깥에서 flood fill — 배경으로 "이어진" 영역만 배경으로 본다
    near = dist < HI
    outside = np.zeros((h, w), bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not outside[y, x]:
                outside[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not outside[y, x]:
                outside[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not outside[ny, nx]:
                outside[ny, nx] = True
                dq.append((ny, nx))

    # ② 알파: 바깥 영역만 배경 거리로 부드럽게, 나머지는 불투명
    alpha = np.ones((h, w), np.float32)
    soft = np.clip((dist - LO) / (HI - LO), 0.0, 1.0)
    alpha[outside] = soft[outside]

    # ③ 디스필 — 반투명 픽셀에서 배경색 기여분을 뺀다(초록 헤일로 제거)
    rgb = a.copy()
    m = (alpha > 0.004) & (alpha < 0.996)
    if m.any():
        av = alpha[m][:, None]
        rgb[m] = np.clip((a[m] - (1.0 - av) * bg[None, :]) / av, 0, 255)

    out = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    img = Image.fromarray(out, 'RGBA')

    # ④ 내용 경계로 자르고 정사각 + 여백
    bbox = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    if bbox:
        img = img.crop(bbox)
    side = max(img.size)
    side = int(round(side * (1 + MARGIN * 2)))
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return sq.resize((target, target), Image.LANCZOS), bg, bbox


def checker(img, light=True):
    """체커보드 위에 올린 확인용 이미지."""
    c1, c2 = ((235, 235, 235), (205, 205, 205)) if light else ((45, 48, 44), (28, 30, 27))
    bgim = Image.new('RGB', img.size, c1)
    px = bgim.load()
    s = 16
    for y in range(img.height):
        for x in range(img.width):
            if ((x // s) + (y // s)) % 2:
                px[x, y] = c2
    bgim.paste(img, (0, 0), img)
    return bgim


if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    img, bg, bbox = cut(src)
    img.save(dst, 'WEBP', lossless=True)
    print('배경색', bg.round(1), '내용 bbox', bbox)
    print('저장', dst, img.size)
    if len(sys.argv) > 3:
        prev = Image.new('RGB', (TARGET * 2 + 24, TARGET), (255, 255, 255))
        prev.paste(checker(img, True), (0, 0))
        prev.paste(checker(img, False), (TARGET + 24, 0))
        prev.save(sys.argv[3])
        print('미리보기', sys.argv[3])
