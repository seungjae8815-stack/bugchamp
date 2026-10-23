"""암컷 성충 그림 19종 + 수컷 고증 다시 그리기 2종 (2026-10-23, 유저 문의 "암수 차이" → 사장님 "따로 그려보자").

    python docs/art_prompts_female_spec.py
    python packages/app/tool/make_prompt_page.py docs/art_prompts_female.json "C:/Users/Lenovo/Downloads/곤충암컷/곤충암컷_작업.html"

- 형식은 1차 고증(art_prompts_bug_accuracy_spec.py)과 같다: 가로 3자세 한 장(대기 · 공격 · 피격), 화풍 기준은 **다른 생물**,
  두 번째 첨부는 실물 **암컷** 사진(위키미디어 공용, 암컷 사진이 없는 종은 같은 종 수컷·같은 속 사진 + 카드에 차이점).
- 장수꽃무지는 암수 겉모습 차이가 거의 없어 수컷 그림을 그대로 쓴다(카드 없음).
- 장수말벌은 지금 그림이 일벌(암컷)이라 "암컷 그림" = **여왕벌**, 수컷은 지금 그림 그대로.
- 파일명 = `{종 id}_female` (배치 도구가 `_female_adult`·`_1`·`_2`·`_3` 으로 자른다). 수컷 다시 그리기는 `{종 id}` 그대로.
"""

import json
import re
import shutil
from pathlib import Path

B = "../packages/app/assets/images/bugs/"
SP = Path(r"C:\Users\Lenovo\AppData\Local\Temp\claude\D--coding-BugChamp\062ce65a-69bd-43e7-b31e-5c518cfedcd3\scratchpad\female_photos")
DST = Path(r"C:\Users\Lenovo\Downloads\곤충암컷\_참고사진")
SPECIES = json.loads(Path(__file__).with_name("..").joinpath("packages/app/assets/data/species.json").read_text(encoding="utf-8"))
SPECIALTY = {s["id"]: s["specialty"] for s in (SPECIES if isinstance(SPECIES, list) else SPECIES["species"])}

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
    "dividing lines, no panel borders, no numbers, no labels, no words anywhere, plain flat pale sage-green background; left: standing "
    "idle, weight settled, all legs planted, calm ready stance; center: {c}; right: recoiling from a heavy hit, "
    "knocked backward and tilted up, legs buckling underneath, head thrown back, off balance, still seen from the side (NOT belly-up). Cozy naturalist cartoon, "
    "semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, clean "
    "readable silhouette, mobile game art, crisp high detail, no text, no watermark. Wide 3:1 image."
)
SEIZE = "lunging seize, {x} thrown wide open and reaching out to clamp, front of the body reared up"
STRIKE = "charging strike, body pitched low and thrust forward, {x} driving straight ahead, rear legs kicking off the ground"
TOSS = "heaving throw, {x} scooping upward, front of the body lifted high, rear legs braced and coiled"
POSE = {"grip": SEIZE, "strike": STRIKE, "throw": TOSS, "toss": TOSS}

BEETLE_REF = "hornet_giant_adult_1.webp"   # 딱정벌레·물장군 → 말벌(다른 목)
OTHER_REF = "stag_dorcus_adult_1.webp"     # 사마귀·메뚜기·여치·말벌 → 사슴벌레

