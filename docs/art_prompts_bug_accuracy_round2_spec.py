"""곤충 고증 2차 — 1차 결과에서 틀린 5장 + 성충이 바뀐 종의 스킨 4장(근거: art_prompts_bug_accuracy.md).

    python docs/art_prompts_bug_accuracy_round2_spec.py
    python packages/app/tool/make_prompt_page.py docs/art_prompts_bug_accuracy_round2.json "C:/Users/Lenovo/Downloads/곤충고증/2차/곤충고증_2차.html"

1차와 파일명이 같아서 저장 폴더를 `곤충고증\\2차` 로 나눈다.
"""

import json
from pathlib import Path

B = "../packages/app/assets/images/bugs/"
PHOTOS = Path(r"C:\Users\Lenovo\Downloads\곤충고증\_참고사진")
HEAD = (
    "Use the first attached image only as the art style reference. Do NOT copy its anatomy. "
    "Its subject is deliberately a different creature: copy only the brushwork, outline, lighting and palette, never its shape, pose or composition. "
    "The second attached image is a real photo for anatomy reference: follow its body shape and colours, "
    "but where it differs from the description below, the description wins. "
)
TAIL = (
    " Style: detailed painterly naturalist illustration with a soft dark outline, matching the attached style image. "
    "Single isolated subject, plain flat pale sage-green background touching the outline directly, "
    "no ground, no ground line, no shadow, no glow, no text, no watermark. Square 1:1."
)
items = []


def photo_of(card):
    ph = json.loads((PHOTOS / "_출처.json").read_text(encoding="utf-8"))
    p = ph[card]
    return dict(photo=p["photo"], photoNote=p["photoNote"], photoCredit=p["credit"])


# ── 1. 장수풍뎅이 번데기: 1차는 머리뿔이 성충처럼 위로 솟았다 ─────────────────
items.append(dict(
    title="장수풍뎅이 번데기 (다시)",
    file="rhino_japanese_pupa",
    ref=B + "stage_mantis_egg.png",
    note="1차: 머리뿔이 위로 솟음. 실제 번데기는 뿔이 앞으로 뻗었다가 아래로 꺾여 배 쪽에 붙는다(사진처럼).",
    prompt=HEAD + "Subject: the pupa of a male Japanese rhinoceros beetle (Trypoxylus dichotomus), amber-orange, waxy and "
    "semi-translucent. The long head horn is NOT raised: it points forward from the face and then bends DOWN, lying low "
    "along the underside below the head, its twice-forked tip near the front legs, exactly like the photo. Nothing sticks "
    "up above the back line except a small short forked bump on the front of the pronotum. Beetle pupae are exarate: "
    "NOT a cocoon and NOT a smooth shell. Legs, antennae and wing pads are folded tightly against the underside and "
    "clearly visible as separate sculpted parts; segmented abdomen with small paired lobes along the sides. "
    "Strict side profile, head facing RIGHT." + TAIL,
    **photo_of("rhino_japanese_pupa"),
))

# ── 2. 방아깨비 어린 약충: 1차는 후기 약충과 똑같았다 ─────────────────────
items.append(dict(
    title="방아깨비 어린 약충 (다시)",
    file="grasshopper_longheaded_larva",
    ref=B + "stage_mantis_egg.png",
    note="1차: 후기 약충(번데기 자리) 그림과 똑같음. 어린 약충은 짧고 통통하고 머리가 크고 날개싹이 없다.",
    prompt=HEAD + "Subject: a very young first-instar nymph of the oriental longheaded grasshopper (Acrida cinerea): "
    "SHORT and stubby compared with the adult (body only about four times as long as it is tall), proportionally large "
    "head with a short blunt cone pointing forward and upward, short flat antennae, plump soft pale-green body, hind legs "
    "long but thicker and shorter than an adult's, absolutely NO wings and NO wing buds, a cute baby look. "
    "Strict side profile, head facing RIGHT." + TAIL,
    **photo_of("grasshopper_longheaded_larva"),
))

