"""오행 아이콘 5장을 누끼 따서 배치한다.

    python tool/place_element_art.py --from C:\\Users\\Lenovo\\Downloads

파일명은 **Element enum 이름 그대로**(`wood/fire/earth/metal/water.png`).

AI 는 "transparent background" 를 요구해도 **투명을 안 만들고 체크무늬를 그려 넣는다**
(실측: 완전투명 0%, 모서리 픽셀 223/248 회색). 그대로 넣으면 게임에서 회색 체크판
사각형이 보인다. `place_item_art.cutout` 이 그 무채색 체크판만 골라 지운다.

또 **정사각형으로 다시 맞춘다.** 생성기가 비율을 안 지켜서(목: 2816×1536) 그대로
쓰면 아이콘마다 크기가 달라 보인다 — 나란히 놓이는 자리라 이게 바로 티가 난다.
"""

import argparse
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.abspath(__file__))
UI = os.path.normpath(os.path.join(ROOT, "..", "assets", "images", "ui"))
# 세트 이름 → (enum 이름 목록, assets/images 아래 폴더)
SETS = {
    "element": (["wood", "fire", "earth", "metal", "water"], "element"),
    "temperament": (
        ["aggressive", "cautious", "cunning", "steadfast", "fickle"],
        "temperament",
    ),
    "stance": (["attack", "defend", "heal"], "stance"),
    "trait": (["fierce", "sturdy", "vital", "noble"], "trait"),
    "league": (
        ["bronze", "silver", "gold", "platinum", "diamond"],
        "league",
    ),
    "sex": (["male", "female"], "sex"),
}
SIZE = 256


