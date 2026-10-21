"""곤충 고증 다시 그리기 — 작업 페이지 명세를 만든다(근거: art_prompts_bug_accuracy.md).

    python docs/art_prompts_bug_accuracy_spec.py
    python packages/app/tool/make_prompt_page.py docs/art_prompts_bug_accuracy.json "C:/Users/Lenovo/Downloads/곤충고증/곤충고증_다시그리기.html"
"""

import json
from pathlib import Path

B = "../packages/app/assets/images/bugs/"
HEAD = (
    "Use the first attached image only as the art style reference. Do NOT copy its anatomy. "
    "Its subject is deliberately a different creature: copy only the brushwork, outline, lighting and palette, never its shape, pose or composition. "
    "The second attached image is a real photo for anatomy reference: follow its body shape and colours, "
    "but where it differs from the description below, the description wins. "
)
TAIL = (
    " Style: detailed painterly naturalist illustration with a soft dark outline, matching the attached style image. "
    "Single isolated subject, plain flat pale sage-green background touching the outline directly, "
    "no ground, no shadow, no glow, no text, no watermark. Square 1:1."
)
PHOTO = ""
items = []


def stage(title, file, subject, ref="stage_mantis_egg.png", note=PHOTO):
    items.append(
        dict(title=title, file=file, ref=B + ref, note=note, prompt=HEAD + "Subject: " + subject + TAIL)
    )


stage(
    "사슴벌레 애벌레 (사슴벌레 6종 공통)",
    "stage_stag_larva",
    "a stag beetle grub (Lucanidae larva, e.g. Dorcus / Lucanus): plump C-shaped creamy-white grub, smooth soft skin "
    "with only sparse fine hairs, rounded glossy orange-amber head capsule with strong dark-tipped mandibles, three pairs "
    "of well-developed orange-tinted legs, small orange spiracle dots along each side, rear abdomen only slightly "
    "enlarged. Strict side profile, head facing RIGHT.",
)
stage(
    "장수풍뎅이 애벌레 (장수풍뎅이·외뿔장수풍뎅이 공통)",
    "stage_rhino_larva",
    "a rhinoceros beetle grub (Dynastinae larva, Trypoxylus dichotomus): very large heavy C-shaped grub, creamy white "
    "with a grey-blue tint in the swollen rear abdomen, skin folded into soft segment wrinkles with only "
    "sparse short fine reddish-brown hairs (NOT furry, no dirt stuck on it), a row of distinct dark brown oval spiracles along each side, dark reddish-brown head capsule "
    "with black mandibles, three pairs of short legs. Strict side profile, head facing RIGHT.",
)
stage(
    "꽃무지 애벌레 (장수꽃무지)",
    "stage_chafer_larva",
    "a flower chafer grub (Cetoniinae larva): thick stout C-shaped creamy-white grub with a broad rounded rear, very "
    "short tiny legs, small brown head capsule, back covered with rows of short stiff brown bristles; it crawls on its "
    "back in real life, so draw it lying on its back with the tiny legs up and the bristly back on the bottom. "
    "Side profile, head facing RIGHT.",
)

PUPA = (
    " Beetle pupae are exarate: NOT a cocoon and NOT a smooth shell. Legs, antennae, wing pads and the mandibles or "
    "horns are folded tightly against the underside and clearly visible as separate sculpted parts; segmented abdomen "
    "with small paired lobes along the sides; waxy semi-translucent pale cream body turning amber. "
    "Strict side profile, head facing RIGHT."
)
for t, f, s in [
    ("애사슴벌레 번데기", "stag_dorcus_pupa",
     "a male Korean Dorcus stag beetle (Dorcus rectus): short stout mandibles curving inward with one small inner tooth, folded forward under the head."),
    ("톱사슴벌레 번데기", "stag_saw_pupa",
     "a male saw stag beetle (Prosopocoilus inclinatus): long mandibles strongly arched forward then downward, a row of saw teeth along the inner edge."),
    ("넓적사슴벌레 번데기", "stag_flat_pupa",
     "a male flat stag beetle (Dorcus titanus castanicolor): very flat broad body, long nearly straight mandibles with a row of many small inner teeth and one larger tooth near the base."),
    ("사슴벌레 번데기", "stag_miyama_pupa",
     "a male miyama stag beetle (Lucanus maculifemoratus): large curved mandibles with forked tips, head with ear-like lateral flanges behind the eyes."),
    ("왕사슴벌레 번데기", "stag_giant_pupa",
     "a male Korean giant stag beetle (Dorcus hopei): broad head, thick smoothly arched caliper-like mandibles with one large blunt inner tooth and simple pointed tips (NOT forked, NOT Lucanus-like)."),
    ("두점박이사슴벌레 번데기", "stag_twospot_pupa",
     "a male two-spotted stag beetle (Prosopocoilus astacoides blanchardi): long slender gently curved mandibles with fine teeth, pale amber body."),
    ("장수풍뎅이 번데기", "rhino_japanese_pupa",
     "a male Japanese rhinoceros beetle (Trypoxylus dichotomus): long head horn with a twice-forked tip lying folded down along the underside, short forked thoracic horn bump on the pronotum, amber-orange colour."),
    ("외뿔장수풍뎅이 번데기", "rhino_lesser_pupa",
     "a male Eophileurus chinensis rhinoceros beetle: small slim body, one short slender upright horn on the head, pronotum with a central lengthwise groove, no thoracic horn."),
    ("장수꽃무지 번데기", "chafer_flower_pupa",
     "a male stag-horned flower chafer (Dicronocephalus adamsi): front of the head extended into two forward antler-like horns, very long front legs folded along the body."),
]:
    stage(t, f, "the pupa of " + s + PUPA, ref="stage_mantis_egg.png")

