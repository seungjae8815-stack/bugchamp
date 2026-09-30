"""제미나이 요정 그림(.jpg) -> 게임용 투명 WebP (docs/art_prompts_fairy.md).

쓰는 법(워크스페이스 루트에서):
    python tool/import_fairy_art.py [원본 폴더] [미리보기.png]

하는 일
 - 요정 동작 시트(fairy_<id>_sheet.jpg, 가로 3동작) -> fairy_<id>_1 · _2 · _cast (512 정사각)
   · 세 동작을 **빈 세로줄**로 가르고(가운데 그림이 옆 칸에 걸쳐도 안 잘린다),
   · 칸마다 **몸통 중심**(아래 60% 의 불투명 무게중심)을 맞춰 **같은 크기**로 자른다 —
     날갯짓 1·2 를 번갈아 보여 줄 때 몸이 흔들리지 않게(날개 크기가 달라 그림 경계로 맞추면 튄다).
 - 아이콘(알·둥지·가속기·속성석·가루·탭) -> 514 정사각(기존 아이콘 규격 — tool/import_skill_icons.py 와 같다).
 - 배경(fairy_bg.jpg) -> 불투명 WebP(워터마크만 주변 색으로 메운다).

배경 지우기는 import_skill_icons.py 와 같다: 가장자리에서 flood fill(그림 안쪽의 같은 색은 남긴다) ·
경계 디스필(어두운 화면에서 흰 헤일로 방지).

⚠️ 제미나이 워터마크(✦)는 **오른쪽 아래 구석**에 떨어진 작은 섬이다. 평평한 배경 위라 flood fill 로
   안 지워지고(배경보다 밝다) 그림으로 남는다 → 구석 안에 **통째로 들어간 작은 섬**만 지운다.
   발끝처럼 몸과 이어진 것은 섬의 상자가 구석 밖으로 나가므로 남는다.
"""

import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

SRC = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\Lenovo\Downloads\요정'
PREVIEW = sys.argv[2] if len(sys.argv) > 2 else None
OUT_FAIRY = 'packages/app/assets/images/fairies'
OUT_TAB = 'packages/app/assets/images/ui/tab'
LO, HI = 10.0, 46.0
FRAME = 512
ICON = 514
KINDS = ['ignis', 'undine', 'terrariel', 'sylphid', 'voltea', 'lunaris', 'titania', 'asteria']


def load(path):
    a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    h, w, _ = a.shape
    edge = np.concatenate([a[0], a[h - 1], a[:, 0], a[:, w - 1]])
    return a, np.median(edge, axis=0)


def flood_alpha(a, bg):
    """가장자리에서 배경을 흘려 지운 알파(0~1)와 디스필한 RGB."""
    h, w, _ = a.shape
    dist = np.sqrt(((a - bg) ** 2).sum(2))
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
    alpha = np.ones((h, w), np.float32)
    soft = np.clip((dist - LO) / (HI - LO), 0.0, 1.0)
    alpha[outside] = soft[outside]
    rgb = a.copy()
    m = (alpha > 0.004) & (alpha < 0.996)
    if m.any():
        av = alpha[m][:, None]
        rgb[m] = np.clip((a[m] - (1.0 - av) * bg[None, :]) / av, 0, 255)
    return alpha, rgb


