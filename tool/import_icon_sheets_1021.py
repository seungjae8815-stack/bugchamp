# -*- coding: utf-8 -*-
"""1.0.21 아이콘 시트(2x2 · 1x3) + 낱장 -> 투명 WebP (`assets/images/ui/icon/`).

`docs/art_prompts_icon_sheets.md` 로 뽑은 그림을 넣는다. 자르기·배경 제거는
`import_icon_sheet.py`(3x3 시트용)의 함수를 그대로 쓰고, 여기서는 **칸 배정만** 다르게 한다:
덩어리 중심에서 가장 가까운 칸으로(2x2 는 네 귀퉁이, 1x3 은 가로 셋). 제미나이가 칸을 정확히
안 지켜도(삼각형 배치 등) 버틴다.

    python tool/import_icon_sheets_1021.py            # 전부
    python tool/import_icon_sheets_1021.py --check    # 몇 개 찾았는지만

⚠️ 제미나이는 "아래 15% 비우기"를 안 지키고 오른쪽 아래(약 905,905)에 ✦ 로고를 찍는다.
   그 둘레에서 배경보다 밝은 점만 배경색으로 덮어 지운다(그림에 붙어 있어도 떨어진다).
"""

import io
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import import_icon_sheet as base  # noqa: E402

if (sys.stdout.encoding or '').lower().replace('-', '') != 'utf8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

SRC = os.environ.get('SHEET_SRC', r'C:\Users\Lenovo\Downloads\아이콘')
OUT = os.environ.get('OUT_ROOT', 'packages/app/assets/images/ui/icon')
MIN_AREA = 300

# 이름 -> (배치, 칸 순서대로 저장 이름). 배치: '2x2' 왼위·오위·왼아·오아 / '1x3' 왼·가운데·오 / '1' 낱장.
# 같은 그림의 낱장이 따로 있으면(정수·재굴림·필터 판·역할·팀 오라) 낱장이 이긴다(해상도가 크다) — 시트 몫은 None.
JOBS = {
    'sheet_train_1': ('2x2', ['train_attack', 'train_defense', 'train_hp', 'train_push']),
    'sheet_train_2': ('2x2', ['train_evade', 'train_crit', 'train_recovery', 'train_weight']),
    'sheet_train_3': ('2x2', ['train_tech', 'train_grit', 'train_command', None]),
    'sheet_roles': ('1x3', [None, None, None]),
    'sheet_items_1': ('2x2', [None, 'potion', 'stone_element', 'stone_temperament']),
    'sheet_items_2': ('2x2', ['duel_ticket', 'combat_power', 'boost', 'injury']),
    'sheet_buttons': ('2x2', ['breeding', 'incubator', None, 'boss_challenge']),
    # 입상(오른쪽 아래)은 금메달 같아 낱장(badge_finalist)으로 다시 그렸다.
    'sheet_badges': ('2x2', ['badge_champion', 'badge_silver', 'badge_bronze', None]),
    'sheet_marks_1': ('2x2', ['dex_crown', 'variant_shiny', 'equip_star', 'max_grade']),
    'sheet_marks_2': ('1x3', ['breakthrough', 'growth', 'star_up']),
    'sheet_tiles': ('1x3', [None, 'forge_grade', 'forge_auto']),
    'essence': ('1', ['essence']),
    'passive_reroll': ('1', ['passive_reroll']),
    'filter_tile': ('1', ['filter_tile']),
    'role_attack': ('1', ['role_attack']),
    'role_defense': ('1', ['role_defense']),
    'role_hp': ('1', ['role_hp']),
    'team_aura': ('1', ['team_aura']),
    'badge_finalist': ('1', ['badge_finalist']),
    'roadmap_boss_frame': ('1', ['roadmap_boss_frame']),
}

CENTERS = {
    '2x2': [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)],  # (x, y)
    '1x3': [(1 / 6, None), (0.5, None), (5 / 6, None)],               # y 는 안 본다
    '1': [(0.5, 0.5)],
}


