# -*- coding: utf-8 -*-
"""제미나이 아이콘 시트(3x3, 8개) -> 낱장 투명 WebP.

`docs/art_prompts_icons.md` 로 뽑은 시트를 칸마다 잘라 앱 애셋으로 넣는다.

    python tool/import_icon_sheet.py                # 정의된 시트 전부
    python tool/import_icon_sheet.py sheet_mission_part   # 하나만

## 왜 1/3 로 무작정 자르지 않나
제미나이는 격자를 **정확히** 그려 주지 않는다. 칸 경계로 자르면 물건이 잘리거나
옆 칸이 딸려 온다. 그래서 **그림 덩어리(연결 성분)를 먼저 찾고** 그 중심이 어느
칸에 있는지로 배정한다 — 격자가 조금 흔들려도 버틴다.

## 배경·워터마크
배경은 아이콘 24장과 같은 평평한 세이지라, 판별도 `import_skill_icons.py` 와 같다:
그림자는 **배경색의 어두운 버전**(P ~= bg*k)이라 그 직선에서의 오차로 가른다.
워터마크(✦)는 **오른쪽 아래 칸**에 떨어지는데, 프롬프트가 그 칸을 비우라고
지시하므로 배경 위에만 놓인다 -> 덩어리 크기 기준에서 걸러진다.

⚠️ 첫 시트를 받으면 `--check` 로 **몇 개를 찾았는지** 먼저 확인할 것.
   8개가 아니면 자르지 말고 그림을 다시 뽑는 편이 빠르다.
"""

import io
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

# 윈도우 콘솔(cp949)은 '—' 같은 글자에서 죽는다 — 출력만 UTF-8 로 고정한다.
if (sys.stdout.encoding or '').lower().replace('-', '') != 'utf8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

SRC = os.environ.get('SHEET_SRC', r'C:\Users\Lenovo\Downloads')
TARGET = 514            # 기존 아이콘 규격(upgrades/attack.webp 와 같다)
MARGIN = 0.035
RESID = 14.0            # bg*k 직선에서의 허용 오차
KLO, KHI = 0.40, 1.07
MIN_AREA_FRAC = 0.0015  # 이보다 작은 덩어리는 부스러기·워터마크로 본다

# 시트 -> (칸 순서대로의 저장 경로). 왼->오른, 위->아래. 9번째는 비어 있다.
SHEETS = {
    'sheet_mission_part': [
        'ui/part/horn_jaw', 'ui/part/cuticle', 'ui/part/wing', 'ui/part/build',
        'ui/mission/kill_monsters', 'ui/mission/kill_bosses',
        'ui/mission/buy_upgrades', 'ui/mission/forge_items',
    ],
    'sheet_trophy_reward': [
        'ui/rank/trophy', 'ui/rank/promote', 'ui/rank/crown',
        'ui/mission/reach_stage',
        'ui/dlg/reward', 'ui/dlg/gift', 'ui/dlg/mail', 'ui/dlg/gift_code',
    ],
    # 자동합성·자동방생·교환소·부화기·공방급행·뽑기카드는 **이미 아트가 있다**
    # (ui/auto_synth·auto_release·exchange·incubator_capsule·anvil·gacha_card_back).
    # 새로 그리지 않고 팝업 제목에 그 아트를 붙인다 — 시트 한 장이 줄었다.
    'sheet_progress_info': [
        'ui/dlg/egg', 'ui/dlg/filter', 'ui/dlg/ticket', 'ui/dlg/offline',
        'ui/dlg/zone_clear', 'ui/dlg/tier_clear', 'ui/dlg/element_wheel',
        'ui/dlg/notice',
    ],
}

# 저장 위치. 검증용으로 임시 폴더에 뽑을 땐 OUT_ROOT 환경변수로 바꾼다.
OUT_ROOT = os.environ.get('OUT_ROOT', 'packages/app/assets/images')


def _masks(a):
    """(배경 여부, k, 잔차) — 그림자까지 배경으로 본다."""
    h, w, _ = a.shape
    edge = np.concatenate([a[0], a[h - 1], a[:, 0], a[:, w - 1]])
    bg = np.median(edge, axis=0)
    bb = float((bg * bg).sum())
    k = (a * bg[None, None, :]).sum(2) / bb
    resid = np.sqrt(((a - k[:, :, None] * bg[None, None, :]) ** 2).sum(2))
    bglike = (resid < RESID) & (k > KLO) & (k < KHI)
    return bg, bglike, k, resid


