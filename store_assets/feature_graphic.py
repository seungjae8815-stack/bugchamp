"""Play 그래픽 이미지(1024x500) — 결투 원화 오른쪽 + 왼쪽 제목·부제·뱃지."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from poster_store_shots import *  # 같은 폴더의 포스터 스크립트

TAG = {
    'ko': ('곤충 키우기', '장수풍뎅이 vs 사슴벌레', '진짜 곤충 스모!', ['광고 없음', '방치 8시간']),
    'ja': ('昆虫チャンプ', 'カブトムシ vs クワガタ', '本気の虫相撲！', ['広告なし', '放置8時間']),
    'en': ('Bug Champ', 'Rhino vs Stag', 'Real Bug Sumo!', ['No Ads', '8h Idle']),
}

def feature(lang, title=None):
    w, h = 1024, 500
    art = Image.open(CLASH).convert('RGB').crop((0, 60, 2048, 1900))
    c = cover(art, w, h, 0.62, 0.3)
    c = ImageEnhance.Color(c).enhance(1.1)
    # 왼쪽을 어둡게(글씨 자리)
    m = Image.new('L', (w, 1))
    for x in range(w):
        t = x / w
        m.putpixel((x, 0), int(235 * max(0, 1 - t / 0.55) ** 1.2))
    c = Image.composite(Image.new('RGB', (w, h), (10, 14, 6)), c, m.resize((w, h)))
    t_, l1, l2, badges = TAG[lang]
    t_ = title or t_
    cx = w * 0.27
    f = fit(FONT[lang][0], t_, w * 0.48, 92)
    fx_text(c, cx, h * 0.12, t_, FONT[lang][0], f.size, GOLD)
    y = h * 0.12 + f.size * 1.2
    for line, col in ((l1, CREAM), (l2, CREAM)):
        f2 = fit(FONT[lang][0], line, w * 0.48, 44)
        fx_text(c, cx, y, line, FONT[lang][0], f2.size, col, ow=0.09)
        y += f2.size * 1.2
    # 뱃지(왼쪽 영역 가운데)
    size = 24
    fb = font(FONT[lang][1], size)
    ws = [fb.getlength(b) + size * 1.2 for b in badges]
    gap = 12
    x = cx - (sum(ws) + gap * (len(ws) - 1)) / 2
    for bw_, b in zip(ws, badges):
        pill(c, x + bw_ / 2, h * 0.86, b, lang, size)
        x += bw_ + gap
    return c

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for lang in ('ko', 'ja', 'en'):
        feature(lang).save(os.path.join(out, f'feature_{lang}.png'))
