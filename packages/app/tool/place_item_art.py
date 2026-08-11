"""생성한 장비 그림을 올바른 파일명으로 자동 배치한다.

파일명을 하나하나 손으로 바꾸면 80개 중 하나만 틀려도 **에러 없이 조용히**
아이콘으로 폴백한다(§6). 그래서 손으로 안 바꾸게 만든다.

쓰는 법
-------
    # 1) 어떤 순서로 뽑아야 하는지 확인
    python tool/place_item_art.py --list

    # 2) 그 순서대로 만든 그림을 아무 폴더에 01, 02, ... 로 저장한 뒤
    python tool/place_item_art.py --from C:/art --dry     # 먼저 확인만
    python tool/place_item_art.py --from C:/art           # 실제 배치

    # 부위 하나만 먼저 할 수도 있다(권장 — 채집도구 10개부터)
    python tool/place_item_art.py --from C:/art --slot tool

정렬 기준은 **파일 이름순**이다. `01.png … 10.png` 처럼 자리수를 맞춰야
10 이 2 앞으로 가지 않는다.

투명 배경을 유지한 채 256×256 webp 로 변환해 넣는다.
"""

import argparse
import os
import sys

# 윈도우 콘솔(cp949)에서 한글·기호가 깨지거나 죽지 않게.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SLOTS = ["tool", "hat", "top", "bottom", "shoes", "necklace", "ring", "box"]
SLOT_KO = {
    "tool": "채집도구", "hat": "모자", "top": "상의", "bottom": "하의",
    "shoes": "신발", "necklace": "목걸이", "ring": "반지", "box": "채집함",
}
TIERS = ["grass", "wood", "leather", "copper", "iron",
         "silver", "gold", "chitin", "carapace", "amber"]
TIER_KO = ["풀잎", "나무", "가죽", "구리", "무쇠", "은", "황금", "키틴", "갑충", "호박"]

DEST = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "items")
EXTS = (".png", ".webp", ".jpg", ".jpeg")
SIZE = 256


def targets(slot=None):
    """배치될 파일명을 문서와 **같은 순서**로 돌려준다."""
    slots = [slot] if slot else SLOTS
    out = []
    for s in slots:
        for i, t in enumerate(TIERS):
            out.append((f"{s}_{t}", f"{SLOT_KO[s]} · {TIER_KO[i]}"))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", help="생성한 그림이 있는 폴더")
    ap.add_argument("--slot", choices=SLOTS, help="이 부위만 배치")
    ap.add_argument("--list", action="store_true", help="필요한 순서만 출력")
    ap.add_argument("--dry", action="store_true", help="옮기지 않고 계획만 출력")
    ap.add_argument("--no-cutout", action="store_true",
                    help="누끼(배경 제거)를 건너뛴다 — 이미 투명한 그림일 때")
    a = ap.parse_args()

    plan = targets(a.slot)

    if a.list or not a.src:
        print(f"필요한 순서 ({len(plan)}개) — 이 순서대로 01, 02, … 로 저장하세요\n")
        for i, (name, ko) in enumerate(plan, 1):
            print(f"  {i:2d}. {ko:<16} → {name}.webp")
        if not a.src:
            print("\n배치하려면: --from <폴더>")
        return

    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow 가 필요합니다:  pip install pillow")

    files = sorted(
        f for f in os.listdir(a.src) if f.lower().endswith(EXTS)
    )
    if not files:
        sys.exit(f"{a.src} 에 이미지가 없습니다")

    # 이미 올바른 이름(tool_amber.png 등)으로 저장했으면 **순서를 무시하고**
    # 이름으로 짝짓는다. 순서 짝짓기는 하나만 어긋나도 전부 밀리므로,
    # 이름이 맞으면 그쪽이 훨씬 안전하다.
    valid = {n for n, _ in targets()}
    named = [f for f in files if os.path.splitext(f)[0] in valid]
    if named:
        if len(named) != len(files):
            skipped = [f for f in files if f not in named]
            names = ", ".join(skipped[:5])
            print("⚠️ 이름이 안 맞는 파일 %d개는 건너뜁니다: %s"
                  % (len(skipped), names))
            print("")
        ko_of = dict(targets())
        pairs = [(f, (os.path.splitext(f)[0], ko_of[os.path.splitext(f)[0]]))
                 for f in named]
        _place(a, pairs)
        return

    if len(files) != len(plan):
        # 멈추지 않는다 — 부위 하나만 뽑아본 경우가 흔하다. 다만 짝이 어긋나면
        # **엉뚱한 이름으로 들어가므로** 반드시 눈으로 확인시킨다.
        print(f"⚠️ 파일 {len(files)}개 · 필요 {len(plan)}개 — 앞에서부터 짝을 맞춥니다.")
        print("   순서가 어긋나면 엉뚱한 이름으로 들어갑니다. --dry 로 먼저 확인하세요.\n")

    _place(a, list(zip(files, plan)))


