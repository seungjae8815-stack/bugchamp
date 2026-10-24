"""다시 그리기 3장 (2026-10-24 그림 검토 뒤) — 암컷 작업 페이지(art_prompts_female.json)의 카드를 바탕으로 설명만 바꾼다.

    python docs/art_prompts_redo_spec.py
    python packages/app/tool/make_prompt_page.py docs/art_prompts_redo.json "C:/Users/Lenovo/Downloads/곤충재작업/곤충재작업_작업.html"

1. 넓적사슴벌레 암컷 — 1차 그림의 큰턱이 수컷처럼 길고 휘었다 → "머리보다 짧은 집게" 를 못 박는다.
2. 장수하늘소 수컷 — 1차 그림의 큰턱이 사슴벌레 뿔처럼 가지가 갈라졌다 → "굵고 안으로 휜 집게, 가지 없음".
3. 넓적사슴벌레 알비노 스킨 — 수컷 그림을 새로 그려 옛 알비노 시트와 자세·턱이 다르다. 화풍 기준 = **새 수컷 그림**(§C 규칙),
   저장은 `stag_flat.png` 이름으로 따로 폴더에 두고 `place_bug_frames.py --skin albino --cut both` 로 처리한다.
"""

import json
from pathlib import Path

HERE = Path(__file__).parent
src = json.loads((HERE / "art_prompts_female.json").read_text(encoding="utf-8"))
by_file = {it["file"]: it for it in src["items"]}

HEAD = "Character pose sheet of the same insect: "
TAIL = " Anatomy rules:"


def with_desc(item, desc, **over):
    p = item["prompt"]
    s, e = p.index(HEAD) + len(HEAD), p.index(TAIL)
    out = dict(item)
    out["prompt"] = p[:s] + desc + p[e:]
    out.update(over)
    return out


FLAT_F = (
    "a FEMALE flat stag beetle (Dorcus titanus castanicolor): black, very flat and broad oval body, SMALL narrow head, "
    "mandibles TINY and stubby — shorter than the head itself, just two small pincer tips that barely poke out in front of "
    "the face, NEVER long, NEVER curved, NEVER toothed jaws (a previous drawing gave her male-like long jaws, which is "
    "wrong — she must look jawless at a glance), elytra glossy with fine lengthwise lines, short elbowed antennae with a "
    "small club."
)
RELICT_M = (
    "a male relict longhorn beetle (Callipogon relictus): huge dark brown-black longhorn, elytra dark brown with a faint "
    "lighter sheen, pronotum black with FOUR oval yellow-brown hair patches and sharp spines on each side, antennae about "
    "as long as the body but NOT longer, very long front legs. The mandibles are a pair of THICK HEAVY PINCERS: short-to-"
    "medium length (about as long as the head), smoothly curved inward toward each other, with two or three small blunt "
    "teeth on the inner edge — like heavy pliers. They are NOT branched, NOT forked, NOT antler-shaped, NOT stag-beetle "
    "jaws (a previous drawing gave it forked antler jaws, which is wrong)."
)
FLAT_ALBINO = (
    "an ALBINO colour variant of a male flat stag beetle (Dorcus titanus castanicolor) — the first attached image is the "
    "normal black version of this exact beetle: keep its shape, proportions and poses exactly, change only the colours: "
    "pearly white to pale cream shell with faint pink-lavender shading in the shadows, pale pink legs and antennae, light "
    "red-pink eyes. Very flat and wide body, long nearly straight mandibles that curve inward only at the tips with a row "
    "of many small inner teeth and one larger tooth near the base, short elbowed antennae with a small comb-like club. The "
    "whole beetle including both mandibles must fit inside the picture with empty space beyond the jaw tips."
)

items = [
    with_desc(
        by_file["stag_flat_female"],
        FLAT_F,
        title="넓적사슴벌레 암컷 (다시)",
        note="1차 그림: 큰턱이 수컷처럼 길고 휨 = 틀림. 머리보다 짧은 집게 끝만 — 한눈에 턱이 없어 보여야 한다.",
    ),
    with_desc(
        by_file["longhorn_relict"],
        RELICT_M,
        title="장수하늘소 수컷 (다시)",
        note="1차 그림: 공격·피격 자세 큰턱이 사슴벌레 뿔처럼 갈라짐 = 틀림. 굵고 안으로 휜 집게(펜치), 가지 없음.",
    ),
    with_desc(
        by_file["stag_flat"],
        FLAT_ALBINO,
        title="넓적사슴벌레 알비노 스킨 (수컷 새 그림 기준)",
        file="stag_flat_albino",
        ref="../packages/app/assets/images/bugs/stag_flat_adult_1.webp",
        note="화풍 기준 = 방금 넣은 새 수컷 그림(검은색). 모양·자세는 그대로, 색만 알비노. 저장 후 이름을 stag_flat.png 로 바꿔 "
        "별도 폴더에 두면 --skin albino 로 처리한다.",
    ),
]
# 알비노는 실물 사진이 필요 없다(색 지정이 프롬프트에 있다).
for k in ("photo", "photoNote", "photoCredit"):
    items[2].pop(k, None)

spec = dict(
    title="곤충 다시 그리기 3장 (2026-10-24)",
    saveDir=r"C:\Users\Lenovo\Downloads\곤충재작업",
    intro="1 = 넓적사슴벌레 암컷(큰턱 짧게) · 2 = 장수하늘소 수컷(큰턱 집게 모양) · 3 = 넓적사슴벌레 알비노 스킨(새 수컷 그림을 기준으로 색만). "
    "가로 3자세 한 장(대기 · 공격 · 피격), 가장자리에 여백. 첫 그림 = 화풍 기준, (있으면) 두 번째 = 실물 사진.",
    items=items,
)
out = HERE / "art_prompts_redo.json"
out.write_text(json.dumps(spec, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(items), "cards →", out)