# (제목, 파일, 화풍 기준, 설명, 공격 부위, 카드 메모, 사진 후보, 사진 메모)
CARDS = [
    ("애사슴벌레 암컷", "stag_dorcus_female", BEETLE_REF,
     "a FEMALE Korean Dorcus stag beetle (Dorcus rectus): small compact glossy black oval body, head small and narrow, "
     "mandibles VERY SHORT and stubby (barely longer than the head, NOT long jaws), elytra with faint fine lengthwise lines, "
     "short elbowed antennae with a small comb-like club.",
     "short stubby mandibles", "수컷보다 훨씬 작고(20~30mm) 큰턱이 거의 없다. 머리가 좁다.",
     "stag_dorcus__1", "애사슴벌레 암컷 — 그 종"),
    ("톱사슴벌레 암컷", "stag_saw_female", BEETLE_REF,
     "a FEMALE saw stag beetle (Prosopocoilus inclinatus): dark reddish-brown to black-brown, compact rounded oval body, "
     "small head, short stubby mandibles with one tiny inner tooth (NO long curved saw jaws), elytra slightly matte with fine "
     "lengthwise lines, short elbowed antennae.",
     "short stubby mandibles", "수컷의 긴 톱니 큰턱이 없다. 색은 수컷보다 어두운 적갈색~흑갈색.",
     "stag_saw__0", "톱사슴벌레 암컷 — 그 종"),
    ("외뿔장수풍뎅이 암컷", "rhino_lesser_female", BEETLE_REF,
     "a FEMALE Eophileurus chinensis rhinoceros beetle: small glossy jet-black slim slightly flattened body, head with only a "
     "tiny blunt bump where the male has a horn (NO horn), pronotum with a shallow central lengthwise groove, elytra with rows "
     "of fine punctures, short elbowed antennae.",
     "flat blunt head", "수컷의 짧은 뿔 대신 작은 혹만 있다.",
     "rhino_lesser__0", "같은 Eophileurus 속(E. javanus) — 그 종 암컷 사진 없음. 광택 검은색·몸꼴만 참고, 뿔은 없게"),
    ("좀사마귀 암컷", "mantis_jumping_female", OTHER_REF,
     "a FEMALE Asian jumping mantis (Statilia maculata): brown-grey mantis, noticeably plumper than the male with a wide heavy "
     "rounded abdomen, wings reaching about the tip of the abdomen, inner side of the raptorial forelegs with a black patch "
     "and a pale patch, short thread antennae, triangular head with large eyes.",
     "spiny raptorial forelegs", "수컷은 가늘고 더듬이가 길다. 암컷은 배가 넓고 무겁다.",
     "mantis_jumping__0", "좀사마귀 암컷 — 그 종"),
    ("톱하늘소 암컷", "longhorn_saw_female", BEETLE_REF,
     "a FEMALE saw longhorn beetle (Prionus insularis): glossy black-brown, broad heavy body widest at the abdomen, strong "
     "jaws, antennae THIN and only weakly serrated and about half the body length (the male's are thick and strongly "
     "saw-toothed), pronotum with a small spine on each side.",
     "strong jaws", "수컷은 더듬이가 굵고 톱니가 강하다. 암컷은 가늘고 짧으며 몸이 더 넓다.",
     "longhorn_saw__0", "톱하늘소 — 그 종(암수 표시 없음). 더듬이는 프롬프트대로 가늘고 짧게"),
    ("방아깨비 암컷", "grasshopper_longheaded_female", OTHER_REF,
     "a FEMALE oriental longheaded grasshopper (Acrida cinerea): MUCH larger and stouter than the male, bright green, very long "
     "cone-shaped head pointing forward and upward, flat sword-shaped antennae, heavy thick abdomen, wings reaching past the "
     "abdomen tip, very long hind legs.",
     "long hind legs", "암컷(75~80mm)이 수컷(40~50mm)보다 훨씬 크다. 통통하게.",
     "grasshopper_longheaded__1", "방아깨비 암컷 — 그 종"),
    ("넓적사슴벌레 암컷", "stag_flat_female", BEETLE_REF,
     "a FEMALE flat stag beetle (Dorcus titanus castanicolor): black, very flat and broad oval body, small head, short stubby "
     "mandibles (NO long flat jaws), elytra glossy with fine lengthwise lines, short elbowed antennae with a small club.",
     "short stubby mandibles", "수컷의 길고 납작한 큰턱이 없다.",
     "stag_flat__0", "넓적사슴벌레 — 오른쪽 작은 것이 암컷"),
    ("장수풍뎅이 암컷", "rhino_japanese_female", BEETLE_REF,
     "a FEMALE Japanese rhinoceros beetle (Trypoxylus dichotomus): NO horns at all, dark red-brown to black-brown, head small "
     "and flat with only a tiny bump, pronotum smooth, elytra MATTE with fine punctures and short sparse golden hairs (not "
     "the male's glossy shell), stout oval body, strong toothed digging front legs, short elbowed antennae.",
     "flat hornless head", "뿔이 전혀 없다. 수컷보다 광택이 적고 짧은 털이 있다.",
     "rhino_japanese__1", "장수풍뎅이 암컷 — 그 종"),
    ("넓적배사마귀 암컷", "mantis_widebelly_female", OTHER_REF,
     "a FEMALE wide-bellied mantis (Hierodula patellifera): bright green stout mantis with a WIDE rounded abdomen, wings "
     "covering the abdomen, one small yellow spot on each front coxa (base of the raptorial forelegs), short antennae, "
     "triangular head.",
     "spiny raptorial forelegs", "수컷은 가늘고 더듬이가 길다. 앞다리 밑마디의 노란 점이 특징.",
     "mantis_widebelly__0", "넓적배사마귀 암컷 — 그 종"),
    ("알락하늘소 암컷", "longhorn_whitespot_female", BEETLE_REF,
     "a FEMALE white-spotted longhorn beetle (Anoplophora malasiaca): glossy black with scattered white spots on the elytra, "
     "antennae with white-banded segments only about as long as the body (the male's are much longer), slightly broader "
     "abdomen, pronotum with a spine on each side.",
     "strong jaws", "수컷 더듬이는 몸의 1.5~2배. 암컷은 몸길이 정도.",
     "longhorn_whitespot__0", "알락하늘소 — 그 종(암수 표시 없음). 더듬이 길이는 프롬프트대로 짧게"),
    ("여치 암컷", "katydid_female", OTHER_REF,
     "a FEMALE katydid (Gampsocleis sedakovii): large green and brown katydid with a LONG straight sword-shaped ovipositor "
     "projecting backward from the rear (about as long as the body), wings shorter than the abdomen, long thread antennae, "
     "strong spiny hind legs, heavy body.",
     "spiny hind legs", "산란관(긴 칼 모양)이 뒤로 뻗는다. 수컷은 산란관이 없고 날개에 소리내는 부위.",
     "katydid__0", "여치 암컷 — 그 종(산란관 보임)"),
    ("사슴벌레 암컷", "stag_miyama_female", BEETLE_REF,
     "a FEMALE miyama stag beetle (Lucanus maculifemoratus): dark brown to black, dull not glossy, plain rounded head with NO "
     "ear-like flanges, short stubby mandibles, distinctive yellow-brown spots on the femora of all legs, oval body, elytra "
     "with fine texture, short elbowed antennae.",
     "short stubby mandibles", "수컷의 귀 같은 머리 돌기와 긴 큰턱이 없다. 넓적다리의 노란 점이 이름의 유래.",
     "stag_miyama__0", "사슴벌레 암컷(출처 제목 기준) — 넓적다리 노란 점은 프롬프트대로"),
    ("왕사마귀 암컷", "mantis_giant_female", OTHER_REF,
     "a FEMALE giant Asian mantis (Tenodera sinensis): large green mantis (brown tones allowed on the wings) with a LONG heavy "
     "abdomen, wings covering the abdomen, long thin raptorial forelegs, short antennae; bigger and heavier than the male.",
     "spiny raptorial forelegs", "수컷은 가늘고 날개가 배보다 길다. 암컷은 배가 무겁다.",
     "mantis_giant__0", "왕사마귀 암컷 — 그 종"),
    ("참나무하늘소 암컷", "longhorn_oak_female", BEETLE_REF,
     "a FEMALE oak longhorn beetle (Batocera lineolata): grey-brown elytra with pale yellow-white spots in two loose rows and "
     "a white stripe along each side of the body, pronotum with two orange-yellow oval spots and a sharp spine on each side, "
     "antennae about as long as the body, long legs, grey-brown velvety texture.",
     "strong jaws", "흰 점무늬·옆 흰 줄·앞가슴 주황 점이 반드시. 암컷 더듬이는 몸길이 정도.",
     "longhorn_oak__3", "참나무하늘소 — 그 종(무늬 참고)"),
    ("왕사슴벌레 암컷", "stag_giant_female", BEETLE_REF,
     "a FEMALE Korean giant stag beetle (Dorcus hopei): glossy black oval body, small head, short stubby mandibles (NO caliper "
     "jaws), elytra with CLEAR lengthwise striae / rows of punctures (unlike the smooth male), short elbowed antennae.",
     "short stubby mandibles", "수컷은 매끈한 딱지날개, 암컷은 세로 줄이 뚜렷하다.",
     "stag_giant__2", "왕사슴벌레 수컷 사진 — 암컷 사진 없음. 색·광택만 참고, 큰턱은 짧게·딱지날개 세로 줄"),
    ("물장군 암컷", "water_bug_giant_female", BEETLE_REF,
     "a FEMALE giant water bug (Lethocerus deyrollei): large flat oval brown bug, slightly larger and broader than the male, "
     "raptorial front legs with hooked tips, oar-like fringed middle and hind legs, short pointed beak, leathery wings folded "
     "flat over the back with a fine pattern, small eyes.",
     "raptorial front legs", "암컷이 수컷보다 조금 크다. 겉모습은 거의 같다.",
     "water_bug_giant__3", "물장군 암수 — 왼쪽 큰 것이 암컷"),
    ("두점박이사슴벌레 암컷", "stag_twospot_female", BEETLE_REF,
     "a FEMALE two-spotted stag beetle (Prosopocoilus astacoides blanchardi): dark brown-black head and pronotum with one small "
     "black dot on each side of the pronotum, elytra yellowish amber-brown with a dark seam and dark edges, short stubby "
     "mandibles, compact oval body, short elbowed antennae.",
     "short stubby mandibles", "수컷의 길고 가는 큰턱이 없다. 머리·앞가슴은 더 어둡다.",
     "stag_twospot__0", "두점박이사슴벌레 표본 — 작은 개체 참고, 큰턱은 프롬프트대로 짧게"),
    ("장수하늘소 암컷", "longhorn_relict_female", BEETLE_REF,
     "a FEMALE relict longhorn beetle (Callipogon relictus): huge dark brown-black longhorn, elytra dark brown with a faint "
     "lighter sheen, pronotum black with FOUR oval yellow-brown hair patches and sharp spines on each side, mandibles short "
     "and thick, antennae SHORTER than the body, long strong legs.",
     "thick jaws", "앞가슴의 노란 털 뭉치 4개 · 더듬이는 몸보다 짧게. 수컷은 큰턱이 크다.",
     "longhorn_relict__0", "장수하늘소 암컷 표본 — 그 종"),
    ("장수말벌 여왕벌 (암컷 그림)", "hornet_giant_female", OTHER_REF,
     "a QUEEN Asian giant hornet (Vespa mandarinia): bigger and heavier than a worker, very large orange-yellow head with "
     "big dark eyes and strong jaws, dark brown thorax, abdomen with broad alternating dark brown and orange bands ending "
     "in an orange tip, amber translucent wings, orange legs.",
     "jaws and stinger", "지금 그림이 일벌(암컷)이라 암컷 그림 = 여왕벌(더 크고 무겁게). 수컷은 지금 그림 그대로.",
     "hornet_giant__2", "장수말벌 여왕 — 그 종"),
    # ── 수컷 고증 다시 그리기 2종(그림 점검에서 틀린 것) ──
    ("참나무하늘소 수컷 (다시)", "longhorn_oak", BEETLE_REF,
     "a male oak longhorn beetle (Batocera lineolata): grey-brown velvety elytra with pale yellow-white spots in two loose rows "
     "and a white stripe along each side of the body, pronotum with two orange-yellow oval spots and a sharp spine on each "
     "side, antennae about one and a half times the body length, long legs.",
     "strong jaws", "지금 그림: 무늬 없는 민무늬 갈색 = 틀림. 흰 점·옆 흰 줄·앞가슴 주황 점을 넣는다.",
     "longhorn_oak__3", "참나무하늘소 — 그 종"),
    ("장수하늘소 수컷 (다시)", "longhorn_relict", BEETLE_REF,
     "a male relict longhorn beetle (Callipogon relictus): huge dark brown-black longhorn, elytra dark brown with a faint "
     "lighter sheen, pronotum black with FOUR oval yellow-brown hair patches and sharp spines on each side, LARGE thick "
     "curved mandibles, antennae about as long as the body but NOT longer, very long front legs.",
     "large curved mandibles", "지금 그림: 알락하늘소처럼 더듬이가 몸보다 김 = 틀림. 앞가슴 노란 털 뭉치·큰 큰턱.",
     "longhorn_relict__1", "장수하늘소 암컷 접사(앞가슴 노란 털 뭉치 참고) — 수컷은 큰턱이 더 크다"),
]

