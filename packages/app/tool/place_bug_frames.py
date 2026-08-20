"""곤충 전투 프레임 시트(가로 3칸)를 잘라 배치한다.

    python tool/place_bug_frames.py --from C:\\Users\\Lenovo\\Downloads --dry
    python tool/place_bug_frames.py --from C:\\Users\\Lenovo\\Downloads
    python tool/place_bug_frames.py --from ... --only stag_giant

파일명은 **종 id 그대로**(`stag_giant.png`). species.json 에 없는 이름이면 멈춘다 —
오타는 에러 없이 조용히 폴백되므로(§6) 여기서 잡아야 한다.

왜 split_sprite_sheet.py 를 안 쓰나
----------------------------------
그 도구는 캐릭터 걷기용이라 **정확히 1/N 로 자른다**. 곤충은 큰턱·더듬이가 옆 칸까지
뻗어서, 정확히 1/3 에서 자르면 **집게가 잘린다**(실측: 왕사슴벌레 대기 자세의 1/3
지점 알파합 6350 — 한복판이 큰턱). 그래서 여기서는 칸 사이 **빈 세로줄**을 찾아 자른다.

또 배경을 rembg 로 지운다. AI 가 "plain background" 를 요구해도 **바닥(이끼·흙)을
그려 넣기 때문에** 밝기 문턱으로는 못 지운다 — 갈색 곤충과 갈색 흙은 같은 색이다.
시트를 **통째로** 한 번에 지워야 한다. 칸을 먼저 자르고 지우면 벌어진 큰턱 안쪽에
배경색이 남는다(실측).

세 칸의 **크기와 발 높이를 맞추는 것**이 이 도구의 핵심이다. 칸마다 따로 맞추면
자세가 바뀔 때 곤충이 커졌다 작아졌다 하고 위아래로 튄다.
  · 배율   = 세 칸 공통 (제일 큰 칸에 맞춘다)
  · 발 높이 = 세 칸 공통 (제일 아래 픽셀)
  · 가로 기준 = **알파 무게중심** — 큰턱이 앞으로 뻗어도 몸통은 제자리에 있다.
    (칸의 좌우 중앙에 맞추면 큰턱이 벌어질 때 몸통이 뒤로 밀린다.)
"""

import argparse
import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# ⚠️ `assets/images/bugs/_raw_backup/` 은 **누끼 전 원본**이다. 복구원으로 쓰면
# 배경이 통째로 딸려 온다(실측 2026-08-19: 8종이 사각형 그림으로 나갔다).
# 대기컷을 되살릴 땐 이미 누끼된 `{종}_adult_1.webp` 를 잘라 쓸 것.
ROOT = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(ROOT, "..", "assets", "images", "bugs"))
SPECIES_JSON = os.path.normpath(
    os.path.join(ROOT, "..", "assets", "data", "species.json")
)
MAX_SIDE = 640  # 아레나에서 96pt(고밀도 288px)로 그린다 — 넉넉하되 과하지 않게


def species_ids():
    with open(SPECIES_JSON, encoding="utf-8") as f:
        d = json.load(f)
    rows = d if isinstance(d, list) else d.get("species", d)
    return [s["id"] for s in rows]


def split_columns(alpha, w, h, frames=3):
    """칸 사이의 **가장 빈 세로줄**을 찾아 자를 위치를 돌려준다."""
    px = alpha.load()
    # 세로로 4픽셀씩 건너뛰며 훑는다 — 골짜기를 찾는 데는 충분하고 훨씬 빠르다.
    cols = [sum(px[x, y] for y in range(0, h, 4)) for x in range(w)]
    cuts = [0]
    for i in range(1, frames):
        c = w * i / frames
        lo, hi = int(c - w / frames * 0.25), int(c + w / frames * 0.25)
        cuts.append(min(range(lo, hi), key=lambda x: cols[x]))
    cuts.append(w)
    return cuts


