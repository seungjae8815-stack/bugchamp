"""요정 추가 그림 10장(docs/art_prompts_fairy_fx.md) -> 투명 WebP.

쓰는 법(워크스페이스 루트에서):
    python tool/import_fairy_extra.py [원본 폴더] [미리보기.png]

- 도감·자동 합성 아이콘(fairy_dex · fairy_automerge) · 스킬 효과 8장(fx_<요정>)
- 배경 지우기·워터마크 제거는 tool/import_fairy_art.py 와 **같은 함수**(가장자리 flood fill · 디스필).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import import_fairy_art as base  # noqa: E402

from PIL import Image  # noqa: E402

SRC = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\Lenovo\Downloads\요정추가이미지'
PREVIEW = sys.argv[2] if len(sys.argv) > 2 else None
NAMES = ['fairy_dex', 'fairy_automerge'] + ['fx_%s' % k for k in base.KINDS]

if __name__ == '__main__':
    os.makedirs(base.OUT_FAIRY, exist_ok=True)
    shots = []
    for name in NAMES:
        img, wm = base.icon(os.path.join(SRC, name + '.jpg'),
                            os.path.join(base.OUT_FAIRY, name + '.webp'))
        print('%-16s (워터마크 %d픽셀 지움)' % (name, wm))
        shots.append(img)
    if PREVIEW:
        cell = 170
        prev = Image.new('RGB', (len(shots) * cell, cell * 2), (255, 255, 255))
        for i, s in enumerate(shots):
            t = s.resize((cell, cell), Image.LANCZOS)
            prev.paste(base.checker(t, True), (i * cell, 0))
            prev.paste(base.checker(t, False), (i * cell, cell))
        prev.save(PREVIEW)
