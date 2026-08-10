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
    """배경이 **밝은 체크무늬**인가 — 누끼를 뜰 수 있는 그림인가.

    생성기에서 내려받은 그림은 밝은 회색 체크판(235~255)이 깔린다.
    화면을 캡처하면 어두운 배경(0~120)에 UI 까지 찍혀 이 검사에 걸린다.
    """
    px = img.convert("RGB").load()
    w, h = img.size
    pts = [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2),
           (w // 2, 1), (w // 2, h - 2)]
    light = 0
    for x, y in pts:
        r, g, b = px[x, y]
        if min(r, g, b) > 195 and max(r, g, b) - min(r, g, b) < 20:
            light += 1
    return light >= 4


def cutout(img):
    """배경을 지워 진짜 투명으로 만든다(누끼).

    AI 는 "transparent background" 를 요구해도 **투명을 만들지 않고 체크무늬를
    그려넣는 경우가 많다**(실측: 완전투명 픽셀 0%, 모서리 알파 255). 그대로
    쓰면 게임에서 회색 체크판 사각형이 그대로 보인다.

    가장자리에서 **연결된 밝은 무채색 영역만** 지운다. 전체를 밝기로 자르면
    그물의 크림색 같은 **안쪽 밝은 부분까지 뚫린다** — 바깥에서 이어진 것만
    지워야 안전하다.
    """
    from collections import Counter

    from PIL import Image, ImageFilter

    w, h = img.size
    rgb = img.convert("RGB")
    px = rgb.load()

    # 1) 체크무늬가 **무슨 색인지** 테두리에서 알아낸다.
    #    실측: 흰색(255,255,255) 과 밝은 회색(240~244) 이 번갈아 칠해져 있다.
    edge = Counter()
    for x in range(0, w, 2):
        edge[px[x, 1]] += 1
        edge[px[x, h - 2]] += 1
    for y in range(0, h, 2):
        edge[px[1, y]] += 1
        edge[px[w - 2, y]] += 1
    bg_colors = [
        c for c, _ in edge.most_common(6)
        if max(c) - min(c) < 20 and min(c) > 195
    ]
    if not bg_colors:
        return img  # 배경이 밝은 무채색이 아니다 — 건드리지 않는다.

    # 2) **전역**으로 지운다. 테두리에서 이어진 것만 지우면 닫힌 고리 안쪽
    #    (무쇠 집게·황금 고리의 구멍)에 체크무늬가 그대로 남는다 — 실제로 남았다.
    #
    #    색을 정확히 맞추는 방식은 못 쓴다. 체크무늬가 흰색(255)과 회색(240)
    #    두 가지인데 좁은 허용치로는 한쪽만 잡혀 오히려 나빠졌다(무쇠 71%→56%).
    #    **"밝고 무채색"** 이라는 성질로 잡는 게 안정적이다(전 파일 73~80%).
    #
    # 3) 두 축 모두 **부드러운 경사**를 준다. 딱 잘라내면 빛번짐(호박·황금)이
    #    흰 테를 남긴다. 어둡거나 색이 있으면 아이템 — 둘 중 더 강한 쪽을 쓴다.
    def ramp(v, lo, hi):
        if v <= lo:
            return 0
        if v >= hi:
            return 255
        return int((v - lo) * 255 / (hi - lo))

    a = bytearray(w * h)
    i = 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            lum = min(r, g, b)
            sat = max(r, g, b) - lum
            # 어두울수록 아이템 / 채도가 있을수록 아이템.
            a[i] = max(255 - ramp(lum, 185, 208), ramp(sat, 18, 34))
            i += 1

    alpha = Image.frombytes("L", (w, h), bytes(a))
    # 계단을 없애는 정도로만 아주 살짝.
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.5))
    out = img.copy()
    out.putalpha(alpha)
    return out


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
