"""길드 공개용 그림(docs/art_prompts_guild.md 3~47번) -> 게임 애셋 ui/guild/.

쓰는 법(워크스페이스 루트에서):
    python tool/import_guild_pack.py [원본 폴더] [미리보기.png]

- 파일명 앞의 `guild_` 를 떼고 넣는다(guild_rank_elite.jpg -> ui/guild/rank_elite.webp).
- 아이콘(문장·코인·보스·직책·등급·탭·일차·성장): 투명 514 정사각(import_fairy_art.icon 과 같은 가공).
- 가로 그림(mission_*·none): 아래 16% 띠를 잘라 워터마크째 뺀다(guild_coming_soon 과 같은 처리).
- 원본 폴더에 있는 것만 처리한다 — 나머지는 다음에 받은 뒤 다시 돌리면 된다.
배경 지우기 전에 아래 15% 를 먼저 잘라낸다(프롬프트가 그 띠를 비운 배경으로 그리게 한다 — 2026-10-05).
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
import import_fairy_art as base  # noqa: E402

from PIL import Image  # noqa: E402

SRC = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\Lenovo\Downloads\곤충만들기 길드'
PREVIEW = sys.argv[2] if len(sys.argv) > 2 else None
OUT = 'packages/app/assets/images/ui/guild'
WIDE = ('mission_', 'none')


def main():
    os.makedirs(OUT, exist_ok=True)
    done = []
    for f in sorted(os.listdir(SRC)):
        stem, ext = os.path.splitext(f)
        if ext.lower() not in ('.jpg', '.jpeg', '.png', '.webp') or not stem.startswith('guild_'):
            continue
        name = stem[len('guild_'):]
        src = Image.open(os.path.join(SRC, f)).convert('RGB')
        out = os.path.join(OUT, name + '.webp')
        if name.startswith(WIDE):
            bg = src.crop((0, 0, src.width, int(src.height * 0.84)))
            bg.save(out, 'WEBP', quality=86)
            done.append((name, False))
            print('%-16s 가로 %s' % (name, bg.size))
            continue
        cut = src.crop((0, 0, src.width, int(src.height * 0.85)))
        with tempfile.TemporaryDirectory() as td:
            tmp = os.path.join(td, 'cut.png')
            cut.save(tmp)
            _, wm = base.icon(tmp, out)
        done.append((name, True))
        print('%-16s 아이콘 (워터마크 %d픽셀 지움)' % (name, wm))
    if PREVIEW and done:
        cell, cols = 140, 8
        rows = (len(done) + cols - 1) // cols
        prev = Image.new('RGB', (cell * cols, cell * rows * 2), (255, 255, 255))
        for i, (name, is_icon) in enumerate(done):
            im = Image.open(os.path.join(OUT, name + '.webp')).convert('RGBA')
            im.thumbnail((cell, cell))
            x, y = (i % cols) * cell, (i // cols) * cell * 2
            for k, light in enumerate((True, False)):
                t = Image.new('RGBA', (cell, cell), (0, 0, 0, 0))
                t.paste(im, ((cell - im.width) // 2, (cell - im.height) // 2))
                prev.paste(base.checker(t, light) if is_icon else t.convert('RGB'), (x, y + k * cell))
        prev.save(PREVIEW)


if __name__ == '__main__':
    main()
