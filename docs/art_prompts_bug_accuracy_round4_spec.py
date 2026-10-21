"""곤충 고증 4차 — 말벌 번데기(근거: art_prompts_bug_accuracy.md).

    python docs/art_prompts_bug_accuracy_round4_spec.py
    python packages/app/tool/make_prompt_page.py docs/art_prompts_bug_accuracy_round4.json "C:/Users/Lenovo/Downloads/곤충고증/4차_말벌/말벌_번데기.html"

지금 그림(stage_hornet_pupa.png)은 형태 없는 크림색 덩어리다. 실제 말벌 번데기는 나용 — 다리·더듬이·날개싹이
몸에 붙어 드러나고 겹눈부터 검게 물든다. 사진: 미국 농무부 ARS 의 장수말벌(Vespa mandarinia) 번데기(퍼블릭 도메인).
"""

import json
from pathlib import Path

B = "../packages/app/assets/images/bugs/"
HEAD = (
    "Use the first attached image only as the art style reference. Do NOT copy its anatomy. "
    "Its subject is deliberately a different creature: copy only the brushwork, outline, lighting and palette, never its shape, pose or composition. "
    "The second attached image is a real photo for anatomy reference (front view of the same pupa in a tube): follow its body "
    "parts and colours, but draw it in the pose described below, and where it differs from the description, the description wins. "
)
TAIL = (
    " Style: detailed painterly naturalist illustration with a soft dark outline, matching the attached style image. "
    "Single isolated subject, plain flat pale sage-green background touching the outline directly, "
    "no ground, no ground line, no tube, no cell, no cocoon, no shadow, no glow, no text, no watermark. Square 1:1."
)
items = [dict(
    title="장수말벌 번데기",
    file="stage_hornet_pupa",
    ref=B + "stage_mantis_egg.png",
    note="지금: 형태 없는 크림색 덩어리. 실제는 성충 모양이 다 드러나는 흰 번데기 — 겹눈만 먼저 검게 물든다.",
    prompt=HEAD + "Subject: the pupa of the Asian giant hornet (Vespa mandarinia), an exarate wasp pupa that already has "
    "the full adult shape: large rounded head with big dark grey-black compound eyes (the only dark part), pale creamy-white "
    "waxy body everywhere else, short strong mandibles, the two elbowed antennae laid down along the face and chest, all six "
    "legs folded tightly against the underside and clearly visible as separate jointed parts, short wing pads lying along "
    "the sides of the thorax, a narrow wasp waist, and a plump segmented abdomen tapering to a point. It is NOT a cocoon, "
    "NOT a smooth shell and NOT a blob. Strict side profile, head facing RIGHT, lying slightly curled." + TAIL,
    photo=r"C:\Users\Lenovo\Downloads\곤충고증\_참고사진\stage_hornet_pupa.jpg",
    photoNote="장수말벌(Vespa mandarinia) 흰 번데기 — 그 종(앞에서 본 모습, 시험관 속)",
    photoCredit="20210216-ARS-LSC-0471 · U.S. Department of Agriculture (ARS) · Public domain · "
    "https://commons.wikimedia.org/wiki/File:20210216-ARS-LSC-0471_(51021749747).jpg",
)]
spec = dict(
    title="곤충 고증 4차 — 장수말벌 번데기 (2026-10-21)",
    saveDir=r"C:\Users\Lenovo\Downloads\곤충고증\4차_말벌",
    intro="그림 복사 → 사진 복사 → 프롬프트 복사. "
    r"근거: D:\coding\BugChamp\docs\art_prompts_bug_accuracy.md",
    items=items,
)
out = Path(__file__).with_name("art_prompts_bug_accuracy_round4.json")
out.write_text(json.dumps(spec, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"{len(items)}장 → {out}")