# ── 성충(가로 3칸) ─────────────────────────────────────────────────────
AH = (
    "Use the first attached image only as the art style reference (painting style, eyes, outline, palette). "
    "Its subject is deliberately a different creature: copy only the brushwork, outline, lighting and palette, never its shape, pose or composition. "
    "Do NOT copy its anatomy. The second attached image is a real photo for anatomy reference: follow its body "
    "shape and colours, but where it differs from the description below, the description wins. "
    "Character pose sheet of the same insect: "
)
POSES = (
    " Three poses in one horizontal row, identical creature at identical size, strict side profile facing right, "
    "evenly spaced with wide even gaps so nothing overlaps, no dividing lines, no panel borders, no numbers, no labels, "
    "NO ground line or horizon line drawn, plain flat {bg} background; left: standing idle, weight settled, all legs planted, "
    "calm ready stance; center: {c}; right: recoiling from a heavy hit, clearly DIFFERENT from the center pose: body "
    "knocked backward and tilted up steeply, belly showing, legs flailing, head thrown back, off balance. "
)
STYLE = (
    "Cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted "
    "storybook texture, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark. Wide 3:1 image."
)
RULES = (
    " Anatomy rules: exactly six legs (three on the near side, three partly hidden on the far side), correct antennae "
    "for this species, no extra horns or spikes."
)
SEIZE = "lunging seize, {x} thrown wide open and reaching out to clamp, front of the body reared up"
STRIKE = "charging strike, body pitched low and thrust forward, {x} driving straight ahead, rear legs kicking off the ground"
SAGE = "pale sage-green"

for t, f, ref, a, c, why in [
    ("왕사슴벌레 성충 (다시)", "stag_giant", "hornet_giant_adult_1.webp",
     "a male Korean giant stag beetle (Dorcus hopei): glossy jet-black, broad parallel-sided body, smooth shiny elytra, "
     "wide flat head without ear-like flanges, thick heavy mandibles smoothly arched inward like calipers. Each mandible "
     "has exactly ONE large blunt inner tooth at about the middle and ends in ONE simple pointed tip — in ALL three poses, "
     "even when opened wide: NO forked tips, NO rows of small teeth, NOT long and thin like Lucanus. Short elbowed "
     "antennae with a small comb-like club.",
     SEIZE.format(x="thick caliper-like mandibles"),
     "1차: 대기 자세는 맞았는데 2·3번 칸 큰턱 끝이 갈라져 Lucanus 처럼 보였다."),
    ("장수꽃무지 성충 (다시)", "chafer_flower", "hornet_giant_adult_1.webp",
     "a male stag-horned flower chafer (Dicronocephalus adamsi): front of the head extended into two forward antler-like "
     "horns; its signature is EXTREMELY LONG FRONT LEGS — each front leg is about as long as the whole body, with a long "
     "slender curved tibia and long tarsi, held stretched out in front like arms, much longer than the middle and hind "
     "legs; compact flower-chafer body; pronotum and wing covers pale cream-grey with a powdery matte coating, two dark "
     "brown lengthwise bands on the pronotum, dark reddish-brown head horns and legs.",
     STRIKE.format(x="antler-like head horns and long front legs"),
     "1차: 앞다리가 보통 길이. 수컷의 가장 큰 특징이 '몸길이만 한 앞다리'다(사진 참고)."),
    ("좀사마귀 성충 (다시)", "mantis_jumping", "stag_dorcus_adult_1.webp",
     "a small slender Statilia maculata mantis: mottled grey-brown, smooth triangular head with NO horn or cone on top, "
     "thin thread-like antennae, slim body, brownish wings reaching the abdomen tip. A distinct black-and-white patch on "
     "the inner side of each front leg (on the coxa and femur) must be clearly visible in ALL three poses, including the "
     "standing idle pose — the front legs are held slightly open so the patch shows.",
     STRIKE.format(x="raptorial forelegs"),
     "1차: 앞다리 흑백 무늬가 대기 자세(1번 칸)에만 없었다."),
]:
    items.append(dict(title=t, file=f, ref=B + ref, note=why,
                      prompt=AH + a + RULES + POSES.format(bg=SAGE, c=c) + STYLE, **photo_of(f)))