meta = json.loads((SP / "_meta.json").read_text(encoding="utf-8"))
DST.mkdir(parents=True, exist_ok=True)
items = []
src_json = {}
for title, file, ref, desc, x, note, cand, photo_note in CARDS:
    sid = file.replace("_female", "")
    pose = POSE[SPECIALTY[sid]].format(x=x)
    m = meta[cand + ".jpg"]
    shutil.copyfile(SP / (cand + ".jpg"), DST / (file + ".jpg"))
    artist = re.sub("<[^>]+>", "", m["artist"]).strip()
    credit = f"{m['title'][5:]} · {artist} · {m['license']} · {m['page']}"
    src_json[file] = {"photo": str(DST / (file + ".jpg")), "photoNote": photo_note, "credit": credit}
    items.append(dict(title=title, file=file, ref=B + ref, note=note, prompt=AH + desc + AR.format(c=pose),
                      photo=str(DST / (file + ".jpg")), photoNote=photo_note, photoCredit=credit))
(DST / "_출처.json").write_text(json.dumps(src_json, ensure_ascii=False, indent=1), encoding="utf-8")

spec = dict(
    title="곤충 암컷 성충 19종 + 수컷 다시 그리기 2종 (2026-10-23)",
    saveDir=r"C:\Users\Lenovo\Downloads\곤충암컷",
    intro="1~19 = 암컷 성충(가로 3자세 한 장: 대기 · 공격 · 피격) · 20~21 = 참나무하늘소·장수하늘소 수컷 고증 다시 그리기. "
    "장수꽃무지는 암수 차이가 거의 없어 수컷 그림을 쓴다. 장수말벌 암컷 그림 = 여왕벌. "
    "첫 그림 = 화풍 기준(일부러 다른 생물), 두 번째 = 실물 사진(암컷 사진이 없는 종은 카드에 적힘 — 다른 점은 프롬프트 글이 이긴다). "
    "결과는 파일명 그대로 저장(암컷은 `종id_female.png`).",
    items=items,
)
out = Path(__file__).with_name("art_prompts_female.json")
out.write_text(json.dumps(spec, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(items), "cards →", out)