def _light_checker(img):
    """배경을 **지워도 되는 그림**인가(스크린샷·사진이 아닌가)."""
    return bool(_background(img)[1])


def _background(img):
    """`(누끼를 뜰 이미지, 지울 배경 톤들, 액자색)`.

    톤이 비면 건드리면 안 되는 그림이다.

    생성기가 그림을 **단색 액자**에 넣어 주는 경우가 있다(하의 구리 = 검은
    여백 안에 흰 체크판 카드). 액자색이 테두리를 100% 덮으면 "체크판이 아님"
    으로 통째로 건너뛰므로, 그때만 액자를 잘라내고 한 번 더 본다.

    ⚠️ **먼저 자르면 안 된다.** 흰 여백이 넓은 그림(무쇠 집게)은 여백째
    잘려 테두리가 그림에 딱 붙고, 그러면 배경 톤을 못 찾는다.
    """
    tones = _checker_tones(img.convert("RGB").load(), *img.size)
    if tones:
        return img, tones, None
    inner, frame = _trim_frame(img)
    if frame is None:
        return img, [], None
    # 액자색은 표본에서 **뺀다**. 카드 모서리가 둥글면 잘라낸 뒤에도 테두리
    # 한 줄이 액자색으로 뒤덮여 있어(하의 구리: 100% 검정) 체크판을 못 본다.
    tones = _checker_tones(inner.convert("RGB").load(), *inner.size, ignore=frame)
    return inner, tones, frame


def _trim_frame(img):
    """단색 액자를 잘라낸 `(그림, 액자색)`. 액자가 없으면 `(원본, None)`.

    카드 모서리가 둥글면 잘라내고도 네 귀퉁이에 액자색이 남는다 — 그건
    `cutout` 이 테두리에서 이어진 액자색을 마저 지운다.
    """
    px = img.convert("RGB").load()
    w, h = img.size
    edge = list(_edge_pixels(px, w, h))
    base = edge[0]
    if sum(1 for p in edge if _near(p, base, 12)) < len(edge) * 0.98:
        return img, None

    # 액자색이 **아닌** 픽셀들의 외곽 상자. 줄 단위로 훑으면 둥근 모서리에서
    # 멈춰 액자가 잔뜩 남는다(하의 구리: 1024→766×875 에서 멈췄다).
    box = None
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if not _near(px[x, y], base, 20):
                box = (x, y, x, y) if box is None else (
                    min(box[0], x), min(box[1], y),
                    max(box[2], x), max(box[3], y))
    if box is None:
        return img, None
    left, top, right, bot = box
    if (top, left, bot, right) == (0, 0, h - 1, w - 1):
        return img, None
    return img.crop((left, top, right + 1, bot + 1)), base


def _near(p, q, tol):
    return all(abs(a - b) <= tol for a, b in zip(p, q))