def drop_fragments(img, keep_ratio=0.10):
    """옆 칸에서 넘어온 **부스러기**를 지운다.

    빈 세로줄에서 잘라도 다리·더듬이 끝이 조금씩 걸친다. 그대로 두면 화면에
    정체불명의 검은 조각이 떠 있고, bbox 까지 넓혀 곤충이 작아진다.
    가장 큰 덩어리의 [keep_ratio] 보다 작은 덩어리는 곤충이 아니다.

    생성기가 구석에 찍는 **워터마크 글리프**도 여기서 걸러진다(2026-08-19).
    더듬이·다리는 몸에 붙어 있어 한 덩어리라 이 문턱에 걸리지 않는다.
    """
    import numpy as np
    from scipy import ndimage

    a = np.array(img.getchannel("A"))
    lab, n = ndimage.label(a > 8)
    if n <= 1:
        return img
    sizes = ndimage.sum(a > 8, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * keep_ratio])
    a[~keep] = 0
    from PIL import Image

    out = img.copy()
    out.putalpha(Image.fromarray(a))
    return out


def erase_corner_mark(sheet, tol=34):
    """생성기가 **우하단 구석에 찍는 워터마크 글리프**를 배경색으로 덮는다.

    누끼 뒤에 지우려 해도 소용없다 — 글리프가 곤충 다리 끝에 살짝 닿으면
    한 덩어리가 되어 `drop_fragments` 를 통과한다(실측 2026-08-19 미야마).
    자르기 **전에** 원본에서 지워야 한다.

    구석 상자 안에 **완전히 들어가는** 덩어리만 지운다 — 다리가 그 구석까지
    뻗어 있으면 상자 밖으로 나가므로 건드리지 않는다.
    """
    import numpy as np
    from PIL import Image
    from scipy import ndimage

    a = np.array(sheet.convert("RGB")).astype(int)
    h, w, _ = a.shape
    bg = np.median(
        np.concatenate([a[:6].reshape(-1, 3), a[:, :6].reshape(-1, 3)]), axis=0
    )
    fg = np.abs(a - bg).max(axis=2) > tol
    y0, x0 = int(h * 0.78), int(w * 0.90)
    box = np.zeros(fg.shape, bool)
    box[y0:, x0:] = True
    if not (box & fg).any():
        return sheet

    # ⚠️ 덩어리로 가르려 하지 말 것. 글리프는 **다리 끝에 겹쳐 그려져** 있어
    # 3번 침식해도 곤충과 한 덩어리다(실측 2026-08-19 미야마 피격 자세).
    #
    # 대신 **밝기**로 가른다. 워터마크는 반투명이라 배경과 곤충의 **중간 톤**에
    # 앉는데, 그림 자체에는 그 중간 톤이 거의 없다. 배경↔곤충 밝기 구간의
    # 25~65% 에 드는 구석 화소만 지운다.
    bright = a.mean(axis=2)
    out_box = fg & ~box
    if not out_box.any():
        return sheet
    lo, hi = sorted([float(bg.mean()), float(np.median(bright[out_box]))])
    span = hi - lo
    hit = box & fg & (bright > lo + span * 0.25) & (bright < lo + span * 0.65)
    # 테두리 흐림까지 덮는다.
    hit = ndimage.binary_dilation(hit, np.ones((3, 3)), iterations=2) & box & fg
    if not hit.any():
        return sheet
    a[hit] = bg
    return Image.fromarray(a.astype("uint8"), "RGB").convert("RGBA")


