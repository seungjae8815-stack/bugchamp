"""제미나이 2x2 시트 → 게임용 몬스터 프레임 4장.

`docs/art_prompts_v2.md` STEP 17 로 뽑은 시트를 잘라 넣는다.
좌상 대기 / 우상 덤벼듦 / 좌하 복귀 / 우하 움찔.

⚠️ **프레임마다 방향이 다르다.** 같은 시트 안에서도 어떤 자세는 왼쪽, 어떤
자세는 오른쪽을 본다. 종 단위로 뒤집으면 반드시 몇 장이 반대로 들어간다
(2026-09-09 에 두 번 틀렸다). 그래서 [FLIP] 은 **종 x 프레임** 표다.
게임에서 적은 화면 오른쪽에 서서 **왼쪽(플레이어)** 을 본다.
"""

import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = os.environ.get('MONSTER_SRC', r'C:\Users\Lenovo\Downloads\곤충키우기 몬스터')
OUT = 'packages/app/assets/images/habitats'
NAMES = ['', '_attack_1', '_attack_2', '_hurt_1']
KEY = (255, 0, 255)
TARGET_H = 512

# 종 -> (대기, 덤벼듦, 복귀, 움찔) 각각 좌우를 뒤집을지.
FLIP = {
    'tree':         (1, 1, 1, 1),
    'flower':       (1, 1, 1, 0),
    'rock':         (1, 1, 1, 0),
    'stump':        (1, 1, 0, 1),
    'mushroom':     (1, 1, 1, 1),
    'log_pile':     (0, 1, 0, 1),
    'fern':         (1, 1, 0, 1),
    'acorn':        (0, 0, 1, 0),
    'reed':         (1, 1, 0, 1),
    'pebble':       (1, 1, 1, 1),
    'driftwood':    (1, 1, 1, 1),
    'tall_grass':   (0, 1, 1, 0),
    'clover':       (1, 1, 0, 1),
    'dandelion':    (0, 0, 1, 0),
    'crystal_rock': (0, 0, 1, 0),
    'dead_tree':    (0, 0, 1, 0),
    'moss_boulder': (1, 1, 0, 1),
    'basalt':       (1, 1, 1, 1),
    'ember_vent':   (0, 0, 1, 0),
    'ash_mound':    (0, 0, 1, 0),
}

# 이 시트들만 칸마다 포즈 이름이 글자로 박혀 있다(FLINCH 등). 글자는 몸통과
# 떨어진 섬으로 남아 색으로는 못 지운다.
DROP_ISLANDS = {'basalt', 'ember_vent'}

# ⚠️ 돌 몬스터는 **몸 색이 배경과 겹친다**(rock·pebble 은 배경과 거리 6 까지
# 붙은 픽셀이 있다). 색으로 배경을 지우면 몸에 구멍이 뚫린다 — 이 둘만 끈다.
# 둘러싸인 배경(팔 사이)은 못 지우지만, 구멍 난 몸보다는 낫다.
SAME_THRESH = {'rock': 0, 'pebble': 0}

# 같은 이유로 **그림자 규칙(색조가 같고 어둡기만 한 픽셀)** 도 끈다 — 베이지
# 돌은 배경과 색조까지 같아서 몸이 통째로 그림자로 잡힌다.
SHADOW_OFF = {'rock', 'pebble'}

# 그림자 규칙을 끈 종은 발밑 타원이 남는다. 자갈깨비가 그렇다.
# 그 타원은 **완전히 균일한 한 가지 색**이고, 발·다리는 훨씬 어둡다
# (그림자 187,157,133 vs 다리 131,109,93 — 거리 144). 색 하나로 가른다.
FLAT_SHADOW = {'pebble'}

# 색 규칙을 끄면 **팔 사이처럼 둘러싸인 배경**이 남는다(모서리에서 흘려보내기로는
# 못 닿는다). 돌 몬스터는 몸의 밝은 면도 배경색에 가깝지만, 그건 **작고 흩어져**
# 있고 둘러싸인 배경은 **크고 이어져** 있다. 크기로 가른다.
POCKET = {'rock': 1500, 'pebble': 1500}

# basalt 시트만 액자형 회색 패널 위에 그려져 있다 — 흰 여백에서 패널로
# 이어 흘려보내야 해서 문턱을 크게 잡는다(몸은 훨씬 어두워 거기서 멈춘다).
FLOOD_THRESH = {
    'basalt': 78,
    # ⚠️ 돌 몬스터는 문턱을 **낮춰야** 한다. 42 로 두면 흘려보내기가 몸의 밝은
    # 면을 타고 안쪽까지 들어가 5만 픽셀을 지웠다(= 몸에 구멍).
    'rock': 20,
    'pebble': 20,
}


