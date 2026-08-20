"""상점 스킨 썸네일을 **게임에서 실제로 보이는 그대로** 만든다.

스킨은 새 아트가 아니라 `lib/ui/skins.dart` 의 ColorFilter(색 행렬)다. 그래서
상점 그림을 따로 그리면 십중팔구 실물보다 화려해진다 — 사면 "그림과 다르다"가
된다. 여기서는 **같은 행렬을 같은 원본 프레임에 적용**해서 뽑는다.

⚠️ skins.dart 의 행렬을 고치면 이 파일의 GOLD/ALBINO/ARENA 도 같이 고치고
다시 돌린다. 두 벌이 갈리면 상점 그림이 조용히 거짓말을 시작한다.

    cd packages/app ; python tool/make_skin_thumbs.py
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUGS = os.path.join(ROOT, 'assets', 'images', 'bugs')
BIOMES = os.path.join(ROOT, 'assets', 'images', 'biomes')
OUT = os.path.join(ROOT, 'assets', 'images', 'shop')

SIZE = 512

# ── skins.dart 와 **글자 그대로 같은** 행렬 (4x5, 이동열은 0~255) ──────
GOLD = [
    [0.5233, 1.0273, 0.1995, 0, -30],
    [0.4037, 0.7925, 0.1539, 0, -28],
    [0.1196, 0.2348, 0.0456, 0, -20],
]
ALBINO = [
    [0.2756, 0.2465, 0.0479, 0, 140],
    [0.1256, 0.3465, 0.0479, 0, 138],
    [0.1256, 0.2465, 0.1979, 0, 142],
]
ARENA = [
    [1.5127, -0.3038, -0.0590, 0, -8],
    [-0.1548, 1.3638, -0.0590, 0, -18],
    [-0.1548, -0.3038, 1.6085, 0, -28],
]


def apply_matrix(im, m):
    """Flutter ColorFilter.matrix 와 같은 계산. 알파는 건드리지 않는다."""
    a = np.asarray(im.convert('RGBA'), dtype=np.float32)
    rgb, alpha = a[..., :3], a[..., 3:]
    out = np.empty_like(rgb)
    for i, row in enumerate(m):
        out[..., i] = (
            rgb[..., 0] * row[0]
            + rgb[..., 1] * row[1]
            + rgb[..., 2] * row[2]
            + alpha[..., 0] * row[3]
            + row[4]
        )
    out = np.clip(out, 0, 255)
    return Image.fromarray(
        np.concatenate([out, alpha], axis=-1).astype(np.uint8), 'RGBA')


def backdrop(inner, outer):
    """가운데가 밝은 원형 그라데이션. 곤충 실루엣을 카드에서 띄운다."""
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    c = (SIZE - 1) / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2) / (c * 1.12)
    t = np.clip(d, 0, 1)[..., None]
    rgb = np.array(inner, np.float32) * (1 - t) + np.array(outer, np.float32) * t
    a = np.full((SIZE, SIZE, 1), 255, np.float32)
    return Image.fromarray(
        np.concatenate([rgb, a], axis=-1).astype(np.uint8), 'RGBA')


def bug_thumb(src, matrix, inner, outer, dst):
    bug = Image.open(os.path.join(BUGS, src)).convert('RGBA')
    bug = apply_matrix(bug, matrix)
    # 알파 경계 기준으로 잘라내 화면을 꽉 채운다 — 프레임 캔버스는 세 자세 중
    # 가장 큰 것에 맞춰져 있어서 대기 자세는 여백이 크다.
    box = bug.split()[3].getbbox()
    if box:
        bug = bug.crop(box)
    scale = (SIZE * 0.80) / max(bug.size)
    bug = bug.resize(
        (max(1, round(bug.width * scale)), max(1, round(bug.height * scale))),
        Image.LANCZOS)
    card = backdrop(inner, outer)
    card.alpha_composite(
        bug, ((SIZE - bug.width) // 2, (SIZE - bug.height) // 2))
    card.convert('RGB').save(os.path.join(OUT, dst), 'WEBP', quality=92)
    print('wrote', dst)


def arena_thumb(src, dst):
    bg = Image.open(os.path.join(BIOMES, src)).convert('RGBA')
    # 정사각으로 가운데 크롭 후 필터.
    s = min(bg.size)
    bg = bg.crop((((bg.width - s) // 2), (bg.height - s) // 2,
                  (bg.width - s) // 2 + s, (bg.height - s) // 2 + s))
    bg = bg.resize((SIZE, SIZE), Image.LANCZOS)
    apply_matrix(bg, ARENA).convert('RGB').save(
        os.path.join(OUT, dst), 'WEBP', quality=92)
    print('wrote', dst)


os.makedirs(OUT, exist_ok=True)
# 대표 종: 장수풍뎅이 = 일본장수풍뎅이, 사슴벌레 = 왕사슴벌레(실루엣이 제일 확실).
bug_thumb('rhino_japanese_adult_1.webp', GOLD,
          (74, 56, 20), (26, 18, 8), 'skin_gold_rhino.webp')
bug_thumb('stag_giant_adult_1.webp', ALBINO,
          (58, 66, 78), (16, 20, 26), 'skin_albino_stag.webp')
arena_thumb('fire.webp', 'theme_arena.webp')
