"""상점 상품 그림을 다운로드 폴더에서 가져와 애셋으로 넣는다.

생성기가 캔버스 **아래쪽에 워터마크 띠**를 붙여서 나온다. 프롬프트에서 그
자리를 "아무것도 없는 평평한 띠"로 비워두게 했으므로, 여기서는 그 띠만
기계적으로 잘라내면 된다 — 그림 본체는 손대지 않는다.

띠 판정은 **어둡고(평균<32) 균일한(표준편차<10) 행이 바닥부터 연속**되는
구간이다. 그림이 바닥까지 어두운 경우(무한버프 패스처럼)에도 띠는 거의 순수한
단색이라 표준편차로 갈린다.

⚠️ 정사각으로 억지로 맞추지 않는다. 카드가 `BoxFit.cover` 로 그리므로 2048x1930
(비율 1.06)이면 좌우 1.4px 만 잘린다 — 굳이 잘라서 젤리 항아리를 날릴 이유가 없다.

    cd packages/app ; python tool/place_shop_art.py
"""

import os

import numpy as np
from PIL import Image

SRC = os.path.join(os.path.expanduser('~'), 'Downloads')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'images', 'shop')

# iap.json 의 상품 id 와 같아야 한다 — 파일명이 곧 참조 키다.
IDS = ['starter_pack', 'idle_pass', 'buff_pass',
       'jelly_s', 'jelly_m', 'jelly_l', 'jelly_xl', 'jelly_xxl']

LONG_SIDE = 512  # 카드는 44px 지만 고해상도 기기·확대 팝업 여유를 둔다.


def strip_band(im):
    """바닥의 워터마크 띠를 잘라낸 이미지와 잘라낸 높이를 돌려준다."""
    a = np.asarray(im.convert('RGB'), dtype=np.float32)
    h = a.shape[0]
    cut = h
    for y in range(h - 1, -1, -1):
        row = a[y]
        if row.mean() < 32 and row.std() < 10:
            cut = y
        else:
            break
    # 띠가 화면의 30% 를 넘으면 판정 실패로 본다(어두운 그림을 통째로 날리는 사고).
    if (h - cut) / h > 0.30:
        raise SystemExit('띠 판정 실패: %d/%d 행이 어둡다' % (h - cut, h))
    return im.crop((0, 0, im.width, cut)), h - cut


def main():
    os.makedirs(OUT, exist_ok=True)
    missing = []
    for pid in IDS:
        src = os.path.join(SRC, pid + '.png')
        if not os.path.exists(src):
            missing.append(pid)
            continue
        im = Image.open(src)
        im, band = strip_band(im)
        k = LONG_SIDE / max(im.size)
        im = im.resize((round(im.width * k), round(im.height * k)),
                       Image.LANCZOS)
        dst = os.path.join(OUT, pid + '.webp')
        im.convert('RGB').save(dst, 'WEBP', quality=92)
        print('%-14s band %3dpx 제거 → %s %s'
              % (pid, band, im.size, os.path.basename(dst)))
    if missing:
        print('없음:', ', '.join(missing))


if __name__ == '__main__':
    main()