def bg_of(a):
    return np.median(
        np.array([a[4, 4], a[4, -5], a[-5, 4], a[-5, -5]]), axis=0
    ).astype(int)


def kill_sparkle(im):
    """제미나이 워터마크(시트 우하단 흰 별)를 배경색으로 덮는다.

    별은 배경보다 **밝고 채도가 낮다**. 그 자리에 오는 몸은 대개 어둡거나
    채도가 높아 갈린다. 사각형으로 덮으면 몸이 잘려 나간다.
    """
    a = np.array(im).astype(np.int16)
    bg = bg_of(a)
    H, W, _ = a.shape
    y0, x0 = int(H * 0.80), int(W * 0.80)
    box = a[y0:, x0:]
    luma = box.mean(axis=2)
    sat = box.max(axis=2) - box.min(axis=2)
    box[(luma > bg.mean() + 10) & (sat < 46)] = bg
    a[y0:, x0:] = box
    return Image.fromarray(a.astype(np.uint8), 'RGB')


def bg_like(a, bg, same_thresh=40, shadow=True):
    """배경으로 취급할 픽셀 — **색이 같은 곳**과 **바닥 그림자**.

    - 팔 사이처럼 **둘러싸인 배경**은 모서리에서 흘려보내는 방식으로 못 닿는다.
      색으로 직접 걸러야 한다.
    - 바닥 그림자는 배경보다 80~135 나 떨어져 있어 문턱만 올리면 밝은 몸통까지
      먹는다. 대신 **배경과 색조가 같고 어둡기만 한지**로 가른다 —
      회색 몸(1,1,1)과 연녹색 배경(0.88,1.11,1.00)은 이 방향이 뚜렷이 다르다.
    """
    d = np.abs(a - bg).sum(axis=2)
    same = d < same_thresh if same_thresh > 0 else np.zeros(d.shape, bool)

    m = a.mean(axis=2)
    k = m / max(bg.mean(), 1e-6)
    with np.errstate(divide='ignore', invalid='ignore'):
        dirn = a / np.maximum(m, 1e-6)[:, :, None]
    bdir = bg / bg.mean()
    dirdiff = np.abs(dirn - bdir).sum(axis=2)
    shade = (k > 0.72) & (k < 0.995) & (dirdiff < 0.06)
    if not shadow:
        shade = np.zeros(same.shape, bool)
    return same | shade


def pockets(a, bg, keep, min_area, tol=30, grid=256):
    """둘러싸인 배경(팔 사이 등)만 골라 지운다.

    배경색에 가까운 픽셀 중 **크게 이어진 덩어리**만 배경으로 본다.
    몸의 밝은 면은 배경색에 가까워도 잘게 흩어져 있어 살아남는다.
    """
    near = (np.abs(a - bg).sum(axis=2) < tol) & keep
    h, w = near.shape
    small = np.array(
        Image.fromarray((near * 255).astype(np.uint8), 'L').resize(
            (grid, grid), Image.NEAREST
        )
    ) > 0
    seen = np.zeros((grid, grid), bool)
    out = np.zeros((grid, grid), bool)
    scale = (h / grid) * (w / grid)
    for sy in range(grid):
        for sx in range(grid):
            if not small[sy, sx] or seen[sy, sx]:
                continue
            q = deque([(sy, sx)])
            seen[sy, sx] = True
            cells = []
            while q:
                y, x = q.popleft()
                cells.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if (0 <= ny < grid and 0 <= nx < grid
                            and small[ny, nx] and not seen[ny, nx]):
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if len(cells) * scale >= min_area:
                for y, x in cells:
                    out[y, x] = True
    up = np.array(
        Image.fromarray((out * 255).astype(np.uint8), 'L').resize(
            (w, h), Image.NEAREST
        )
    ) > 0
    return up & near


def flat_shadow(a, keep, band=0.30, tol=8, min_area=3000):
    """발밑의 **균일한 한 색** 타원을 찾아 지운다.

    색조·밝기로는 못 가른다 — 돌 몬스터는 몸의 밝은 면이 같은 띠에 들어와
    2만 픽셀이 함께 지워졌다. 대신 "아래쪽에 넓게 깔린 단일색"이라는
    그림자만의 성질을 쓴다.
    """
    h, w, _ = a.shape
    y0 = int(h * (1 - band))
    sub = a[y0:]
    m = keep[y0:]
    if m.sum() < min_area:
        return np.zeros(keep.shape, bool)
    vals, counts = np.unique(
        sub[m].reshape(-1, 3) // 4, axis=0, return_counts=True
    )
    modal = vals[counts.argmax()] * 4 + 2
    if counts.max() < min_area:
        return np.zeros(keep.shape, bool)
    out = np.zeros(keep.shape, bool)
    out[y0:] = (np.abs(sub - modal).sum(axis=2) < tol * 3) & m
    return out