stage(
    "방아깨비 어린 약충",
    "grasshopper_longheaded_larva",
    "an early nymph of the oriental longheaded grasshopper (Acrida cinerea): tiny wingless very slender elongated green "
    "body, long cone-shaped head pointing forward and upward, short flat sword-shaped antennae, very long thin hind legs. "
    "Strict side profile, head facing RIGHT.",
    ref="stage_mantis_egg.png",
)
stage(
    "방아깨비 후기 약충 (번데기 자리)",
    "grasshopper_longheaded_pupa",
    "a late-instar nymph of the oriental longheaded grasshopper (Acrida cinerea): long slender green body, long "
    "cone-shaped head, short flat sword-shaped antennae, very long hind legs, small triangular wing buds on the back "
    "(this insect has no true pupa). Strict side profile, head facing RIGHT.",
    ref="stage_mantis_egg.png",
)
stage(
    "여치 알",
    "katydid_egg",
    "three separate long flat oval katydid eggs (Gampsocleis), pale grey-beige, laid side by side. Katydids lay single "
    "eggs with an ovipositor, NOT an egg pod.",
    ref="stage_hornet_larva.png",
    note="",
)

AH = (
    "Use the first attached image only as the art style reference (painting style, eyes, outline, palette). "
    "Its subject is deliberately a different creature: copy only the brushwork, outline, lighting and palette, never its shape, pose or composition. "
    "Do NOT copy its anatomy. The second attached image is a real photo for anatomy reference: follow its body "
    "shape and colours, but where it differs from the description below, the description wins. "
    "Character pose sheet of the same insect: "
)
AR = (
    " Anatomy rules: exactly six legs (three on the near side, three partly hidden on the far side), correct antennae "
    "for this species, no extra horns or spikes. Three poses in one horizontal row, identical creature at identical "
    "size standing on the same ground line, strict side profile facing right, evenly spaced with wide even gaps, no "
    "dividing lines, no panel borders, no numbers, no labels, plain flat pale sage-green background; left: standing "
    "idle, weight settled, all legs planted, calm ready stance; center: {c}; right: recoiling from a heavy hit, "
    "knocked backward and tilted up, legs buckling underneath, head thrown back, off balance. Cozy naturalist cartoon, "
    "semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, clean "
    "readable silhouette, mobile game art, crisp high detail, no text, no watermark. Wide 3:1 image."
)
SEIZE = "lunging seize, {x} thrown wide open and reaching out to clamp, front of the body reared up"
STRIKE = "charging strike, body pitched low and thrust forward, {x} driving straight ahead, rear legs kicking off the ground"
TOSS = "heaving throw, {x} scooping upward, front of the body lifted high, rear legs braced and coiled"

