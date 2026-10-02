"""길드 그림 2장(docs/art_prompts_guild.md) -> 게임 애셋.

쓰는 법(워크스페이스 루트에서):
    python tool/import_guild_art.py [원본 폴더] [미리보기.png]

- nav_guild.jpg -> ui/nav/guild.webp(투명 아이콘 · 다른 하단 메뉴와 같은 가공)
- guild_coming_soon.jpg -> ui/guild_coming_soon.webp(배경 그림 · 오른쪽 아래 워터마크 지움)
배경 지우기·워터마크 제거는 tool/import_fairy_art.py 와 **같은 함수**.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import import_fairy_art as base  # noqa: E402

from PIL import Image  # noqa: E402

SRC = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\Lenovo\Downloads'
PREVIEW = sys.argv[2] if len(sys.argv) > 2 else None
UI = 'packages/app/assets/images/ui'

if __name__ == '__main__':
    img, wm = base.icon(os.path.join(SRC, 'nav_guild.jpg'), os.path.join(UI, 'nav', 'guild.webp'))
    print('nav_guild (워터마크 %d픽셀 지움)' % wm)
    # 워터마크를 칠해 지우면 흐린 네모가 남았다(2026-10-02 실기) — 아래 16% 띠를 잘라 통째로 뺀다.
    bg = Image.open(os.path.join(SRC, 'guild_coming_soon.jpg')).convert('RGB')
    bg = bg.crop((0, 0, bg.width, int(bg.height * 0.84)))
    bg.save(os.path.join(UI, 'guild_coming_soon.webp'), 'WEBP', quality=90)
    print('guild_coming_soon %s' % (bg.size,))
    if PREVIEW:
        cell = 200
        prev = Image.new('RGB', (cell * 4, cell), (255, 255, 255))
        t = img.resize((cell, cell), Image.LANCZOS)
        prev.paste(base.checker(t, True), (0, 0))
        prev.paste(base.checker(t, False), (cell, 0))
        bg = Image.open(os.path.join(UI, 'guild_coming_soon.webp')).convert('RGB')
        prev.paste(bg.resize((cell * 2, int(cell * 2 * bg.height / bg.width))).crop((0, 0, cell * 2, cell)), (cell * 2, 0))
        prev.save(PREVIEW)