# ── 스킨: 첨부 ① = 새로 넣은 그 종의 대기 자세(같은 곤충이어야 스킨으로 읽힌다) ──
SH = (
    "The attached image is THIS exact insect: keep its anatomy exactly — body shape, mandibles or horn, legs, antennae "
    "and proportions — and change ONLY the material and colours as described. Character pose sheet of the same insect "
)
GOLD_STYLE = (
    "Cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted "
    "storybook texture, rich gold palette (bright gold, deep bronze, warm amber, dark umber shadow), mirror-bright "
    "specular highlights, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark. Wide 3:1 image."
)
PEARL_STYLE = (
    "Cozy naturalist cartoon, semi-realistic stylized, soft cool moonlight, gentle rim light, hand-painted storybook "
    "texture, cold pearl palette (pearl white, pale ice blue, soft lilac, faint rose), subsurface glow through the thin "
    "shell plates, clean readable silhouette, mobile game art, crisp high detail, no shadow under the insect, no text, "
    "no watermark. Wide 3:1 image."
)
DARK = "dark slate-navy"  # 알비노는 어두운 배경(art_prompts.md §2c — 밝은 배경 + 창백한 몸은 누끼가 안 갈렸다)

for t, f, skin, mat, c, style, bg, why in [
    ("크리스탈 왕사슴벌레 (알비노 스킨)", "stag_giant", "albino",
     "made of translucent pearl-white crystal with an iridescent sheen and pale ruby eyes, regal: thick caliper-like "
     "mandibles each with ONE large blunt inner tooth and a single pointed tip (NOT forked).",
     SEIZE.format(x="thick caliper-like mandibles"), PEARL_STYLE, DARK, "굵은 둥근 큰턱 + 안쪽 큰 이빨 하나."),
    ("크리스탈 넓적사슴벌레 (알비노 스킨)", "stag_flat", "albino",
     "made of translucent pearl-white crystal with an iridescent sheen and pale ruby eyes: very flat wide body, long "
     "nearly straight mandibles with a row of small inner teeth, short elbowed antennae.",
     SEIZE.format(x="long flat mandibles"), PEARL_STYLE, DARK, "짧은 꺾인 더듬이 · 납작한 몸."),
    ("크리스탈 두점박이사슴벌레 (알비노 스킨)", "stag_twospot", "albino",
     "made of translucent pearl-white crystal with an iridescent sheen and pale ruby eyes; its two signature spots become "
     "two small ruby cabochons, ONE on each side of the pronotum (the thorax plate behind the head), NOT on the wing covers; "
     "long slender gently curved mandibles with fine teeth.",
     "heaving throw, mandibles scooping upward, front of the body lifted high, rear legs braced and coiled",
     PEARL_STYLE, DARK, "'등의 루비 두 개' → 앞가슴 양옆 루비 두 개."),
    ("황금 외뿔장수풍뎅이 (황금 스킨)", "rhino_lesser", "gold",
     "cast in polished gold with a filigree-engraved shell and an amber gem at the horn base: one short slender upright "
     "horn on the head, pronotum with a broad lengthwise central groove and NO thoracic horn.",
     STRIKE.format(x="single short horn"), GOLD_STYLE, "pale sage-green", "가슴 뿔 없이 가운데 홈."),
]:
    items.append(dict(
        title=t, file=f, ref=B + f + "_adult_1.webp",
        note=f"스킨 — 파일명은 종 id 그대로, 이 카드들만 '스킨' 폴더에 저장. {why} 첨부 ① 은 이번에 새로 넣은 그 종 그림(같은 곤충이라 일부러 붙인다).",
        prompt=SH + mat + RULES + POSES.format(bg=bg, c=c) + style,
    ))

spec = dict(
    title="곤충 고증 2차 — 다시 뽑기 5장 + 스킨 4장 (2026-10-21)",
    saveDir=r"C:\Users\Lenovo\Downloads\곤충고증\2차",
    intro="1~5 = 1차에서 틀린 그림 다시 뽑기(그림 → 사진 → 프롬프트). 6~9 = 스킨(그림 → 프롬프트, 사진 없음) — 스킨은 파일명이 성충과 같으니 "
    r"C:\Users\Lenovo\Downloads\곤충고증\2차\스킨 에 따로 저장. 결과에 바닥선이 그려져 나와도 괜찮다(배치할 때 지운다). "
    r"근거: D:\coding\BugChamp\docs\art_prompts_bug_accuracy.md",
    items=items,
)
out = Path(__file__).with_name("art_prompts_bug_accuracy_round2.json")
out.write_text(json.dumps(spec, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"{len(items)}장 → {out}")
