"""스토어 스크린샷 v2 — 포스터형(원화·누끼·뱃지·큰 글씨).

사용: python poster_store_shots.py <언어 ko|ja|en|all> <크기 play|appstore|all> <출력 폴더> [장면 번호 01,02,...]

2026-10-15 판(사진 폴더 C:\\Users\\Lenovo\\Pictures\\BugChamp_store_2026-10-15\\v2_포스터형)을 만든 스크립트.
다시 쓸 때 준비물(이 파일 옆에 둔다):
- shots/ : 가상 폰 원본 1080x2400 — {ko,ja,en}_duel_hit · _duel_clutch · _detail · _hunt (같은 사진 폴더의 _원본캡처)
- fonts/ : BlackHanSans · LilitaOne · MPLUSRounded1c(Black·ExtraBold) — Google Fonts, 모두 OFL(상업 사용 가능)
- CLASH : 새 아이콘 원화 2048px(Gemini, 오른쪽 아래 로고는 잘라서 쓴다)
게임 그림(곤충 누끼·보스·타이틀·경기장)은 packages/app/assets/images 에서 바로 읽는다.
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
APP = r'C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app'
IMG = os.path.join(APP, 'assets', 'images')
SHOTS = os.path.join(HERE, 'shots')
F = os.path.join(HERE, 'fonts')
CLASH = r'C:\Users\Lenovo\Downloads\Gemini_Generated_Image_ytsk31ytsk31ytsk.png'

FONT = {
    'ko': (os.path.join(F, 'BlackHanSans-Regular.ttf'), os.path.join(APP, 'assets', 'fonts', 'Jua-Regular.ttf')),
    'ja': (os.path.join(F, 'MPLUSRounded1c-Black.ttf'), os.path.join(F, 'MPLUSRounded1c-ExtraBold.ttf')),
    'en': (os.path.join(F, 'LilitaOne-Regular.ttf'), os.path.join(F, 'MPLUSRounded1c-ExtraBold.ttf')),
}

GRADE_COLOR = {
    'common': (150, 156, 162), 'uncommon': (76, 175, 80), 'rare': (47, 128, 237),
    'epic': (155, 81, 224), 'legendary': (242, 169, 0),
}
GRADE_NAME = {
    'ko': {'common': '일반', 'uncommon': '고급', 'rare': '희귀', 'epic': '영웅', 'legendary': '전설'},
    'ja': {'common': '一般', 'uncommon': '高級', 'rare': 'レア', 'epic': '英雄', 'legendary': '伝説'},
    'en': {'common': 'Common', 'uncommon': 'Uncommon', 'rare': 'Rare', 'epic': 'Epic', 'legendary': 'Legendary'},
}

# ---- 문구 ------------------------------------------------------------------
TXT = {
    'ko': {
        'title': '곤충 키우기',
        'hero': ['장수풍뎅이 vs 사슴벌레', '진짜 곤충 스모!'],
        'badges': ['광고 없음', '방치 보상 8시간', '곤충 20종'],
        'duel': ['밀어내고!', '뒤집고!'], 'duel_sub': '위기엔 연타로 버텨라', 'clutch': '버텼다!',
        'col': ['20종 곤충', '전부 모아라'], 'col_sub': '일반부터 전설까지',
        'uniq': ['같은 종도', '한 마리씩 달라요'], 'uniq_sub': '크기, 능력치, 기질이 다른 나만의 곤충',
        'idle': ['꺼 둬도', '곤충이 모여요'], 'idle_badge': '최대 8시간 보상',
        'boss': ['보스 44마리', '끝없는 심연'], 'boss_sub': '매주 순위로 겨뤄요',
    },
    'ja': {
        'title': '昆虫チャンプ',
        'hero': ['カブトムシ vs クワガタ', '本気の虫相撲！'],
        'badges': ['広告なし', '放置8時間', '20種の虫'],
        'duel': ['押し出せ！', 'ひっくり返せ！'], 'duel_sub': 'ピンチは連打で踏ん張れ', 'clutch': '耐えた！',
        'col': ['20種の虫を', 'コンプリート'], 'col_sub': '一般から伝説まで',
        'uniq': ['同じ種でも', '一匹ずつ違う'], 'uniq_sub': 'サイズ・能力・気質、自分だけの一匹',
        'idle': ['放置でも', '虫が集まる'], 'idle_badge': '最大8時間分',
        'boss': ['ボス44体', '終わらない深淵'], 'boss_sub': '毎週ランキングで勝負',
    },
    'en': {
        'title': 'Bug Champ',
        'hero': ['Rhino vs Stag', 'Real Bug Sumo!'],
        'badges': ['No Ads', '8h Idle Rewards', '20 Species'],
        'duel': ['Push!', 'Flip! Win!'], 'duel_sub': 'Mash the screen to hold on', 'clutch': 'Held on!',
        'col': ['Collect', 'All 20 Bugs'], 'col_sub': 'From Common to Legendary',
        'uniq': ['No Two Bugs', 'Are Alike'], 'uniq_sub': 'Unique size, stats and temperament',
        'idle': ['Bugs Gather', 'While You Rest'], 'idle_badge': 'Up to 8h rewards',
        'boss': ['44 Bosses', 'Endless Abyss'], 'boss_sub': 'Weekly rankings',
    },
}

CREAM = (255, 244, 214)
GOLD = (255, 205, 72)
INK = (38, 22, 8)


# ---- 도구 ------------------------------------------------------------------
def font(path, size):
    return ImageFont.truetype(path, int(size))


def fit(path, text, max_w, size):
    while size > 16:
        f = font(path, size)
        if f.getlength(text) <= max_w:
            return f
        size -= 2
    return font(path, size)


def cover(im, w, h, cx=0.5, cy=0.5):
    """비율 유지해 꽉 채우고 (cx,cy) 기준으로 자른다."""
    s = max(w / im.width, h / im.height)
    im = im.resize((math.ceil(im.width * s), math.ceil(im.height * s)), Image.LANCZOS)
    x = int((im.width - w) * cx)
    y = int((im.height - h) * cy)
    return im.crop((x, y, x + w, y + h))


def vgrad(w, h, stops):
    """세로 그라데이션 알파 마스크(stops: [(위치0~1, 알파0~255)])."""
    m = Image.new('L', (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        for (p0, a0), (p1, a1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                k = (t - p0) / max(1e-6, p1 - p0)
                m.putpixel((0, y), int(a0 + (a1 - a0) * k))
                break
    return m.resize((w, h))


def darken(canvas, stops, color=(8, 12, 6)):
    w, h = canvas.size
    return Image.composite(Image.new('RGB', (w, h), color), canvas, vgrad(w, h, stops))


def fx_text(canvas, cx, top, text, path, size, fill, outline=INK, ow=0.08, shadow=True):
    """매끈한 외곽선 글자(2배로 그려 둥글게 부풀린 뒤 줄임) + 흐린 그림자. 반환: 글자 높이."""
    k = 2
    f = font(path, size * k)
    l, t, r, b = f.getbbox(text)
    o = int(f.size * ow)                      # 외곽선 두께(2배 기준)
    pad = o * 3 + 8
    W, H = r - l + pad * 2, b - t + pad * 2
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).text((pad - l, pad - t), text, font=f, fill=255)
    # 둥근 팽창: 흐리고 문턱 → 매끈한 외곽선
    ol = m.filter(ImageFilter.GaussianBlur(o * 0.55)).point(lambda v: 255 if v > 18 else 0)
    ol = ol.filter(ImageFilter.GaussianBlur(1.2))
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    layer.paste(Image.new('RGBA', (W, H), outline + (255,)), (0, 0), ol)
    layer.paste(Image.new('RGBA', (W, H), fill + (255,)), (0, 0), m)
    layer = layer.resize((W // k, H // k), Image.LANCZOS)
    x = int(cx - layer.width / 2)
    y = int(top - pad // k)
    if shadow:
        sh_a = ol.resize((W // k, H // k), Image.LANCZOS).filter(ImageFilter.GaussianBlur(size * 0.06))
        sh_a = sh_a.point(lambda v: int(v * 0.75))
        sh = Image.new('RGBA', sh_a.size, (0, 0, 0, 255))
        sh.putalpha(sh_a)
        canvas.paste(sh, (x + int(size * 0.03), y + int(size * 0.07)), sh)
    canvas.paste(layer, (x, y), layer)
    return (b - t) / k


def headline(canvas, lines, lang, top, w, size, colors=(CREAM, GOLD)):
    """굵은 외곽선 제목 여러 줄. 반환: 마지막 줄 아래 y."""
    path = FONT[lang][0]
    y = top
    for i, line in enumerate(lines):
        f = fit(path, line, w * 0.86, size)
        fx_text(canvas, w / 2, y, line, path, f.size, colors[i % len(colors)])
        y += f.size * 1.12
    return y


def subline(canvas, text, lang, y, w, size, fill=(240, 236, 220)):
    f = fit(FONT[lang][1], text, w * 0.88, size)
    fx_text(canvas, w / 2, y, text, FONT[lang][1], f.size, fill, outline=(0, 0, 0), ow=0.07)
    return y + f.size * 1.3


def pill(canvas, cx, cy, text, lang, size, bg=(255, 205, 72), fg=INK):
    d = ImageDraw.Draw(canvas)
    f = font(FONT[lang][1], size)
    tw = f.getlength(text)
    pw, ph = tw + size * 1.2, size * 1.7
    box = [cx - pw / 2, cy - ph / 2, cx + pw / 2, cy + ph / 2]
    d.rounded_rectangle([box[0] + 4, box[1] + 6, box[2] + 4, box[3] + 6], ph / 2, fill=(0, 0, 0))
    d.rounded_rectangle(box, ph / 2, fill=bg, outline=INK, width=int(max(3, size // 9)))
    d.text((cx, cy), text, font=f, fill=fg, anchor='mm')
    return pw


def pill_row(canvas, items, lang, cy, w, size, max_frac=0.94):
    """[(글자, 배경, 글자색)] 를 실제 너비로 재서 가로 가운데 정렬(넘치면 줄인다)."""
    while True:
        f = font(FONT[lang][1], size)
        ws = [f.getlength(t) + size * 1.2 for t, _, _ in items]
        gap = size * 0.45
        if sum(ws) + gap * (len(ws) - 1) <= w * max_frac or size < 16:
            break
        size -= 1
    x = (w - sum(ws) - gap * (len(ws) - 1)) / 2
    for bw_, (t, bg, fg) in zip(ws, items):
        pill(canvas, x + bw_ / 2, cy, t, lang, size, bg=bg, fg=fg)
        x += bw_ + gap


def card(canvas, im, x, y, w, radius, border=(255, 205, 72), bw=8, angle=0, shadow=True, max_h=None):
    """사진 카드(둥근 모서리·테두리·그림자·기울기)를 (x,y) 왼쪽 위에 붙인다. max_h 면 아래를 잘라 맞춘다."""
    h = int(im.height * w / im.width)
    if max_h and h > max_h:
        im = im.crop((0, 0, im.width, int(im.height * max_h / h)))
        h = int(max_h)
    im = im.convert('RGB').resize((w, h), Image.LANCZOS)
    full = Image.new('RGBA', (w + bw * 2, h + bw * 2), (0, 0, 0, 0))
    ImageDraw.Draw(full).rounded_rectangle([0, 0, full.width - 1, full.height - 1], radius + bw, fill=border + (255,))
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius, fill=255)
    full.paste(im, (bw, bw), m)
    if angle:
        full = full.rotate(angle, resample=Image.BICUBIC, expand=True)
    if shadow:
        pad = 60
        a = Image.new('L', (full.width + pad * 2, full.height + pad * 2), 0)
        a.paste(full.split()[3].point(lambda v: int(v * 0.6)), (pad, pad))
        a = a.filter(ImageFilter.GaussianBlur(24))
        sh = Image.new('RGBA', a.size, (0, 0, 0, 255))
        sh.putalpha(a)
        canvas.paste(sh, (x + 10 - pad, y + 22 - pad), sh)
    canvas.paste(full, (x, y), full)
    return full.size


def glow(canvas, cx, cy, r, color, strength=200):
    g = Image.new('L', canvas.size, 0)
    ImageDraw.Draw(g).ellipse([cx - r, cy - r, cx + r, cy + r], fill=strength)
    g = g.filter(ImageFilter.GaussianBlur(r * 0.45))
    return Image.composite(Image.new('RGB', canvas.size, color), canvas, g)


def sprite(canvas, path, cx, cy, w, outline=True, dry=False):
    im = Image.open(path).convert('RGBA')
    a = im.split()[3].point(lambda v: 0 if v < 48 else v)
    im.putalpha(a)
    im = im.crop(a.getbbox())
    h = int(im.height * w / im.width)
    if dry:
        return h
    im = im.resize((int(w), h), Image.LANCZOS)
    if outline:
        # 그림자는 여백을 둔 판에서 흐린다 — 그림 크기 판에서 흐리면 가장자리에서 잘려 네모 선이 생겼다
        pad = 40
        a = Image.new('L', (im.width + pad * 2, im.height + pad * 2), 0)
        a.paste(im.split()[3].filter(ImageFilter.MaxFilter(5)), (pad, pad))
        a = a.point(lambda v: int(v * 0.55)).filter(ImageFilter.GaussianBlur(10))
        sh = Image.new('RGBA', a.size, (0, 0, 0, 255))
        sh.putalpha(a)
        canvas.paste(sh, (int(cx - w / 2) + 6 - pad, int(cy - h / 2) + 14 - pad), sh)
    canvas.paste(im, (int(cx - w / 2), int(cy - h / 2)), im)
    return h


def shot(name, y0, y1):
    im = Image.open(os.path.join(SHOTS, name + '.png')).convert('RGB')
    return im.crop((0, y0, im.width, y1))


def species():
    d = json.load(open(os.path.join(APP, 'assets', 'data', 'species.json'), encoding='utf-8'))
    return d if isinstance(d, list) else d.get('species', d)


# ---- 장면 ------------------------------------------------------------------
def s1_hero(lang, w, h):
    art = Image.open(CLASH).convert('RGB').crop((0, 0, 2048, 1900))  # 오른쪽 아래 로고 빼기
    c = cover(art, w, h, 0.5, 0.45)
    c = ImageEnhance.Color(c).enhance(1.12)
    c = darken(c, [(0, 215), (0.28, 120), (0.45, 0), (0.72, 0), (1, 235)])
    t = TXT[lang]
    y = headline(c, [t['title']], lang, h * 0.045, w, w * 0.15, colors=(GOLD,))
    y = headline(c, t['hero'], lang, y + h * 0.01, w, w * 0.085, colors=(CREAM, CREAM))
    # 뱃지: 실제 너비를 재서 가로로 고르게(넘치면 글씨를 줄인다)
    size = w * 0.052
    while True:
        f = font(FONT[lang][1], size)
        ws = [f.getlength(b) + size * 1.2 for b in t['badges']]
        gap = size * 0.5
        if sum(ws) + gap * (len(ws) - 1) <= w * 0.94 or size < 20:
            break
        size -= 1
    x = (w - sum(ws) - gap * (len(ws) - 1)) / 2
    for bw_, b in zip(ws, t['badges']):
        pill(c, x + bw_ / 2, h * 0.915, b, lang, size)
        x += bw_ + gap
    return c


def s2_duel(lang, w, h):
    bg = cover(Image.open(os.path.join(IMG, 'duel', 'arena_wood_side.webp')).convert('RGB'), w, h)
    bg = bg.filter(ImageFilter.GaussianBlur(14))
    bg = ImageEnhance.Brightness(bg).enhance(0.55)
    t = TXT[lang]
    y = headline(bg, t['duel'], lang, h * 0.04, w, w * 0.13)
    y = subline(bg, t['duel_sub'], lang, y + h * 0.005, w, w * 0.05)
    hit = shot(f'{lang}_duel_hit', 900, 2150)
    top = y + h * 0.02
    avail = h * 0.975 - top
    cw = int(min(w * 0.92, avail * hit.width / hit.height))
    card(bg, hit, int((w - cw) / 2), int(top), cw, int(w * 0.04))
    cl = shot(f'{lang}_duel_clutch', 480, 1500)
    sw_ = int(w * 0.44)
    card(bg, cl, int(w * 0.53), int(h * 0.66), sw_, int(w * 0.03), border=(255, 120, 60), angle=-6)
    return bg


def s3_collection(lang, w, h):
    c = Image.new('RGB', (w, h), (20, 30, 16))
    c = glow(c, w / 2, h * 0.55, w * 0.7, (70, 90, 40), 160)
    t = TXT[lang]
    y = headline(c, t['col'], lang, h * 0.035, w, w * 0.12)
    y = subline(c, t['col_sub'], lang, y, w, w * 0.05)
    sp = sorted(species(), key=lambda s: ['common', 'uncommon', 'rare', 'epic', 'legendary'].index(s['grade']))
    cols, rows = 4, 5
    gx, gy = w * 0.05, y + h * 0.015
    gw = w - 2 * gx
    gh = h - gy - h * 0.03
    cw, ch = gw / cols, gh / rows
    inner_w = cw * 0.92 * 0.84
    name_size = cw * 0.11
    while name_size > 12 and max(font(FONT[lang][1], name_size).getlength(x['name'][lang]) for x in sp) > inner_w:
        name_size -= 1
    # 너무 작아지면(긴 영어 이름) 두 줄 허용 대신 각자 맞추되 상한을 둔다
    min_size = cw * 0.075
    for i, s in enumerate(sp[::-1]):  # 전설이 위에
        r, k = divmod(i, cols)
        x0, y0 = gx + k * cw + cw * 0.04, gy + r * ch + ch * 0.04
        x1, y1 = x0 + cw * 0.92, y0 + ch * 0.92
        col = GRADE_COLOR[s['grade']]
        d = ImageDraw.Draw(c)
        d.rounded_rectangle([x0 + 4, y0 + 8, x1 + 4, y1 + 8], cw * 0.1, fill=(0, 0, 0))
        top = tuple(min(255, int(v * 0.95)) for v in col)
        inner = Image.new('RGB', (int(x1 - x0), int(y1 - y0)), top)
        inner = Image.composite(Image.new('RGB', inner.size, (25, 25, 25)), inner,
                                vgrad(inner.width, inner.height, [(0, 0), (1, 170)]))
        m = Image.new('L', inner.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, inner.width - 1, inner.height - 1], cw * 0.1, fill=255)
        c.paste(inner, (int(x0), int(y0)), m)
        d = ImageDraw.Draw(c)
        d.rounded_rectangle([x0, y0, x1, y1], cw * 0.1, outline=(255, 236, 160) if s['grade'] == 'legendary' else (240, 240, 240),
                            width=int(max(3, cw * 0.025)))
        img = s.get('image')
        p = os.path.join(APP, img) if img and os.path.exists(os.path.join(APP, img)) else os.path.join(IMG, 'bugs', s['id'] + '_adult.webp')
        if not os.path.exists(p):
            p = os.path.join(IMG, 'bugs', s['id'] + '_adult.webp')
        if os.path.exists(p):
            sprite(c, p, (x0 + x1) / 2, y0 + (y1 - y0) * 0.43, (x1 - x0) * 0.86)
        name = s['name'][lang]
        size_ = max(name_size, min_size)
        nf2 = fit(FONT[lang][1], name, inner_w, size_)
        d = ImageDraw.Draw(c)
        lines = [name]
        if nf2.getlength(name) > inner_w and ' ' in name:
            k = name.rfind(' ', 0, len(name) // 2 + 4) if name.rfind(' ', 0, len(name) // 2 + 4) > 0 else name.find(' ')
            lines = [name[:k], name[k + 1:]]
            nf2 = font(FONT[lang][1], size_)
            for ln in lines:
                nf2 = fit(FONT[lang][1], ln, inner_w, min(nf2.size, size_))
        ly = y1 - ch * (0.1 if len(lines) == 1 else 0.155)
        for ln in lines:
            d.text(((x0 + x1) / 2, ly), ln, font=nf2, fill='white', anchor='mm', stroke_width=3, stroke_fill=(0, 0, 0))
            ly += nf2.size * 1.05
    return c


def s4_unique(lang, w, h):
    c = Image.new('RGB', (w, h), (26, 20, 10))
    c = glow(c, w / 2, h * 0.36, w * 0.55, (255, 190, 60), 190)
    t = TXT[lang]
    y = headline(c, t['uniq'], lang, h * 0.035, w, w * 0.11)
    y = subline(c, t['uniq_sub'], lang, y, w, w * 0.045)
    bw_ = w * 0.66
    bh = sprite(c, os.path.join(IMG, 'bugs', 'longhorn_relict_adult.webp'), w / 2, -9999, bw_, dry=True)
    sprite(c, os.path.join(IMG, 'bugs', 'longhorn_relict_adult.webp'), w / 2, y + h * 0.015 + bh / 2, bw_)
    # 등급 사다리
    names = GRADE_NAME[lang]
    gy = y + h * 0.015 + bh + h * 0.035
    pill_row(c, [(names[g], GRADE_COLOR[g], (255, 255, 255)) for g in ['common', 'uncommon', 'rare', 'epic', 'legendary']],
             lang, gy, w, w * 0.042)
    det = shot(f'{lang}_detail', 160, 1480)
    top = gy + h * 0.045
    # 자르지 않고 통째로 줄여 넣는다(아래 끝이 글자 줄 한가운데서 잘렸다)
    cw = int(min(w * 0.86, (h * 0.97 - top) * det.width / det.height))
    card(c, det, int((w - cw) / 2), int(top), cw, int(w * 0.035))
    return c


def s5_idle(lang, w, h):
    bg = cover(Image.open(os.path.join(IMG, 'ui', 'title_bg.webp')).convert('RGB'), w, h, 0.5, 0.35)
    bg = darken(bg, [(0, 210), (0.25, 90), (0.5, 0), (1, 120)])
    t = TXT[lang]
    y = headline(bg, t['idle'], lang, h * 0.04, w, w * 0.12)
    pill(bg, w / 2, y + h * 0.03, t['idle_badge'], lang, w * 0.05)
    hunt = shot(f'{lang}_hunt', 130, 1395)
    top = h * 0.47
    # 기울인 카드가 화면 아래로 넘치지 않게(넘치면 글자 줄이 잘렸다) — 회전 여유 10%
    cw = int(min(w * 0.8, (h * 0.97 - top) / 1.1 * hunt.width / hunt.height))
    card(bg, hunt, int((w - cw) / 2 + w * 0.04), int(top), cw, int(w * 0.04), angle=4)
    return bg


def s6_boss(lang, w, h):
    bg = cover(Image.open(os.path.join(IMG, 'ui', 'abyss_banner.webp')).convert('RGB'), w, h, 0.5, 0.5)
    bg = ImageEnhance.Brightness(bg.filter(ImageFilter.GaussianBlur(6))).enhance(0.75)
    bg = darken(bg, [(0, 200), (0.3, 60), (0.7, 60), (1, 200)])
    t = TXT[lang]
    y = headline(bg, t['boss'], lang, h * 0.04, w, w * 0.12, colors=(GOLD, (190, 160, 255)))
    y = subline(bg, t['boss_sub'], lang, y, w, w * 0.05)
    b = os.path.join(IMG, 'bosses')
    bg = glow(bg, w / 2, h * 0.62, w * 0.5, (140, 90, 255), 120)
    sprite(bg, os.path.join(b, 'x_final.webp'), w * 0.5, y + (h * 0.73 - y) / 2, w * 0.82)
    for cx, name in ((0.18, 'e_final'), (0.5, 'n_final'), (0.82, 'h_final')):
        bg = glow(bg, w * cx, h * 0.85, w * 0.16, (120, 80, 220), 90)
        sprite(bg, os.path.join(b, name + '.webp'), w * cx, h * 0.85, w * 0.32)
    return bg


SCENES = [('01_hero', s1_hero), ('02_duel', s2_duel), ('03_collection', s3_collection),
          ('04_unique', s4_unique), ('05_idle', s5_idle), ('06_boss', s6_boss)]
SIZES = {'play': (1080, 1920), 'appstore': (1290, 2796)}

if __name__ == '__main__':
    langs = ['ko', 'ja', 'en'] if sys.argv[1] == 'all' else [sys.argv[1]]
    sizes = list(SIZES) if sys.argv[2] == 'all' else [sys.argv[2]]
    out = sys.argv[3]
    only = sys.argv[4].split(',') if len(sys.argv) > 4 else None
    for lang in langs:
        for kind in sizes:
            w, h = SIZES[kind]
            folder = os.path.join(out, f'{lang}_{kind}')
            os.makedirs(folder, exist_ok=True)
            for name, fn in SCENES:
                if only and name[:2] not in only:
                    continue
                fn(lang, w, h).convert('RGB').save(os.path.join(folder, name + '.png'), optimize=True)
            print(folder)
