"""스토어 스크린샷 합성 — 위쪽 문구 + 아래 게임 화면(둥근 모서리·금테).

사용: python compose_store_shots.py <shots 폴더> <출력 폴더>
Play(1080x1920)와 App Store 6.7"(1290x2796) 두 크기를 만든다.

- shots 폴더: 가상 폰(bugchamp_cap)에서 찍은 1080x2400 원본. 파일명 = SETS 의 첫 칸(ko_duel_hit.png 등).
  2026-10-15 원본·완성본: C:\\Users\\Lenovo\\Pictures\\BugChamp_store_2026-10-15
- 글꼴: 한국어 = 앱의 Jua. 일본어·영어 = M PLUS Rounded 1c(Black·ExtraBold, OFL — 상업 사용 가능)를
  Google Fonts 에서 받아 이 파일 옆 fonts/ 에 둔다(저장소에는 넣지 않음, 7MB).
- ⚠️ Jua 에는 가운뎃점(·)이 없다 — 한국어 문구에 쓰면 네모로 깨진다.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SHOTS, OUT = sys.argv[1], sys.argv[2]
FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fonts')
KO_FONT = r'C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\fonts\Jua-Regular.ttf'
JA_FONT = os.path.join(FONTS, 'MPLUSRounded1c-Black.ttf')
JA_SUB = os.path.join(FONTS, 'MPLUSRounded1c-ExtraBold.ttf')

# (파일, 화면에서 쓸 세로 구간(원본 px), 제목, 부제)
SETS = {
    'ko': [
        ('ko_duel_hit', [(120, 380), (860, 2160)], '밀어내고! 뒤집고!', '장수풍뎅이 vs 사슴벌레, 진짜 곤충 스모'),
        ('ko_duel_clutch', [(120, 380), (470, 2160)], '위기엔 연타로 버텨라', '탭 반격으로 짜릿한 대역전'),
        ('ko_hunt', (130, 2330), '꺼 둬도 곤충이 모여요', '방치해도 최대 8시간 보상'),
        ('ko_storage', (130, 2330), '20종 곤충 컬렉션', '일반부터 전설까지 모아 보세요'),
        ('ko_detail', (130, 2330), '같은 종도 한 마리씩 달라요', '크기, 능력치, 기질이 다른 나만의 곤충'),
        ('ko_league', (130, 1215), '3마리 팀으로 주간 리그', '광고 없이 실력으로 다이아까지'),
    ],
    'ja': [
        ('ja_duel_hit', [(120, 380), (860, 2160)], '押し出せ！ひっくり返せ！', 'カブトムシ vs クワガタ 本気の虫相撲'),
        ('ja_duel_clutch', [(120, 380), (470, 2160)], 'ピンチは連打で踏ん張れ', 'タップ反撃で大逆転'),
        ('ja_hunt', (130, 2330), '放置でも虫が集まる', 'アプリを閉じても最大8時間'),
        ('ja_storage', (130, 2330), '20種の虫をコレクション', '一般から伝説まで集めよう'),
        ('ja_detail', (130, 2330), '同じ種でも一匹ずつ違う', 'サイズ・能力・気質、自分だけの一匹'),
        ('ja_league', (130, 1215), '3匹のチームで週間リーグ', 'ブロンズからダイヤを目指せ'),
        ('ja_title', (110, 2040), '広告なしで遊べる', '虫相撲 × 放置育成'),
    ],
    'en': [
        ('en_duel_hit', [(120, 380), (860, 2160)], "Push 'em out! Flip 'em over!", 'Rhino beetle vs stag beetle: real bug sumo'),
        ('en_duel_clutch', [(120, 380), (470, 2160)], 'Mash to hold on!', 'Tap counter for an epic comeback'),
        ('en_hunt', (130, 2330), "Bugs gather while you're away", 'Up to 8 hours of idle rewards'),
        ('en_storage', (130, 2330), 'Collect 20 species', 'From Common all the way to Legendary'),
        ('en_detail', (130, 2330), 'No two bugs are alike', 'Unique size, stats and temperament'),
        ('en_league', (130, 1215), 'Weekly 3-bug team league', 'No ads. Just skill.'),
    ],
}

SIZES = {'play': (1080, 1920), 'appstore': (1290, 2796)}

GOLD = (233, 176, 74)
CREAM = (255, 236, 176)
SUBC = (226, 220, 200)


def background(w, h):
    """짙은 숲색 세로 그라데이션 + 위쪽 은은한 빛."""
    bg = Image.new('RGB', (w, h))
    top, bot = (38, 54, 26), (12, 18, 10)
    px = ImageDraw.Draw(bg)
    for y in range(h):
        t = y / (h - 1)
        px.line([(0, y), (w, y)], fill=tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
    glow = Image.new('L', (w, h), 0)
    ImageDraw.Draw(glow).ellipse([-w * 0.2, -h * 0.12, w * 1.2, h * 0.3], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.12))
    bg = Image.composite(Image.new('RGB', (w, h), (120, 110, 50)), bg, glow.point(lambda v: int(v * 0.5)))
    return bg


def fit_font(path, text, max_w, size):
    while size > 20:
        f = ImageFont.truetype(path, size)
        if f.getlength(text) <= max_w:
            return f
        size -= 2
    return ImageFont.truetype(path, size)


def compose(lang, name, crop, title, sub, w, h):
    canvas = background(w, h)
    d = ImageDraw.Draw(canvas)
    title_font = KO_FONT if lang == 'ko' else JA_FONT
    sub_font = KO_FONT if lang == 'ko' else JA_SUB

    cap_h = int(h * 0.19)
    tf = fit_font(title_font, title, w * 0.9, int(w * 0.088))
    sf = fit_font(sub_font, sub, w * 0.9, int(w * 0.047))
    ty = int(cap_h * 0.30)
    # 제목: 그림자 + 크림색
    for dx, dy in ((0, 5), (2, 6)):
        d.text((w / 2 + dx, ty + dy), title, font=tf, fill=(0, 0, 0), anchor='mm')
    d.text((w / 2, ty), title, font=tf, fill=CREAM, anchor='mm')
    d.text((w / 2, ty + tf.size * 0.95 + sf.size * 0.4), sub, font=sf, fill=SUBC, anchor='mm')

    # 게임 화면: 지정 구간을 잘라 남은 칸에 맞춘다
    src = Image.open(os.path.join(SHOTS, name + '.png')).convert('RGB')
    # 구간 하나 또는 여러 개(위아래로 이어 붙임 — 결투 화면의 빈 가운데를 뺀다)
    parts = [crop] if isinstance(crop, tuple) else crop
    pieces = [src.crop((0, a, src.width, b)) for a, b in parts]
    shot = Image.new('RGB', (src.width, sum(p.height for p in pieces)))
    yy = 0
    for p in pieces:
        shot.paste(p, (0, yy)); yy += p.height
    box_w, box_h = int(w * 0.86), int(h - cap_h - h * 0.035)
    scale = min(box_w / shot.width, box_h / shot.height)
    sw, sh = int(shot.width * scale), int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    x, y = (w - sw) // 2, cap_h + (box_h - sh) // 2
    r = int(w * 0.04)
    # 그림자
    shadow = Image.new('L', (w, h), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([x, y + 12, x + sw, y + sh + 12], r, fill=170)
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas = Image.composite(Image.new('RGB', (w, h), (0, 0, 0)), canvas, shadow)
    # 금테 + 둥근 모서리 화면
    bw = max(5, w // 180)
    ImageDraw.Draw(canvas).rounded_rectangle([x - bw, y - bw, x + sw + bw, y + sh + bw], r + bw, fill=GOLD)
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], r, fill=255)
    canvas.paste(shot, (x, y), mask)
    return canvas


for lang, items in SETS.items():
    for kind, (w, h) in SIZES.items():
        folder = os.path.join(OUT, f'{lang}_{kind}')
        os.makedirs(folder, exist_ok=True)
        for i, (name, crop, title, sub) in enumerate(items, 1):
            img = compose(lang, name, crop, title, sub, w, h)
            img.save(os.path.join(folder, f'{i:02d}_{name.split("_", 1)[1]}.png'), optimize=True)
        print(folder)