def _erase_logo(a, bg):
    h, w, _ = a.shape
    y0, y1 = int(h * 0.83), int(h * 0.93)
    x0, x1 = int(w * 0.83), int(w * 0.93)
    box = a[y0:y1, x0:x1]
    light = (box > (bg[None, None, :] + 10)).all(2)
    box[light] = bg
    a[y0:y1, x0:x1] = box


def _cells(path, layout):
    im = Image.open(path).convert('RGB')
    a = np.asarray(im).astype(np.float32).copy()
    h, w, _ = a.shape
    bg, _, _, _ = base._masks(a)
    _erase_logo(a, bg)
    bg, bglike, k, resid = base._masks(a)
    lab, n = ndimage.label(~bglike)
    centers = CENTERS[layout]
    blobs = []
    for i in range(1, n + 1):
        m = lab == i
        area = int(m.sum())
        if area < MIN_AREA:
            continue
        ys, xs = np.nonzero(m)
        blobs.append([ys.min(), ys.max(), xs.min(), xs.max(), area, xs.mean() / w, ys.mean() / h])
    # 가장 큰 덩어리 N 개를 닻으로 — 부스러기(나무 조각 등)는 **가장 가까운 닻**에 붙인다.
    # 칸 중심 거리로 바로 배정하면 옆 아이콘의 파편이 엉뚱한 칸으로 가서 상자를 키웠다(돌파 조각 → 성장 칸).
    blobs.sort(key=lambda b: -b[4])
    anchors = blobs[:len(centers)]
    groups = [[a] for a in anchors]
    for b in blobs[len(centers):]:
        def gap(a):
            dx = max(a[2] - b[3], b[2] - a[3], 0)
            dy = max(a[0] - b[1], b[0] - a[1], 0)
            return dx * dx + dy * dy
        gi = min(range(len(anchors)), key=lambda j: gap(anchors[j]))
        groups[gi].append(b)

    def dist(c, g):
        cx, cy = g[0][5], g[0][6]
        dx = cx - c[0]
        dy = 0 if c[1] is None else cy - c[1]
        return dx * dx + dy * dy

    boxes = {}
    free = list(range(len(groups)))
    for ci, c in enumerate(centers):
        if not free:
            break
        gi = min(free, key=lambda j: dist(c, groups[j]))
        free.remove(gi)
        g = groups[gi]
        boxes[ci] = (min(x[0] for x in g), max(x[1] for x in g),
                     min(x[2] for x in g), max(x[3] for x in g), sum(x[4] for x in g))
    return a, bg, bglike, k, resid, boxes


def run(name, check):
    layout, names = JOBS[name]
    path = os.path.join(SRC, name + '.jpg')
    if not os.path.exists(path):
        path = os.path.join(SRC, name + '.png')
    if not os.path.exists(path):
        print('%-20s 파일 없음' % name)
        return
    a, bg, bglike, k, resid, boxes = _cells(path, layout)
    print('%-20s 칸 %d개 찾음 / 기대 %d' % (name, len(boxes), len(names)))
    if len(boxes) != len(names):
        print('    ⚠️ 개수가 다르다 — 자르지 않는다')
        return
    if check:
        return
    os.makedirs(OUT, exist_ok=True)
    for idx, out in enumerate(names):
        if out is None:
            continue
        y0, y1, x0, x1, _ = boxes[idx]
        # 화면에서 최대 64논리px(3배 기기 192px)라 256(테두리 틀은 칸이 커서 384)이면 넉넉하다.
        # 무손실 514px 로 두면 42장이 4.6MB 였다 — 기존 아이콘(15~45KB)처럼 손실 압축.
        side = 384 if out == 'roadmap_boss_frame' else 256
        img = base.cut_cell(a, bg, bglike, k, resid, (y0, y1, x0, x1), target=side)
        dst = os.path.join(OUT, out + '.webp')
        img.save(dst, 'WEBP', quality=88, alpha_quality=100, method=6)
        print('    -> %-26s %dx%d %4.0f KB' % (out + '.webp', img.width, img.height, os.path.getsize(dst) / 1024))


if __name__ == '__main__':
    check = '--check' in sys.argv
    only = [x for x in sys.argv[1:] if not x.startswith('--')]
    for nm in (only or list(JOBS)):
        run(nm, check)