def _checker_tones(px, w, h, ignore=None):
    """테두리에서 알아낸 **지워야 할 배경 톤들**. 아니면 빈 리스트.

    배경은 두 종류로 온다 —
      · **체크무늬**: 무채색 두 톤이 번갈아 나온다(대략 50:50).
      · **단색 카드**: 흰 배경 한 톤이 테두리를 거의 다 덮는다.

    ⚠️ 밝기만으로 판정하면 안 된다. 체크판 톤이 생성기마다 크게 다르다 —
    흰색(255/240) · 회색(213/193) · **중간 회색(151/122)** 까지 봤다.
    밝기 기준(>170)을 두면 어두운 체크판이 통째로 안 지워진다(실제로 그랬다).

    ⚠️ 반대로 밝기를 완전히 버리면 **어두운 스크린샷**이 배경으로 오인된다.
    그래서 어두운 배경은 "두 톤이 번갈아 나올 때"(= 체크판이 확실할 때)만
    인정한다. 단색 어두운 테두리는 지우지 않는다.
    """
    from collections import Counter

    c = Counter()
    total = 0
    for p in _edge_pixels(px, w, h):
        if ignore is not None and _near(p, ignore, 20):
            continue  # 액자색 — 표본이 아니다
        total += 1
        if max(p) - min(p) < 20:  # 무채색만
            c[min(p) // 6 * 6] += 1  # 6단위로 뭉쳐 노이즈를 흡수
    if not total or sum(c.values()) / total < 0.90:
        return []  # 테두리에 색이 섞였다 — 사진·스크린샷이다.

    major = [v for v, n in c.most_common(4) if n / total >= 0.10]
    if not major or (len(major) < 2 and max(major) <= 200):
        return []

    # 지울 톤은 **그림 전체**에서 다시 모은다. 테두리가 흰 칸(252)에만 걸리면
    # 안쪽의 체크칸(240)이 표본에 안 들어와 반투명하게 남는다 — 무쇠 집게에서
    # 실제로 그랬다(반투명 18%). 테두리는 "지워도 되는가"만 판정하고,
    # 실제 색은 전체에서 찾는다. 배경색과 40 이상 떨어진 무채색은 그림이다.
    top = c.most_common(1)[0][0]
    inner = Counter()
    n_inner = 0
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            p = px[x, y]
            n_inner += 1
            if max(p) - min(p) < 20 and abs(min(p) // 6 * 6 - top) <= 40:
                inner[min(p) // 6 * 6] += 1
    return [v for v, n in inner.items() if n / n_inner >= 0.01]


def _edge_pixels(px, w, h):
    """테두리 한 줄의 픽셀들 — 체크판 색을 알아내는 표본."""
    for x in range(0, w, 2):
        yield px[x, 1]
        yield px[x, h - 2]
    for y in range(0, h, 2):
        yield px[1, y]
        yield px[w - 2, y]


def cutout(img):
    """배경을 지워 진짜 투명으로 만든다(누끼).

    AI 는 "transparent background" 를 요구해도 **투명을 만들지 않고 체크무늬를
    그려넣는 경우가 많다**(실측: 완전투명 픽셀 0%, 모서리 알파 255). 그대로
    쓰면 게임에서 회색 체크판 사각형이 그대로 보인다.

    체크판 **색 구간(band)** 에 든 무채색 픽셀만 지운다. "이 밝기보다 밝으면
    배경" 으로 자르면 체크판이 어두울 때(회색 122/151) 그보다 밝은 **그림 속
    밝은 부분까지 뚫린다** — 실제로 배지·유리병이 뚫렸다.
    """
    from PIL import Image, ImageFilter

    # 1) 체크무늬가 **무슨 톤인지** 테두리에서 알아낸다(필요하면 액자를 벗긴다).
    #    밝기 하한을 두면 안 된다 — 흰색(255/240)·회색(213/193)·중간
    #    회색(151/122) 까지 봤다. 무채색 톤 분포로만 잡는다.
    img, tones, frame = _background(img)
    if not tones:
        return img  # 지울 배경이 아니다 — 건드리지 않는다.

    w, h = img.size
    px = img.convert("RGB").load()

    # 2) **전역**으로 지운다. 테두리에서 이어진 것만 지우면 닫힌 고리 안쪽
    #    (무쇠 집게·황금 고리의 구멍)에 체크무늬가 그대로 남는다 — 실제로 남았다.
    #
    # 3) 지우는 기준은 **체크판 색 구간 안인가**다. "이보다 밝으면 배경" 은 못
    #    쓴다 — 체크판이 회색(122/151)이면 그보다 밝은 배지·유리병까지 뚫린다.
    #    구간 바깥은 **부드러운 경사**로 되살린다. 딱 잘라내면 빛번짐(호박·황금)
    #    가장자리에 흰 테가 남는다. 채도가 있으면 그림 — 둘 중 강한 쪽을 쓴다.
    def ramp(v, lo, hi):
        if v <= lo:
            return 0
        if v >= hi:
            return 255
        return int((v - lo) * 255 / (hi - lo))

    # 체크판 두 칸의 톤을 모두 감싸는 구간. 흰 체크판이면 [240,252] 처럼
    # 좁고, 회색 체크판이면 [122,151] 처럼 아래에 있다.
    band_lo, band_hi = min(tones) - 4, max(tones) + 4
    # 되살아나는 폭. **위쪽은 좁게** — 회색 체크판(122/151)에서 폭을 넓게 잡으면
    # 밝은 카키(모자 챙)가 반투명해져 배경이 비친다(실제로 비쳤다).
    # 아래쪽은 어두운 그림과 배경 사이 안티에일리어싱이라 넉넉해야 테가 안 남는다.
    fade_dn, fade_up = 30, 10

    a = bytearray(w * h)
    i = 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            lum = min(r, g, b)
            sat = max(r, g, b) - lum
            # 구간보다 어둡거나 / 밝으면 그림. 채도가 있어도 그림.
            by_lum = max(
                255 - ramp(lum, band_lo - fade_dn, band_lo),
                ramp(lum, band_hi, band_hi + fade_up),
            )
            a[i] = max(by_lum, ramp(sat, 18, 34))
            i += 1

    # 둥근 카드 모서리에 남은 액자색을 마저 지운다. **테두리에서 이어진 것만**
    # — 그림 안의 검은 외곽선까지 지우면 아이템이 갉아먹힌다.
    if frame is not None:
        _erase_connected(a, px, w, h, frame)

    _eat_glow(a, px, w, h, band_lo)

    alpha = Image.frombytes("L", (w, h), bytes(a))
    # 계단을 없애는 정도로만 아주 살짝.
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.5))
    out = img.copy()
    out.putalpha(alpha)
    return out


def _eat_glow(a, px, w, h, band_lo, drop=50, limit=1.0):
    """아이템 둘레의 **하얀 발광**을 지운다.

    생성기가 스티커처럼 흰 후광을 그려 넣는 경우가 있다(채집도구 호박·하의
    호박·채집함 구리). 체크판 색 구간에는 안 들어가서 남고, 게임에서 흰 테로
    보인다. 후광은 **모든 채널이 밝고**(크림색) 바깥과 이어져 있다. 아이템
    색은 한 채널이라도 어두워서(구리 98 · 호박 120) 여기 안 걸리고, 검은
    외곽선에서 저절로 멈춘다.

    ⚠️ 밝은 아이템(은 갑옷·은 반지)도 같은 조건에 걸린다. 그래서 **바깥에서
    이어진 것만** 훑고, 지워질 양이 *그러고도 남는 그림*에 비해 `limit` 을
    넘으면 "후광이 아니라 아이템"으로 보고 통째로 되돌린다.
    ⚠️ 기준을 **그림 전체 넓이**로 잡으면 안 된다 — 작은 은반지는 통째로
    지워져도 전체의 8% 밖에 안 돼 그냥 통과한다.

    실측(원본 81장): 후광이 있는 4장만 크게 줄고(채집도구 호박 −36% · 채집함
    구리 −28% · 채집도구 황금 −23% · 하의 호박 −15%) 나머지는 −0.2% 안쪽이다.
    아이템마다 검은 외곽선이 그려져 있어 거기서 멈추기 때문이다.
    """
    from collections import deque

    lo = band_lo - drop
    seen = bytearray(w * h)
    hit = []
    q = deque()

    def push(x, y):
        i = y * w + x
        if seen[i]:
            return
        seen[i] = 1
        if a[i] == 0:  # 이미 배경
            q.append((x, y))
            return
        r, g, b = px[x, y]
        if min(r, g, b) >= lo:
            hit.append(i)
            q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)
    while q:
        x, y = q.popleft()
        if x > 0:
            push(x - 1, y)
        if x < w - 1:
            push(x + 1, y)
        if y > 0:
            push(x, y - 1)
        if y < h - 1:
            push(x, y + 1)

    kept = sum(1 for v in a if v > 128) - len(hit)
    if len(hit) > max(kept, 1) * limit:
        return 0  # 후광이 아니라 밝은 아이템이다 — 건드리지 않는다.
    for i in hit:
        a[i] = 0
    return len(hit)