for t, f, ref, a, c, why in [
    ("왕사슴벌레 성충 (전투 3자세)", "stag_giant", "hornet_giant_adult_1.webp",
     "a male Korean giant stag beetle (Dorcus hopei): glossy jet-black, broad parallel-sided body, smooth shiny elytra, wide flat head without ear-like flanges, thick heavy mandibles smoothly arched inward like calipers with ONE large blunt inner tooth at about the middle and simple pointed tips (NOT forked, NOT long and thin like Lucanus), short elbowed antennae with a small comb-like club.",
     SEIZE.format(x="thick arched mandibles"), "지금: 끝이 갈라진 가는 큰턱 = Lucanus 생김새."),
    ("넓적사슴벌레 성충 (전투 3자세)", "stag_flat", "hornet_giant_adult_1.webp",
     "a male flat stag beetle (Dorcus titanus castanicolor): black, very flat and wide body, slightly matte finely textured elytra, long nearly straight mandibles that curve inward only at the tips, a row of many small teeth along the inner edge and one larger tooth near the base, short elbowed antennae with a small comb-like club (NOT long antennae).",
     SEIZE.format(x="long flat mandibles"), "지금: 하늘소 같은 긴 톱니 더듬이."),
    ("두점박이사슴벌레 성충 (전투 3자세)", "stag_twospot", "hornet_giant_adult_1.webp",
     "a male two-spotted stag beetle (Prosopocoilus astacoides blanchardi): body yellowish amber-brown (NOT red) with thin black edges along the pronotum margins and the wing-cover seam, ONE small black dot on each side of the pronotum (the thorax plate behind the head) and NO spots on the wing covers, long slender gently curved mandibles with a row of fine teeth, short elbowed antennae.",
     TOSS.format(x="mandibles"), "지금: 적갈색 + 딱지날개 위 주황 점. 실제는 황갈색 + 앞가슴 양옆 검은 점."),
    ("외뿔장수풍뎅이 성충 (전투 3자세)", "rhino_lesser", "hornet_giant_adult_1.webp",
     "a male Eophileurus chinensis rhinoceros beetle: small, glossy jet-black (NOT brown), slightly flattened elongate body, one short slender upright horn on the head, pronotum with a broad lengthwise central groove and NO thoracic horn, short lamellate antennae.",
     STRIKE.format(x="single short horn"), "지금: 갈색 + 장수풍뎅이식 가슴."),
    ("장수하늘소 성충 (전투 3자세)", "longhorn_relict", "hornet_giant_adult_1.webp",
     "a male Korean relict longhorn beetle (Callipogon relictus, the largest beetle in Korea): huge, very dark glossy black-brown body, wing covers with a faint golden-brown sheen of fine hair, a few small yellowish hair patches on the black pronotum, LARGE strong mandibles curving forward and down, pronotum sides with several sharp spines, thick antennae about as long as the body, long strong front legs.",
     SEIZE.format(x="big mandibles"), "지금: 주황 몸에 점, 가는 긴 더듬이, 큰턱 없음."),
    ("톱하늘소 성충 (전투 3자세)", "longhorn_saw", "hornet_giant_adult_1.webp",
     "a male Prionus insularis longhorn beetle: dark brown to black-brown, matte, broad body, NO horn on the head, strong short mandibles, three sharp spines on each side of the pronotum, saw-toothed (serrate) antennae shorter than the body.",
     SEIZE.format(x="mandibles"), "지금: 머리에 뿔."),
    ("좀사마귀 성충 (전투 3자세)", "mantis_jumping", "stag_dorcus_adult_1.webp",
     "a small slender Statilia maculata mantis: mottled grey-brown, smooth triangular head with NO horn or cone on top, thin thread-like antennae, slim body, brownish wings reaching the abdomen tip, a distinct black-and-white patch on the inner side of the raised front legs.",
     STRIKE.format(x="raptorial forelegs"), "지금: 머리 위 원뿔 뿔, 더듬이 없음."),
    ("방아깨비 성충 (전투 3자세)", "grasshopper_longheaded", "stag_dorcus_adult_1.webp",
     "an oriental longheaded grasshopper (Acrida cinerea): very long and slender green body, the whole head is a long cone pointing forward and upward (NO horn on top), short flat sword-shaped antennae, very long thin hind legs, long narrow pointed wings.",
     TOSS.format(x="powerful hind legs"), "지금: 정수리 뿔, 긴 톱니 더듬이, 통통한 몸."),
    ("장수꽃무지 성충 (전투 3자세)", "chafer_flower", "hornet_giant_adult_1.webp",
     "a male stag-horned flower chafer (Dicronocephalus adamsi): front of the head extended into two forward antler-like horns, very long front legs, compact flower-chafer body; pronotum and wing covers pale cream-grey with a powdery matte coating, two dark brown lengthwise bands on the pronotum, dark reddish-brown head horns and legs.",
     STRIKE.format(x="antler-like head horns"), "지금: 금속빛 초록 = 다른 꽃무지. 색·무늬는 확인 못 함 — 사진 필수."),
]:
    items.append(dict(title=t, file=f, ref=B + ref, note=why, prompt=AH + a + AR.format(c=c)))

# 두 번째 그림(실물 사진) — 위키미디어 공용에서 골라 다운로드 폴더에 둔 것(사진 고르기 결과 _출처.json).
PHOTOS = Path(r"C:\Users\Lenovo\Downloads\곤충고증\_참고사진\_출처.json")
if PHOTOS.exists():
    ph = json.loads(PHOTOS.read_text(encoding="utf-8"))
    for it in items:
        p = ph.get(it["file"])
        if p:
            it.update(photo=p["photo"], photoNote=p["photoNote"], photoCredit=p["credit"])

spec = dict(
    title="곤충 고증 다시 그리기 (2026-10-20)",
    saveDir=r"C:\Users\Lenovo\Downloads\곤충고증",
    intro="1~15 = 애벌레·번데기(문의 대상), 16~24 = 성충 전투 3자세(가로 3칸 한 장). 실물 사진은 위키미디어 공용에서 골랐고, 그 종 사진이 없으면 같은 속·같은 무리 사진이다(카드에 적힘 — 다른 점은 프롬프트 글이 이긴다). 스킨(알비노·황금) 4장은 새 성충을 넣은 뒤 따로 드린다. "
    r"근거: D:\coding\BugChamp\docs\art_prompts_bug_accuracy.md",
    items=items,
)
out = Path(__file__).with_name("art_prompts_bug_accuracy.json")
out.write_text(json.dumps(spec, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"{len(items)}장 → {out}")
