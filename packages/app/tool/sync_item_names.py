"""문서의 아이템 이름을 items.json 에 맞춘다.

이름을 세 곳(JSON·프롬프트 문서·기획서)에 손으로 적어두니 **고칠 때마다
한 곳이 빠졌다**(정강이받이가 프롬프트에서만 지워지고 기획서에 남는 식).
JSON 을 진실로 두고 문서를 맞춘다.
"""
import io
import json
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SLOT_KO = {"tool": "채집도구", "hat": "모자", "top": "상의", "bottom": "하의",
           "shoes": "신발", "necklace": "목걸이", "ring": "반지", "box": "채집함"}
TIERS = ["grass", "wood", "leather", "copper", "iron",
         "silver", "gold", "chitin", "carapace", "amber"]

d = json.load(io.open("packages/app/assets/data/items.json", encoding="utf-8"))
ko = {s["slot"]: [n["ko"] for n in s["names"]] for s in d["slots"]}

# ── 1) 프롬프트 문서: 경로로 해당 줄을 찾아 이름만 갈아끼운다 ──
p = "docs/art_prompts_equipment.md"
s = io.open(p, encoding="utf-8").read()
fixed = 0
for slot, names in ko.items():
    for i, t in enumerate(TIERS):
        path = f"assets/images/items/{slot}_{t}.webp"
        pat = re.compile(r"^\*\*(.+?)\*\* — `" + re.escape(path) + "`", re.M)
        m = pat.search(s)
        if m and m.group(1) != names[i]:
            print(f"  프롬프트  {m.group(1)} → {names[i]}")
            s = s[:m.start(1)] + names[i] + s[m.end(1):]
            fixed += 1
io.open(p, "w", encoding="utf-8", newline="\n").write(s)

# ── 2) 기획서: 부위별 이름 나열 줄을 통째로 다시 쓴다 ──
p2 = "docs/design_character.md"
s2 = io.open(p2, encoding="utf-8").read()
for slot, names in ko.items():
    joined = " · ".join(names)
    # "| ...(부위 이름)... | 담당 | 이름1 · 이름2 … |" 형태의 줄을 찾는다.
    pat = re.compile(
        r"^(\|[^|\n]*" + SLOT_KO[slot] + r"[^|\n]*\|[^|\n]*\|)[^|\n]*\|$", re.M
    )
    m = pat.search(s2)
    if m and joined not in m.group(0):
        print(f"  기획서    {SLOT_KO[slot]} 줄 갱신")
        s2 = s2[:m.start()] + m.group(1) + " " + joined + " |" + s2[m.end():]
        fixed += 1
io.open(p2, "w", encoding="utf-8", newline="\n").write(s2)

print(f"\n{fixed}곳 맞췄습니다 (기준: items.json)")