def flood_cut(sheet, tol=34):
    """**테두리에서 번지는 플러드필**로 배경을 지운다.

    rembg 대신 쓰는 길이다. rembg 는 창백한 곤충(알비노 스킨)을 연보라 배경과
    구분하지 못해 등껍질에 큼직한 구멍을 뚫거나(왕사슴·도르쿠스·톱), 아예
    배경을 통째로 남긴다(넓적, 실측 2026-08-19).

    배경이 **균일한 단색**일 때만 쓴다 — 그럴 땐 색이 아니라 **연결성**으로
    가르므로, 몸 색이 배경과 아무리 닮아도 바깥에서 이어지지 않으면 살아남는다.
    곤충 둘레의 어두운 선화가 번짐을 막아준다.
    """
    import numpy as np
    from PIL import Image
    from scipy import ndimage

    raw = np.array(sheet.convert("RGB")).astype(int)
    bg = np.median(
        np.concatenate([raw[:6].reshape(-1, 3), raw[:, :6].reshape(-1, 3)]),
        axis=0,
    )
    # ⚠️ **가장자리에 배경색 여백을 덧댄다.** 곤충이 시트 끝에 닿아 있으면
    # 그 몸 픽셀이 곧 테두리 씨앗이 되어, 창백한 몸으로 번짐이 새어 들어간다
    # (실측 2026-08-19: 톱사슴벌레 피격 자세가 통째로 지워졌다).
    # 여백을 두면 씨앗이 여백에만 생기고, 번짐은 곤충 둘레의 어두운 선화에서 멈춘다.
    PAD = 8
    rgb = np.pad(raw, ((PAD, PAD), (PAD, PAD), (0, 0)), mode="constant")
    rgb[:PAD] = bg
    rgb[-PAD:] = bg
    rgb[:, :PAD] = bg
    rgb[:, -PAD:] = bg
    like = np.abs(rgb - bg).max(axis=2) < tol
    lab, n = ndimage.label(like)
    if n == 0:
        return sheet.convert("RGBA")
    # 테두리에 닿은 덩어리만 배경이다. 안에 갇힌 같은 색은 몸의 밝은 부분이다.
    keep = set(lab[0].tolist()) | set(lab[-1].tolist())
    keep |= set(lab[:, 0].tolist()) | set(lab[:, -1].tolist())
    keep.discard(0)
    out_bg = np.isin(lab, list(keep))
    a = np.where(out_bg, 0, 255).astype(np.uint8)
    # 경계 1px 을 부드럽게 — 칼로 자른 듯한 계단을 없앤다.
    soft = ndimage.gaussian_filter(a.astype(float), 0.8)
    a = np.clip(soft, 0, 255).astype(np.uint8)[PAD:-PAD, PAD:-PAD]
    out = np.dstack([raw.astype(np.uint8), a])
    return Image.fromarray(out, "RGBA")


def fill_speckles(cut, sheet, max_px=None):
    """rembg 가 곤충 몸 안에 남긴 **자잘한 투명 구멍**을 메운다.

    다리가 몸통을 가로지르는 곳에서 곧잘 뚫린다(실측: 톱사슴벌레 피격 자세의
    딱지날개). 화면에서는 배경이 비쳐 **몸에 구멍이 난 것처럼** 보인다.

    바깥과 안 이어진 작은 섬만 메운다 — 다리 사이 진짜 틈은 바깥과 이어져 있고,
    벌어진 큰턱 사이는 이 문턱보다 훨씬 넓다.

    ⚠️ **알파만 올리면 안 된다.** rembg 는 투명 화소의 RGB 를 0(검정)으로 두므로,
    알파만 255 로 세우면 그 자리가 **검은 반점**이 된다(실측 2026-08-19 알비노
    스킨: 왕사슴벌레 다리 밑에 941px 검은 얼룩). 원본 시트의 색을 같이 되살린다.

    ⚠️ **색으로 걸러내려 하지 말 것.** 창백한 곤충(알비노 스킨)은 몸 색이 배경과
    거의 같아서(실측 색차 3) 배경으로 오판되고, 그러면 구멍이 그대로 남아 화면에
    검게 뚫린다. 갇힌 작은 섬은 **무조건 메운다** — 진짜 틈은 대개 바깥과 이어져
    있어 여기 걸리지 않고, 걸리더라도 원본 색으로 메우므로 티가 안 난다.
    """
    import numpy as np
    from PIL import Image
    from scipy import ndimage

    src = np.array(sheet.convert("RGB")).astype(int)
    a = np.array(cut.getchannel("A"))
    holes = a <= 8
    if max_px is None:
        # 정액(4000)은 큰 시트에서 너무 작아 등껍질에 난 큰 구멍을 못 메웠다.
        # 피사체의 6% 까지는 구멍으로 본다 — 벌어진 큰턱 사이는 그보다 넓다.
        max_px = max(4000, int((a > 8).sum() * 0.06))
    lab, n = ndimage.label(holes)
    if n == 0:
        return cut
    edge = set(lab[0].tolist()) | set(lab[-1].tolist())
    edge |= set(lab[:, 0].tolist()) | set(lab[:, -1].tolist())
    fill = np.zeros_like(holes)
    for i in range(1, n + 1):
        if i in edge:
            continue
        m = lab == i
        if m.sum() > max_px:
            continue
        fill |= m
    if not fill.any():
        return cut
    a[fill] = 255
    rgb = np.array(cut.convert("RGB"))
    rgb[fill] = src[fill]  # 검정 대신 원본 색을 되살린다
    out = Image.fromarray(
        np.dstack([rgb.astype(np.uint8), a]).astype(np.uint8), "RGBA"
    )
    return out


