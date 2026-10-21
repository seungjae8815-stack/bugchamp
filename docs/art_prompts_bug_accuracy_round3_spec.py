"""곤충 고증 3차 — 알비노 스킨 3장 다시(근거: art_prompts_bug_accuracy.md).

    python docs/art_prompts_bug_accuracy_round3_spec.py
    python packages/app/tool/make_prompt_page.py docs/art_prompts_bug_accuracy_round3.json "C:/Users/Lenovo/Downloads/곤충고증/3차_알비노/알비노_다시.html"

2차 알비노는 대기 자세 한 장만 붙이고 "같은 곤충의 세 자세"를 새로 그리게 했더니
① 자세 이름 글자를 그려 넣고 ② 왼쪽을 보거나 뒤집히고("belly showing" 탓) ③ 큰턱이 다시 Lucanus 처럼 갈라졌다.
그래서 **새 성충 시트 전체**(바닥선 지운 것)를 붙이고 "이 시트 그대로, 재질만"으로 바꾼다 — 자세·방향·생김새를 새로 정할 여지를 없앤다.
"""

import json
from pathlib import Path

REF = Path(r"C:\Users\Lenovo\Downloads\곤충고증\3차_알비노\_기준")
HEAD = (
    "The attached image is the finished pose sheet of this exact insect. Redraw this SAME sheet: the same three insects "
    "in exactly the same poses, positions, sizes and facing direction (all facing RIGHT, seen from the side), with exactly "
    "the same anatomy — body, mandibles, legs and antennae unchanged. Change ONLY the material and colours: "
)
TAIL = (
    " Background: plain flat dark slate-navy, no ground line, no shadow under the insects. "
    "Absolutely NO text, NO captions, NO pose names, NO labels anywhere in the image. "
    "Keep the same hand-painted storybook style; soft cool moonlight, gentle rim light, subsurface glow through the thin "
    "shell plates, cold pearl palette (pearl white, pale ice blue, soft lilac, faint rose). Wide image, same proportions "
    "as the attached sheet."
)
PEARL = "translucent pearl-white crystal with an iridescent sheen and pale ruby eyes"

items = [
    dict(title="크리스탈 왕사슴벌레 (알비노)", file="stag_giant", ref=str(REF / "stag_giant.png"),
         note="2차: 자세 이름 글자 · 2·3번 칸 왼쪽/뒤집힘 · 큰턱 끝 갈라짐. 굵은 큰턱 + 큰 이빨 하나 + 끝 한 갈래 그대로.",
         prompt=HEAD + "the whole insect becomes " + PEARL + ". The mandibles keep their thick caliper shape with ONE large "
         "inner tooth and a single pointed tip (NOT forked)." + TAIL),
    dict(title="크리스탈 넓적사슴벌레 (알비노)", file="stag_flat", ref=str(REF / "stag_flat.png"),
         note="2차: 자세 이름 글자 · 큰턱이 가늘고 갈라짐 · 3번 칸 위에서 본 모습. 납작한 몸 + 곧은 톱니 큰턱 + 짧은 꺾인 더듬이 그대로.",
         prompt=HEAD + "the whole insect becomes " + PEARL + ". Keep the very flat wide body, the long nearly straight "
         "mandibles with a row of small inner teeth, and the short elbowed antennae." + TAIL),
    dict(title="크리스탈 두점박이사슴벌레 (알비노)", file="stag_twospot", ref=str(REF / "stag_twospot.png"),
         note="2차: 세 칸 모두 왼쪽 · 3번 칸 뒤집힘 · 루비가 머리에도. 루비는 앞가슴 양옆의 검은 점 자리 두 개뿐.",
         prompt=HEAD + "the whole insect becomes " + PEARL + ". The two small black dots on the sides of the pronotum (the "
         "thorax plate behind the head) become two small ruby cabochons, exactly where the dots are — one visible ruby per "
         "insect in this side view, NO other gems on the head or wing covers." + TAIL),
]
spec = dict(
    title="곤충 고증 3차 — 알비노 스킨 다시 (2026-10-21)",
    saveDir=r"C:\Users\Lenovo\Downloads\곤충고증\3차_알비노",
    intro="그림 복사 → 프롬프트 복사만(사진 없음). 첨부 그림은 이번에 새로 넣은 그 종의 성충 시트 — 재질만 바꿔 다시 그리게 한다. "
    r"근거: D:\coding\BugChamp\docs\art_prompts_bug_accuracy.md",
    items=items,
)
out = Path(__file__).with_name("art_prompts_bug_accuracy_round3.json")
out.write_text(json.dumps(spec, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"{len(items)}장 → {out}")