def _erase_connected(a, px, w, h, color):
    """테두리에서 이어진 `color` 영역의 알파를 0으로 만든다(제자리 수정)."""
    from collections import deque

    seen = bytearray(w * h)
    q = deque()

    def push(x, y):
        i = y * w + x
        if not seen[i] and _near(px[x, y], color, 20):
            seen[i] = 1
            a[i] = 0
            q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)
    while q:
        x, y = q.popleft()
        if x > 0:
            push(x - 1, y)
        if x < w - 1:
            push(x + 1, y)
        if y > 0:
            push(x, y - 1)
        if y < h - 1:
            push(x, y + 1)


def _place(a, pairs):
    """(원본파일, (대상이름, 설명)) 짝을 실제로 배치한다."""
    from PIL import Image

    os.makedirs(DEST, exist_ok=True)
    for src_name, (name, ko) in pairs:
        dst = os.path.normpath(os.path.join(DEST, f"{name}.webp"))
        if a.dry:
            print(f"  {src_name:<24} → {name}.webp   ({ko})")
            continue
        img = Image.open(os.path.join(a.src, src_name)).convert("RGBA")

        # ⚠️ **스크린샷을 걸러낸다.** 생성 결과를 내려받지 않고 화면을 캡처하면
        # 배경이 어두운 체크판이 되고 UI 요소까지 같이 찍힌다. 게다가 아이템이
        # 넓은 캔버스의 일부라 확대하면 뭉개진다. 조용히 망치느니 건너뛴다.
        before = sum(1 for a2 in img.getchannel("A").getdata() if a2 < 10)
        if not a.no_cutout and before < img.width * img.height * 0.02:
            if not _light_checker(img):
                print(f"  {src_name:<24} ⏭  건너뜀 — 배경이 밝은 체크무늬가 아님"
                      f" ({img.width}×{img.height})")
                print("     생성기에서 **내려받기**로 저장하세요(화면 캡처 X).")
                continue
            img = cutout(img)
        after = sum(1 for a2 in img.getchannel("A").getdata() if a2 < 10)
        pct = after / (img.width * img.height) * 100
        note = "" if before or a.no_cutout else f"  누끼 {pct:.0f}%"
        print(f"  {src_name:<24} → {name}.webp   ({ko}){note}")
        if pct < 5 and not a.no_cutout:
            print("     ⚠️ 배경이 거의 안 지워졌습니다 — 눈으로 확인하세요.")

        # 비율을 유지한 채 정사각 캔버스 가운데에 놓는다 — 칸마다 크기가
        # 들쭉날쭉하면 격자로 늘어놨을 때 티가 난다.
        img.thumbnail((SIZE, SIZE), Image.LANCZOS)
        canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        canvas.paste(img, ((SIZE - img.width) // 2, (SIZE - img.height) // 2), img)
        canvas.save(dst, "WEBP", lossless=True)

    if a.dry:
        print("\n(--dry 라 실제로 옮기지 않았습니다)")
    else:
        print(f"\n완료 — {DEST} 에 배치했습니다. 앱에서 캐릭터 탭을 확인하세요.")


if __name__ == "__main__":
    main()