def find_cells(path, grid=3):
    """덩어리를 찾아 (행, 열) 칸에 배정한다. [(행,열,슬라이스,마스크)] 반환."""
    im = Image.open(path).convert('RGB')
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape
    bg, bglike, _, _ = _masks(a)

    lab, n = ndimage.label(~bglike)
    found = []
    for i in range(1, n + 1):
        m = lab == i
        if m.sum() < MIN_AREA_FRAC * h * w:
            continue        # 부스러기·워터마크
        ys, xs = np.nonzero(m)
        cy, cx = ys.mean(), xs.mean()
        r = min(grid - 1, int(cy / h * grid))
        c = min(grid - 1, int(cx / w * grid))
        found.append((r, c, ys.min(), ys.max(), xs.min(), xs.max(), int(m.sum())))

    # 같은 칸의 덩어리는 합친다(물건 하나가 여러 조각으로 갈릴 수 있다).
    cells = {}
    for r, c, y0, y1, x0, x1, area in found:
        if (r, c) in cells:
            p = cells[(r, c)]
            cells[(r, c)] = (min(p[0], y0), max(p[1], y1),
                             min(p[2], x0), max(p[3], x1), p[4] + area)
        else:
            cells[(r, c)] = (y0, y1, x0, x1, area)
    return im, a, bg, bglike, cells


def cut_cell(a, bg, bglike, box, target=TARGET):
    """칸 하나를 잘라 투명 WebP 용 이미지로."""
    y0, y1, x0, x1 = box
    pad = 6
    y0, x0 = max(0, y0 - pad), max(0, x0 - pad)
    y1, x1 = min(a.shape[0], y1 + pad + 1), min(a.shape[1], x1 + pad + 1)
    sub = a[y0:y1, x0:x1]
    sub_bg = bglike[y0:y1, x0:x1]

    # 경계를 1px 깎고 부드럽게 — 세이지 헤일로 방지.
    inside = ndimage.binary_erosion(~sub_bg, iterations=1)
    alpha = ndimage.gaussian_filter(inside.astype(np.float32), 0.8)
    alpha = np.clip((alpha - 0.35) / 0.45, 0.0, 1.0)

    rgb = sub.copy()
    m = (alpha > 0.004) & (alpha < 0.996)
    if m.any():
        av = alpha[m][:, None]
        rgb[m] = np.clip((sub[m] - (1.0 - av) * bg[None, :]) / av, 0, 255)

    img = Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), 'RGBA')
    bbox = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    if bbox:
        img = img.crop(bbox)
    side = int(round(max(img.size) * (1 + MARGIN * 2)))
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return sq.resize((target, target), Image.LANCZOS)


def run(name, names, check_only=False):
    path = os.path.join(SRC, name + '.jpg')
    if not os.path.exists(path):
        path = os.path.join(SRC, name + '.png')
    if not os.path.exists(path):
        print('%-22s 파일 없음 — 건너뜀' % name)
        return
    im, a, bg, bglike, cells = find_cells(path)
    order = sorted(cells.keys())
    print('%-22s %s  덩어리 %d개' % (name, im.size, len(order)))
    for (r, c) in order:
        y0, y1, x0, x1, area = cells[(r, c)]
        print('    %d행%d열  %dx%d  면적 %d' % (r + 1, c + 1, x1 - x0, y1 - y0, area))
    if (2, 2) in cells:
        print('    ⚠️ 오른쪽 아래 칸에 그림이 있다 — 워터마크가 겹쳤을 수 있다. 눈으로 볼 것.')
    if len(order) != len(names):
        print('    ⚠️ %d개를 기대했는데 %d개다 — 자르지 않는다. 그림을 다시 뽑는 게 빠르다.'
              % (len(names), len(order)))
        return
    if check_only:
        return
    for (r, c), out in zip(order, names):
        y0, y1, x0, x1, _ = cells[(r, c)]
        img = cut_cell(a, bg, bglike, (y0, y1, x0, x1))
        dst = os.path.join(OUT_ROOT, out + '.webp')
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        img.save(dst, 'WEBP', lossless=True)
        print('    -> %-34s %4.0f KB' % (out + '.webp',
                                         os.path.getsize(dst) / 1024))


if __name__ == '__main__':
    args = [x for x in sys.argv[1:] if not x.startswith('--')]
    check = '--check' in sys.argv
    todo = args or list(SHEETS)
    for nm in todo:
        if nm not in SHEETS:
            print('모르는 시트: %s (%s)' % (nm, ', '.join(SHEETS)))
            continue
        run(nm, SHEETS[nm], check_only=check)