def punch_holes(cut, sheet, tol=20, min_frac=0.005, min_abs=600,
                rim_guard=True):
    """곤충 **안에 갇힌 배경**을 뚫는다(벌어진 큰턱 사이 등).

    rembg 는 곤충을 하나의 덩어리로 잡아서, 큰턱이 벌어진 자세면 그 사이의 배경도
    곤충으로 친다(실측: 톱사슴벌레 대기 자세의 집게 안쪽이 크림색으로 찼다).

    배경색과 닮은 픽셀 중 **바깥(투명)에 닿지 않는 덩어리**만 뚫는다. 곤충 가장자리의
    크림색 림라이트는 바깥에 닿아 있으므로 살아남는다 — 이 구분이 없으면 테두리가
    갉아 먹힌다.
    """
    import numpy as np
    from PIL import Image
    from scipy import ndimage

    src = np.array(sheet.convert("RGB")).astype(int)
    bg = np.median(np.concatenate([src[:6].reshape(-1, 3), src[:, :6].reshape(-1, 3)]), axis=0)

    rgb = np.array(cut.convert("RGB")).astype(int)
    a = np.array(cut.getchannel("A"))
    inside = a > 8
    like_bg = inside & (abs(rgb - bg).max(axis=2) < tol)

    # ⚠️ **곤충이 배경과 비슷한 색이면 이 판정을 쓰면 안 된다.**
    # 알비노 스킨(연보라 배경 + 진주빛 흰 몸)에서 몸통·다리가 배경으로 잡혀
    # 등껍질에 검은 구멍이 뚫렸다(실측 2026-08-19). 큰턱 사이가 조금 차는 것보다
    # 몸에 구멍이 나는 쪽이 훨씬 나쁘다 — 애매하면 아무것도 뚫지 않는다.
    inside_px = max(1, inside.sum())
    if like_bg.sum() / inside_px > 0.25:
        return cut

    lab, n = ndimage.label(like_bg)
    if n == 0:
        return cut
    outside = ~inside
    # 벌어진 큰턱 사이는 **넓다**. 작은 덩어리는 곤충 몸의 밝은 부분이지 구멍이
    # 아니다 — 문턱이 낮으면 등껍질에 구멍이 뚫린다(실측: 톱사슴벌레 피격 자세).
    min_px = max(min_abs, int(inside.sum() * min_frac))
    kill = np.zeros_like(like_bg)
    for i in range(1, n + 1):
        m = lab == i
        if m.sum() < min_px:
            continue
        # 바깥(투명)에 닿으면 림라이트다 — 건드리지 않는다.
        #
        # ⚠️ flood 누끼에서는 이 보호를 끈다. 다리와 배 사이의 **가느다란 틈**은
        # 입구가 안티에일리어싱으로 막혀 번짐이 못 들어가고, 그 안에 갇힌 배경이
        # 몸 가장자리에 붙어 있어 이 검사에 걸려 살아남는다 — 어두운 배경
        # 시트에서 검은 조각으로 보였다(실측 2026-08-19).
        if rim_guard and (ndimage.binary_dilation(m, iterations=2) & outside).any():
            continue
        kill |= m
    if not kill.any():
        return cut
    a[kill] = 0
    out = cut.copy()
    out.putalpha(Image.fromarray(a))
    return out


def frame_metrics(img):
    """(bbox, 무게중심 x). 알파가 있는 픽셀 기준."""
    box = img.getbbox()
    if box is None:
        return None, None
    a = img.getchannel("A").load()
    l, t, r, b = box
    total = 0
    acc = 0
    for x in range(l, r):
        s = sum(a[x, y] for y in range(t, b, 3))
        acc += s * x
        total += s
    return box, (acc / total if total else (l + r) / 2)