def islands(mask):
    """4-연결 섬 목록 [(픽셀 수, y0, x0, y1, x1, 좌표 배열)]."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    out = []
    ys, xs = np.nonzero(mask)
    for sy, sx in zip(ys, xs):
        if seen[sy, sx]:
            continue
        seen[sy, sx] = True
        dq = deque([(sy, sx)])
        pts = []
        while dq:
            y, x = dq.popleft()
            pts.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    dq.append((ny, nx))
        p = np.array(pts)
        out.append((len(pts), p[:, 0].min(), p[:, 1].min(), p[:, 0].max(), p[:, 1].max(), p))
    return out


def drop_watermark(alpha):
    """오른쪽 아래 구석(가로·세로 78% 밖)에 통째로 들어간 작은 섬을 지운다. 지운 픽셀 수."""
    h, w = alpha.shape
    y0, x0 = int(h * 0.78), int(w * 0.78)
    sub = alpha[y0:, x0:] > 0.03
    gone = 0
    for n, a0, b0, a1, b1, p in islands(sub):
        touches_edge = a0 == 0 or b0 == 0  # 구석 상자 위·왼쪽 경계에 닿으면 바깥과 이어졌을 수 있다
        if n < 4000 and not touches_edge:
            alpha[y0 + p[:, 0], x0 + p[:, 1]] = 0
            gone += n
    return gone


def to_rgba(rgb, alpha):
    return Image.fromarray(np.dstack([rgb, alpha * 255.0]).astype(np.uint8), 'RGBA')


def square(img, side_out, margin=0.035):
    bbox = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    if bbox:
        img = img.crop(bbox)
    side = int(round(max(img.size) * (1 + margin * 2)))
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return sq.resize((side_out, side_out), Image.LANCZOS)


def icon(path, out):
    a, bg = load(path)
    alpha, rgb = flood_alpha(a, bg)
    wm = drop_watermark(alpha)
    img = square(to_rgba(rgb, alpha), ICON)
    img.save(out, 'WEBP', lossless=True)
    return img, wm


def sheet(path, kind):
    a, bg = load(path)
    alpha, rgb = flood_alpha(a, bg)
    wm = drop_watermark(alpha)
    h, w = alpha.shape
    solid = alpha > 0.35
    col = solid.sum(0)
    # 빈 세로줄로 덩어리를 가른다 → 가장 넓은 3개가 세 동작(불꽃·꽃잎 같은 작은 조각은 가까운 쪽에 붙인다).
    runs, x = [], 0
    while x < w:
        if col[x] > 0:
            s = x
            while x < w and col[x] > 0:
                x += 1
            runs.append([s, x])
        else:
            x += 1
    main = sorted(sorted(runs, key=lambda r: r[1] - r[0], reverse=True)[:3])
    if len(main) != 3:
        raise SystemExit('%s: 동작 3개를 못 찾았다(덩어리 %d개) — 겹친 그림이면 다시 뽑을 것' % (path, len(runs)))
    for r in runs:
        if r in main:
            continue
        c = (r[0] + r[1]) / 2
        near = min(main, key=lambda m: min(abs(c - m[0]), abs(c - m[1])))
        near[0], near[1] = min(near[0], r[0]), max(near[1], r[1])
    rows = np.nonzero(solid.any(1))[0]
    top, bot = rows.min(), rows.max() + 1
    # 몸통 중심 = 아래 60% 의 불투명 무게중심(날개는 대부분 위쪽이라 덜 흔들린다).
    body_y = int(top + (bot - top) * 0.4)
    anchors = []
    for s, e in main:
        m = solid[body_y:bot, s:e]
        xs = np.nonzero(m)[1]
        anchors.append(s + (xs.mean() if len(xs) else (e - s) / 2))
    half = int(max(max(ax - s, e - ax) for (s, e), ax in zip(main, anchors)) + 6)
    height = bot - top + 12
    side = max(2 * half, height)
    frames = []
    for (s, e), ax in zip(main, anchors):
        # 이 동작의 기둥만 남긴다(창이 옆 동작까지 닿아도 섞이지 않게).
        keep = np.zeros_like(alpha)
        keep[:, s:e] = alpha[:, s:e]
        img = to_rgba(rgb, keep)
        cx, cy = int(round(ax)), (top + bot) // 2
        box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
        canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
        crop = img.crop((max(0, box[0]), max(0, box[1]), min(w, box[2]), min(h, box[3])))
        canvas.paste(crop, (max(0, -box[0]), max(0, -box[1])))
        frames.append(canvas.resize((FRAME, FRAME), Image.LANCZOS))
    for img, suffix in zip(frames, ['_1', '_2', '_cast']):
        img.save(os.path.join(OUT_FAIRY, 'fairy_%s%s.webp' % (kind, suffix)), 'WEBP', lossless=True)
    return frames, wm


def background(path, out):
    img = Image.open(path).convert('RGB')
    a = np.asarray(img).astype(np.float32)
    h, w, _ = a.shape
    y0, x0 = int(h * 0.85), int(w * 0.75)
    reg = a[y0:, x0:]
    lum = reg.mean(2)
    base = np.median(lum)
    star = lum > base + 25
    n = int(star.sum())
    if n:
        m = Image.fromarray((star * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
        star = np.asarray(m) > 0
        blur = np.asarray(Image.fromarray(reg.astype(np.uint8)).filter(ImageFilter.GaussianBlur(18))).astype(np.float32)
        fill = np.median(reg[~star], axis=0) if (~star).any() else blur.mean((0, 1))
        reg[star] = fill * 0.5 + blur[star] * 0.5
        a[y0:, x0:] = reg
    Image.fromarray(a.astype(np.uint8)).save(out, 'WEBP', quality=90)
    return n


def checker(img, light):
    c1, c2 = ((235, 235, 235), (205, 205, 205)) if light else ((45, 48, 44), (28, 30, 27))
    bgim = Image.new('RGB', img.size, c1)
    px = bgim.load()
    for y in range(img.height):
        for x in range(img.width):
            if ((x // 16) + (y // 16)) % 2:
                px[x, y] = c2
    bgim.paste(img, (0, 0), img)
    return bgim


if __name__ == '__main__':
    os.makedirs(OUT_FAIRY, exist_ok=True)
    shots = []
    for k in KINDS:
        frames, wm = sheet(os.path.join(SRC, 'fairy_%s_sheet.jpg' % k), k)
        print('시트 %-10s -> _1 _2 _cast  (워터마크 %d픽셀 지움)' % (k, wm))
        shots += frames
    icons = ['fairy_egg', 'fairy_nest', 'fairy_dust', 'acc30m', 'acc2h', 'acc8h'] + [
        'stone_%s' % s for s in ['attack', 'hp', 'defense', 'attackSpeed', 'critDamage', 'bossDamage', 'petShare']]
    for name in icons:
        img, wm = icon(os.path.join(SRC, name + '.jpg'), os.path.join(OUT_FAIRY, name + '.webp'))
        print('아이콘 %-18s (워터마크 %d픽셀 지움)' % (name, wm))
        shots.append(img)
    img, wm = icon(os.path.join(SRC, 'fairy.jpg'), os.path.join(OUT_TAB, 'fairy.webp'))
    print('탭 fairy (워터마크 %d픽셀 지움)' % wm)
    shots.append(img)
    n = background(os.path.join(SRC, 'fairy_bg.jpg'), os.path.join(OUT_FAIRY, 'fairy_bg.webp'))
    print('배경 fairy_bg (워터마크 후보 %d픽셀 메움)' % n)

    if PREVIEW:
        cell = 170
        cols = 8
        rows = (len(shots) + cols - 1) // cols
        prev = Image.new('RGB', (cols * cell, rows * cell * 2), (255, 255, 255))
        for i, s in enumerate(shots):
            t = s.resize((cell, cell), Image.LANCZOS)
            r, c = divmod(i, cols)
            prev.paste(checker(t, True), (c * cell, r * 2 * cell))
            prev.paste(checker(t, False), (c * cell, r * 2 * cell + cell))
        prev.save(PREVIEW)
        print('미리보기', PREVIEW)
