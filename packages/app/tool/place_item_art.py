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
    "tool": "채집도구", "hat": "모자", "top": "옷", "bottom": "바지",
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


def cutout(img):
    """배경을 지워 진짜 투명으로 만든다(누끼).

    AI 는 "transparent background" 를 요구해도 **투명을 만들지 않고 체크무늬를
    그려넣는 경우가 많다**(실측: 완전투명 픽셀 0%, 모서리 알파 255). 그대로
    쓰면 게임에서 회색 체크판 사각형이 그대로 보인다.

    가장자리에서 **연결된 밝은 무채색 영역만** 지운다. 전체를 밝기로 자르면
    그물의 크림색 같은 **안쪽 밝은 부분까지 뚫린다** — 바깥에서 이어진 것만
    지워야 안전하다.
    """
    from PIL import Image, ImageFilter

    w, h = img.size
    px = img.convert("RGB").load()

    def is_bg(x, y):
        r, g, b = px[x, y]
        # 체크무늬는 밝고 채도가 없다(235~250 회색). 아이템의 밝은 부분은
        # 대개 색이 살짝 있어(크림·베이지) 채도로 걸러진다.
        return max(r, g, b) - min(r, g, b) < 24 and min(r, g, b) > 195

    # 테두리에서 시작하는 플러드 필(반복문 — 재귀는 깊이 제한에 걸린다).
    mask = bytearray(w * h)
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(x, y):
                stack.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(x, y):
                stack.append((x, y))
    while stack:
        x, y = stack.pop()
        i = y * w + x
        if mask[i]:
            continue
        mask[i] = 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not mask[ny * w + nx] and is_bg(nx, ny):
                stack.append((nx, ny))

    alpha = Image.frombytes("L", (w, h), bytes(255 if not m else 0 for m in mask))
    # 가장자리를 아주 살짝 부드럽게 — 안 하면 계단이 보인다.
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))
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

        # 이미 투명한 그림이면 건드리지 않는다. 아니면 누끼를 딴다.
        before = sum(1 for a2 in img.getchannel("A").getdata() if a2 < 10)
        if not a.no_cutout and before < img.width * img.height * 0.02:
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