def cutout(img):
    """체크무늬 배경을 지운다 — **테두리에서 이어진 것만**.

    `place_item_art.cutout` 은 "체크판 색 구간에 든 무채색 픽셀"을 전역으로 지운다.
    아이템 아이콘에는 맞지만 여기선 못 쓴다: 쇠(금) 아이콘은 **그림 자체가 무채색**
    이고 하이라이트가 흰색(250+)이라, 체크판 밝은 칸(253)과 구간이 겹쳐 너트가
    뚫린다(실측: 무채색 문턱 방식은 금·토·수 3장을 그대로 통과시켜 체크판이 남았다).

    오행 아이콘은 **테두리가 닫힌 단색 도형**이라 바깥에서 번져 들어가는 방식이
    안전하다 — 도형 안쪽은 테두리와 이어져 있지 않으니 절대 안 뚫린다.
    """
    import numpy as np
    from PIL import Image, ImageFilter
    from scipy import ndimage

    rgb = np.array(img.convert("RGB")).astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    gray = (abs(r - g) < 12) & (abs(g - b) < 12) & (abs(r - b) < 12)

    # 체크판 두 톤을 테두리에서 알아낸다(밝은 칸·어두운 칸).
    ring = np.concatenate(
        [rgb[:3].reshape(-1, 3), rgb[-3:].reshape(-1, 3),
         rgb[:, :3].reshape(-1, 3), rgb[:, -3:].reshape(-1, 3)]
    )
    ring = ring[(abs(ring[:, 0] - ring[:, 1]) < 12) & (abs(ring[:, 1] - ring[:, 2]) < 12)]
    if len(ring) == 0:
        return img  # 지울 배경이 아니다
    vals = ring.mean(axis=1)
    tones = (np.percentile(vals, 15), np.percentile(vals, 85))

    v = rgb.mean(axis=2)
    near = gray & (
        (abs(v - tones[0]) < 14) | (abs(v - tones[1]) < 14)
        | ((v > min(tones) - 4) & (v < max(tones) + 4))
    )
    # 테두리에 닿은 덩어리만 배경이다.
    lab, n = ndimage.label(near)
    edge = set(lab[0].tolist()) | set(lab[-1].tolist())
    edge |= set(lab[:, 0].tolist()) | set(lab[:, -1].tolist())
    edge.discard(0)
    if not edge:
        return img
    bg = np.isin(lab, list(edge))

    # 도형 **안에 갇힌** 체크판도 지운다(쇠 너트의 나사 구멍). 바깥과 안 이어져
    # 있어 위 단계로는 못 지운다. 다만 은색 너트 자체도 무채색이라 무턱대고
    # 지우면 너트가 뚫린다 — **두 톤이 섞여 있는 덩어리만** 체크판으로 본다.
    # 매끈한 금속 하이라이트는 한쪽 톤에만 쏠린다.
    lo, hi = min(tones), max(tones)
    # 체크무늬가 아니라 **민무늬 배경**인 경우도 있다(생성기마다 다르다). 그때는
    # 두 톤이 거의 같으므로 "반반" 판정이 성립하지 않는다 — 대신 **넓은** 덩어리만
    # 지운다(작은 건 그림 속 흰 하이라이트다).
    flat = hi - lo < 10
    area = rgb.shape[0] * rgb.shape[1]
    for i in range(1, n + 1):
        if i in edge:
            continue
        m = lab == i
        if m.sum() < 64:
            continue
        vv = v[m]
        if flat:
            if m.sum() >= area * 0.005 and abs(vv.mean() - (lo + hi) / 2) < 12:
                bg |= m
            continue
        share_lo = (vv < (lo + hi) / 2).mean()
        if 0.25 < share_lo < 0.75:  # 밝은 칸·어두운 칸이 반반 = 체크판
            bg |= m

    # ── 2차: 헤일로(발광) 제거 ───────────────────────────────────
    # 생성기가 아이콘 둘레에 **부드러운 빛**을 그려 넣으면 그 빛이 체크무늬와
    # 섞여, "정확히 체크판 색"이 아니게 되어 위 판정을 통과한다 → 화면에서는
    # **회색 후광**으로 보인다(실측: 회복 아이콘).
    #
    # 그래서 **더 느슨한 기준**으로 한 번 더 번져 들어간다. 여전히 바깥에서
    # 이어진 것만 지우므로, 그림의 진한 외곽선에서 멈춘다 — 색이 진한 부분은
    # 애초에 이 기준에 안 걸린다(회색기 + 체크판 밝기대 안이어야 한다).
    spread = rgb.max(axis=2) - rgb.min(axis=2)
    loose = (spread < 34) & (v > lo - 46) & (v < hi + 46)
    lab2, n2 = ndimage.label(loose | bg)
    if n2:
        edge2 = set(lab2[0].tolist()) | set(lab2[-1].tolist())
        edge2 |= set(lab2[:, 0].tolist()) | set(lab2[:, -1].tolist())
        edge2.discard(0)
        if edge2:
            bg |= np.isin(lab2, list(edge2)) & loose

    a = np.where(bg, 0, 255).astype("uint8")
    out = img.convert("RGBA")
    alpha = Image.fromarray(a)
    # 1px 침식 — 딱 잘라내면 가장자리에 밝은 테가 남는다(§4c 의 교훈).
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    out.putalpha(alpha)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", required=True)
    ap.add_argument("--set", dest="only", choices=sorted(SETS))
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    from PIL import Image

    for set_name in [a.only] if a.only else sorted(SETS):
        names, folder = SETS[set_name]
        dest = os.path.join(UI, folder)
        os.makedirs(dest, exist_ok=True)
        print(f"[{set_name}]")
        run(a, names, dest, Image)


def run(a, names, dest, Image):
    for n in names:
        src = os.path.join(a.src, n + ".png")
        if not os.path.exists(src):
            print(f"  {n:11s} 없음 — 그림 없이 폴백됩니다")
            continue
        img = cutout(Image.open(src).convert("RGBA"))
        box = img.getbbox()
        if box is None:
            print(f"  ! {n}: 다 지워졌습니다 — 체크무늬 판정을 확인하세요")
            continue
        img = img.crop(box)
        # 긴 변을 기준으로 맞춰야 5장이 같은 크기로 보인다.
        img.thumbnail((SIZE - 8, SIZE - 8), Image.LANCZOS)
        canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(
            img, ((SIZE - img.width) // 2, (SIZE - img.height) // 2)
        )
        print(f"  {n:8s} {box[2] - box[0]}x{box[3] - box[1]} → {SIZE}x{SIZE}")
        if not a.dry:
            canvas.save(os.path.join(dest, n + ".png"))
    if a.dry:
        print("\n(--dry 라 저장하지 않았습니다)")


if __name__ == "__main__":
    main()
