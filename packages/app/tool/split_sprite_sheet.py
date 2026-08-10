"""가로로 이어 그린 스프라이트 시트를 프레임별 파일로 자른다.

왜 시트로 뽑나
--------------
걷기 2프레임을 **따로** 뽑으면 같은 프롬프트·같은 레퍼런스를 줘도 옷·모자·비율이
미묘하게 달라진다(레퍼런스를 주면 아예 같은 그림을 복제해버리기도 한다).
그러면 번갈아 보여줄 때 **덜덜 떨린다.**

**한 장 안에** 두 자세를 나란히 그리게 하면 같은 붓질로 그려지므로 흔들림이 없다.
그걸 여기서 잘라 쓴다.

쓰는 법
-------
    python tool/split_sprite_sheet.py --from C:/art/walk_sheet.png --name walk --frames 2
    → assets/images/character/walk_1.webp , walk_2.webp

    # 확인만
    python tool/split_sprite_sheet.py --from ... --name walk --frames 2 --dry
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from place_item_art import cutout  # 누끼는 같은 로직을 쓴다

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

DEST = os.path.join(os.path.dirname(__file__), "..", "assets", "images")
SIZE = 512


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", required=True, help="시트 이미지")
    ap.add_argument("--name", required=True, help="상태 이름(walk / attack …)")
    ap.add_argument("--frames", type=int, default=2, help="가로 프레임 수")
    ap.add_argument("--sub", default="character", help="assets/images 아래 폴더")
    ap.add_argument("--size", type=int, default=SIZE)
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    from PIL import Image

    sheet = Image.open(a.src).convert("RGBA")
    w, h = sheet.size
    fw = w // a.frames
    if fw < 32:
        sys.exit(f"프레임이 너무 좁습니다({fw}px) — --frames 를 확인하세요")

    out_dir = os.path.normpath(os.path.join(DEST, a.sub))
    os.makedirs(out_dir, exist_ok=True)
    print(f"시트 {w}×{h} → 프레임 {a.frames}개 (각 {fw}×{h})\n")

    for i in range(a.frames):
        frame = sheet.crop((i * fw, 0, (i + 1) * fw, h))
        dst = os.path.join(out_dir, f"{a.name}_{i + 1}.webp")
        print(f"  프레임 {i + 1} → {a.sub}/{a.name}_{i + 1}.webp")
        if a.dry:
            continue
        if sum(1 for v in frame.getchannel("A").getdata() if v < 10) < fw * h * 0.02:
            frame = cutout(frame)

        # ⚠️ 프레임마다 따로 여백을 자르면 **캐릭터가 프레임마다 튄다.**
        # 시트 전체 기준으로 같은 자리에 놓아야 제자리걸음처럼 보인다.
        frame.thumbnail((a.size, a.size), Image.LANCZOS)
        canvas = Image.new("RGBA", (a.size, a.size), (0, 0, 0, 0))
        canvas.paste(
            frame,
            ((a.size - frame.width) // 2, a.size - frame.height),  # 발을 바닥에
            frame,
        )
        canvas.save(dst, "WEBP", lossless=True)

    if a.dry:
        print("\n(--dry 라 저장하지 않았습니다)")
    else:
        print(f"\n완료 — {out_dir}")


if __name__ == "__main__":
    main()