def process(src, sid, dry, skin="", cutter="rembg", tol=34):
    from PIL import Image

    sheet = erase_corner_mark(Image.open(src).convert("RGBA"))
    # 시트를 **통째로** 지운다(칸을 먼저 자르면 큰턱 안쪽에 배경이 남는다).
    if cutter == "flood":
        # 배경이 균일하면 연결성으로 가르는 쪽이 훨씬 안전하다(창백한 곤충).
        #
        # 번짐은 **바깥에서 시작**하므로, 다리 사이처럼 몸에 갇힌 배경은
        # 지워지지 않고 남는다. 어두운 배경 시트에서는 그게 **검은 조각**으로
        # 보인다(실측 2026-08-19). 뚫는 문턱을 낮춰 잔조각까지 걷어낸다 —
        # 배경과 몸의 색이 확연히 다르니(어두운 배경 + 창백한 몸) 안전하다.
        cut = punch_holes(
            fill_speckles(flood_cut(sheet, tol), sheet),
            sheet,
            tol=tol,
            min_frac=0.0006,
            min_abs=120,
            rim_guard=False,
        )
    elif cutter == "both":
        # 창백한 곤충의 정답. 실루엣은 flood(연결성 — 몸을 안 먹는다), 바닥
        # 그림자 제거는 rembg(색이 아니라 학습된 형태로 판단) — **교집합**을
        # 쓰고, 그 과정에서 생긴 갇힌 구멍은 원본 색으로 되메운다.
        import numpy as np
        from rembg import remove
        from scipy import ndimage

        flood = flood_cut(sheet, tol)
        fa = np.array(flood.getchannel("A")).astype(int)
        ra = np.array(remove(sheet).getchannel("A")).astype(int)
        both = np.minimum(fa, ra)
        # ⚠️ **rembg 가 지운 덩어리**를 되살릴지 말지 — 기준은 크기가 아니라
        # **선화가 들어 있는가**다.
        #
        # rembg 는 시트의 칸 하나를 통째로 놓치기도 하고(실측: 톱사슴벌레 피격
        # 자세), 반대로 바닥 그림자는 잘 지운다. 크기로 가르려 했더니 다리
        # 사이의 넓은 그림자가 곤충만큼 커서 같이 되살아났다(실측 2026-08-19).
        #
        # 그림은 둘레에 **어두운 선화**가 있고 그림자에는 없다 — 배경보다
        # 확실히 어두운 화소가 들어 있으면 그림, 아니면 그림자다.
        # ("곤충 단위로 보자"도 안 통한다: 시트 바닥의 가로 지평선이 세 마리를
        #  하나로 이어 붙인다.)
        raw = np.array(sheet.convert("RGB")).astype(int)
        bgc = np.median(
            np.concatenate(
                [raw[:6].reshape(-1, 3), raw[:, :6].reshape(-1, 3)]
            ),
            axis=0,
        )
        inked = raw.mean(axis=2) < bgc.mean() - 70
        killed = (fa > 8) & (both <= 8)
        lab, n = ndimage.label(killed)
        for i in range(1, n + 1):
            m = lab == i
            if m.sum() < 4000:
                continue
            # 선화가 넉넉히 들어 있으면 그림이다.
            if (inked & m).sum() >= m.sum() * 0.02:
                both[m] = fa[m]
        merged = flood.copy()
        merged.putalpha(Image.fromarray(both.astype("uint8")))
        cut = fill_speckles(merged, sheet)
    else:
        from rembg import remove

        cut = punch_holes(fill_speckles(remove(sheet), sheet), sheet)
    w, h = cut.size
    cuts = split_columns(cut.getchannel("A"), w, h)

    frames = []
    for i in range(3):
        f = drop_fragments(cut.crop((cuts[i], 0, cuts[i + 1], h)))
        box, cx = frame_metrics(f)
        if box is None:
            return f"  ! {sid}: {i + 1}번 칸이 비었습니다 — 자른 위치를 확인하세요"
        frames.append((f, box, cx))

    # 세 칸 공통 기준. 발(바닥)과 배율을 맞춰야 자세가 바뀔 때 안 튄다.
    base_y = max(b[3] for _, b, _ in frames)
    top_y = min(b[1] for _, b, _ in frames)
    need_h = base_y - top_y
    # 가로는 무게중심을 가운데 두고도 안 잘리도록 잡는다.
    need_w = max(
        2 * max(cx - b[0], b[2] - cx) for _, b, cx in frames
    )
    scale = min(MAX_SIDE / need_w, MAX_SIDE / need_h, 1.0)
    cw, ch = max(1, round(need_w * scale)), max(1, round(need_h * scale))

    out = []
    for i, (f, box, cx) in enumerate(frames):
        strip = f.crop((0, top_y, f.width, base_y))
        sw, sh = max(1, round(strip.width * scale)), max(1, round(strip.height * scale))
        strip = strip.resize((sw, sh), Image.LANCZOS)
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.alpha_composite(strip, (round(cw / 2 - cx * scale), 0))
        # 스킨 그림은 접미사를 **번호 뒤**에 붙인다 — 앱이 찾는 이름이
        # `{종}_adult_{번호}_{효과}.webp` 다(art.dart 의 폴백 사슬).
        dst = os.path.join(DEST, f"{sid}_adult_{i + 1}{skin}.webp")
        out.append(dst)
        if not dry:
            # 무손실은 60장에 8.4MB — 번들이 감당 못 한다. 화면에서 96pt(고밀도
            # 288px)로 그리므로 q92 와 육안 차이가 없다(§0 규격과도 같다).
            canvas.save(dst, "WEBP", quality=92, method=6)
    # 채집함·도감·펫 화면은 자세가 없다(`bugStageImage`). 거기에 프레임 캔버스를
    # 그대로 주면 **위쪽이 텅 비어** 곤충이 작게 보인다 — 공격 자세가 위로 솟은
    # 만큼 캔버스가 높기 때문이다. 그래서 대기 프레임을 **딱 맞게 잘라** 따로 낸다.
    idle = frames[0][0]
    idle = idle.crop(idle.getbbox())
    idle.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    if not dry:
        # ⚠️ 스킨이면 접미사를 붙인다. 안 붙이면 **기본 대기컷을 덮어써서**
        # 스킨을 안 산 사람에게도(스카우트 보드·채집함·도감) 스킨 그림이
        # 나온다 — 후광도 없이 색만 바뀌어 보인다(실기 지적 2026-08-19).
        idle.save(
            os.path.join(DEST, f"{sid}_adult{skin}.webp"),
            "WEBP",
            quality=92,
            method=6,
        )

    return f"  {sid:24s} {cw}x{ch}  자른 위치 {cuts[1]},{cuts[2]} (1/3={w // 3},{2 * w // 3})"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", required=True, help="시트가 든 폴더")
    ap.add_argument("--only", help="종 id 하나만")
    ap.add_argument(
        "--cut",
        choices=("rembg", "flood", "both"),
        default="rembg",
        help="배경 제거 방식. 창백한 곤충(알비노)은 flood 가 안전하다.",
    )
    ap.add_argument(
        "--tol",
        type=int,
        default=34,
        help="flood 허용 색차. 바닥 그림자까지 지우려면 올린다(60 안팎).",
    )
    ap.add_argument(
        "--skin",
        help="스킨 그림이면 효과 키(gold/albino). "
        "{종}_adult_{n}_{효과}.webp 로 저장된다.",
    )
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    ids = species_ids()
    if a.only:
        if a.only not in ids:
            sys.exit(f"species.json 에 없는 id 입니다: {a.only}")
        ids = [a.only]

    found = [(i, os.path.join(a.src, i + ".png")) for i in ids]
    found = [(i, p) for i, p in found if os.path.exists(p)]
    missing = [i for i in ids if not any(i == j for j, _ in found)]
    if not found:
        sys.exit(f"{a.src} 에 종 id 이름의 png 가 없습니다")

    os.makedirs(DEST, exist_ok=True)
    print(f"{len(found)}종 처리{' (--dry: 저장 안 함)' if a.dry else ''}\n")
    for sid, path in found:
        # 스킨 그림은 같은 종의 기본 그림을 덮지 않게 접미사를 붙여 저장한다.
        # 파일이 없으면 앱이 기본 그림 + 색 필터로 조용히 떨어진다.
        print(
            process(
                path,
                sid,
                a.dry,
                "_" + a.skin if a.skin else "",
                a.cut,
                a.tol,
            )
        )
    if missing:
        print(f"\n아직 없는 종({len(missing)}): {', '.join(missing)}")
        print("  → 그 종은 예전 한 장짜리 그림으로 폴백됩니다(화면은 안 깨집니다).")


if __name__ == "__main__":
    main()