def keep_big_islands(mask, frac=0.05, grid=192):
    h, w = mask.shape
    small = np.array(
        Image.fromarray((mask * 255).astype(np.uint8), 'L').resize(
            (grid, grid), Image.NEAREST
        )
    ) > 0
    lab = np.zeros((grid, grid), np.int32)
    areas = [0]
    for sy in range(grid):
        for sx in range(grid):
            if not small[sy, sx] or lab[sy, sx]:
                continue
            n = len(areas)
            q = deque([(sy, sx)])
            lab[sy, sx] = n
            a = 0
            while q:
                y, x = q.popleft()
                a += 1
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if (0 <= ny < grid and 0 <= nx < grid
                            and small[ny, nx] and not lab[ny, nx]):
                        lab[ny, nx] = n
                        q.append((ny, nx))
            areas.append(a)
    if len(areas) <= 1:
        return mask
    biggest = max(areas[1:])
    good = np.zeros(len(areas), bool)
    for i, a in enumerate(areas):
        if i and a >= biggest * frac:
            good[i] = True
    up = np.array(
        Image.fromarray((good[lab] * 255).astype(np.uint8), 'L').resize(
            (w, h), Image.NEAREST
        )
    ) > 0
    return mask & up


def cut(path, mid):
    src = kill_sparkle(Image.open(path).convert('RGB'))
    W, H = src.size
    hw, hh = W // 2, H // 2
    thresh = FLOOD_THRESH.get(mid, 42)
    frames = []
    for box in [(0, 0, hw, hh), (hw, 0, W, hh), (0, hh, hw, H), (hw, hh, W, H)]:
        q = src.crop(box)
        work = q.copy()
        ins = int(min(q.width, q.height) * 0.06)
        seeds = [(0, 0), (q.width - 1, 0), (0, q.height - 1),
                 (q.width - 1, q.height - 1), (ins, ins),
                 (q.width - 1 - ins, ins), (ins, q.height - 1 - ins),
                 (q.width - 1 - ins, q.height - 1 - ins)]
        for c in seeds:
            ImageDraw.floodfill(work, c, KEY, thresh=thresh)
        m = np.array(work)
        keep = ~((m[:, :, 0] == 255) & (m[:, :, 1] == 0) & (m[:, :, 2] == 255))
        a = np.array(q).astype(int)
        keep &= ~bg_like(a, bg_of(a), SAME_THRESH.get(mid, 40),
                         shadow=mid not in SHADOW_OFF)
        if mid in POCKET:
            keep &= ~pockets(a, bg_of(a), keep, POCKET[mid])
        if mid in FLAT_SHADOW:
            keep &= ~flat_shadow(a, keep)
        if mid in DROP_ISLANDS:
            keep = keep_big_islands(keep)
        alpha = Image.fromarray(np.where(keep, 255, 0).astype(np.uint8), 'L')
        alpha = alpha.filter(ImageFilter.GaussianBlur(1.2)).point(
            lambda v: 0 if v < 90 else (255 if v > 190 else int((v - 90) * 255 / 100))
        )
        rgba = q.convert('RGBA')
        rgba.putalpha(alpha)
        frames.append(rgba)
    return frames


def main():
    only = set(sys.argv[1:])
    for mid, flips in sorted(FLIP.items()):
        if only and mid not in only:
            continue
        path = os.path.join(SRC, mid + '.png')
        if not os.path.exists(path):
            print('없음:', path)
            continue
        frames = cut(path, mid)
        boxes = [f.getbbox() for f in frames]
        L = min(b[0] for b in boxes)
        T = min(b[1] for b in boxes)
        R = max(b[2] for b in boxes)
        B = max(b[3] for b in boxes)
        # ⚠️ 네 칸을 각자 트림하면 안 된다 — 여백이 달라 재생할 때 몬스터가 튄다.
        scale = TARGET_H / (B - T)
        size = (max(1, round((R - L) * scale)), TARGET_H)
        for f, suffix, flip in zip(frames, NAMES, flips):
            img = f.crop((L, T, R, B)).resize(size, Image.LANCZOS)
            if flip:
                img = img.transpose(Image.FLIP_LEFT_RIGHT)
            img.save(f'{OUT}/{mid}{suffix}.webp', 'WEBP', quality=85, method=6)
        print(f'{mid:14s} {size}  뒤집기 {flips}')


if __name__ == '__main__':
    main()
