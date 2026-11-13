# 연구소 · 심연 연구소 그림 (1.0.28, 2026-11-12) — 9장

그림이 없으면 화면은 Material 아이콘으로 대신 그린다(파일을 넣기만 하면 바로 바뀐다, 코드 수정 없음).
정사각 1:1 PNG(1024px) → webp(256px)로 바꿔 아래 경로(`packages/app/` 아래)에 둔다.

화풍이 두 가지다 — 같은 자리에 있는 그림과 맞춘다:
- **A. 재화·탭 아이콘**(`assets/images/ui/icon/`) — 배지 없이 물건만, **배경 투명**. 기준 그림 `assets/images/ui/icon/growth.webp`.
- **B. 연구 아이콘**(`assets/images/ui/research/`) — **둥근 배지 + 두꺼운 테** 안에 소재. 기준 그림 `assets/images/ui/research/antenna.webp`.
  심연 연구 6종은 같은 배지 모양에 **안쪽을 짙은 보라**로 둬서 일반 연구(크림색)와 한눈에 갈리게 한다.

---

## A. 재화·탭 아이콘 (기준 그림: growth.webp)

### A1. 연구 샘플(연구 재료) — `assets/images/ui/icon/research_sample.webp`
연구 화면 위 보유량 · 연구 비용 줄에 뜬다(지금은 하늘색 플라스크 아이콘).
```
Use the attached image only as the art style reference. Do NOT copy its subject. A single game item icon for a cozy insect-collecting mobile game: a small corked glass specimen vial with a soft cyan glow, holding a tiny preserved green leaf and a little amber insect wing, a paper label tied with twine around the neck, a research sample collected in the forest. Centered, filling about 80% of the frame, one clear bold silhouette readable at 16 pixels. Style: glossy stylized mobile game icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream, with a cool cyan glass accent), semi-realistic painterly shading, soft rim light, thick warm brown outlines, high detail. Transparent background, no badge, no frame. Square 1:1 image. no text, no letters, no numbers, no labels, no watermark, no logo.
```

### A2. 심연 포자(심연 재화) — `assets/images/ui/icon/abyss_spore.webp`
```
Use the attached image only as the art style reference. Do NOT copy its subject. A single game item icon for a cozy insect-collecting mobile game: a small cluster of three glowing lavender fungal spores floating above a dark violet mushroom cap, tiny sparkles around them, a mysterious deep-cave currency. Centered, filling about 80% of the frame, one clear bold silhouette readable at 16 pixels. Style: glossy stylized mobile game icon, cozy naturalist storybook palette with a deep abyss accent (moss green, warm bark brown, soft cream, plus deep violet and glowing lavender), semi-realistic painterly shading, soft rim light, thick warm brown outlines, high detail. Transparent background, no badge, no frame. Square 1:1 image. no text, no letters, no numbers, no labels, no watermark, no logo.
```

### A3. 연구소 '심연' 탭 — `assets/images/ui/icon/research_abyss.webp`
```
Use the attached image only as the art style reference. Do NOT copy its subject. A single game tab icon for a cozy insect-collecting mobile game: a round glass laboratory flask filled with swirling deep violet liquid, one glowing lavender spore floating inside, a faint violet mist rising from the mouth, a research lab of the abyss. Centered, filling about 80% of the frame, one clear bold silhouette readable at 28 pixels. Style: glossy stylized mobile game icon, cozy naturalist storybook palette with a deep abyss accent (warm bark brown, soft cream, plus deep violet and glowing lavender), semi-realistic painterly shading, soft rim light, thick warm brown outlines, high detail. Transparent background, no badge, no frame. Square 1:1 image. no text, no letters, no numbers, no labels, no watermark, no logo.
```

### A4. 분해 버튼(채집함 곤충 상세) — `assets/images/ui/icon/disassemble.webp`
곤충·알을 눌렀을 때 나오는 '분해' 버튼 앞(20px, 지금은 갈래 아이콘). 분해하면 키틴·미네랄·수액결정이 나온다.
```
Use the attached image only as the art style reference. Do NOT copy its subject. A single game item icon for a cozy insect-collecting mobile game: a cracked open cream insect egg shell splitting into two halves, with small pieces spilling out of it — a brown chitin shell flake, a grey-blue mineral chip and a glowing honey amber sap crystal — turning a bug into crafting materials. Centered, filling about 80% of the frame, one clear bold silhouette readable at 20 pixels. Style: glossy stylized mobile game icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, thick warm brown outlines, high detail. Transparent background, no badge, no frame. Square 1:1 image. no text, no letters, no numbers, no labels, no watermark, no logo.
```

### A5. 난이도 이동 팝업 — `assets/images/ui/dlg/roadmap.webp`
로드맵에서 다른 난이도로 옮길 때 뜨는 팝업 제목 그림(30px, 지금은 반짝이 아이콘). 기준 그림 `assets/images/ui/dlg/tier_clear.webp`.
```
Use the attached image only as the art style reference. Do NOT copy its subject. A single popup title icon for a cozy insect-collecting mobile game: a small rolled-open parchment map with a dotted trail winding up through three little forest hills to a tiny red flag at the top, a brass compass resting on its corner, choosing which difficulty to travel to. Centered, filling about 85% of the frame, one clear bold silhouette readable at 30 pixels. Style: glossy stylized mobile game icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, thick warm brown outlines, high detail. Transparent background, no badge, no frame. Square 1:1 image. no text, no letters, no numbers, no labels, no watermark, no logo.
```

### A6. 심연 엠블럼(결투 순위표 '심연' 탭) — `assets/images/ui/abyss_emblem.webp`
심연 주간 순위 머리 그림(지금은 달 아이콘). 기준 그림 `assets/images/ui/abyss_banner.webp`(색감) — 물건 아이콘처럼 하나만.
```
Use the attached image only as the color and mood reference. Do NOT copy its scene. A single emblem icon for a cozy insect-collecting mobile game: a round dark stone medallion framed by twisting tree roots, a glowing cyan-lavender abyss pit swirling in its center, two tiny glowing purple mushrooms and a teal crystal growing on the rim, the emblem of an endless underground abyss. Centered, filling about 85% of the frame, one clear bold silhouette readable at 32 pixels. Style: glossy stylized mobile game icon, deep violet, teal and glowing lavender with warm bark brown roots, semi-realistic painterly shading, soft rim light, thick warm brown outlines, high detail. Transparent background, no frame. Square 1:1 image. no text, no letters, no numbers, no labels, no watermark, no logo.
```

---

## B. 심연 연구 아이콘 6장 (기준 그림: antenna.webp)

공통 앞: `Use the attached image only as the art style reference: keep the same round badge with a thick light cream rim and the same painterly style. Do NOT copy its subject. Make the inner disc of the badge a deep violet night-cave color instead of cream. A single research icon for a cozy insect-collecting mobile game:`

공통 끝: `Centered inside the badge, one clear bold silhouette readable at 30 pixels. Style: glossy stylized mobile game icon, warm bark brown outlines, glowing lavender and soft cyan highlights on the deep violet disc, semi-realistic painterly shading, soft rim light, high detail. Transparent background outside the badge. Square 1:1 image. no text, no letters, no numbers, no labels, no watermark, no logo.`

| # | 연구 | 저장 경로 | 소재(앞·끝 사이에 넣는다) |
|---|---|---|---|
| B1 | 심연 지름길 | `assets/images/ui/research/abyssShortcut.webp` | a glowing lavender portal ring set in dark stone, with a short stone staircase leading straight down through it, a shortcut deeper into the cave |
| B2 | 빠른 하강 | `assets/images/ui/research/abyssFastFloor.webp` | a small brown beetle diving headfirst downward with motion streaks, a glowing lavender double downward chevron behind it |
| B3 | 변이 길들이기 | `assets/images/ui/research/mutationTame.webp` | a small twisted glowing violet crystal shard gently bound by a soft green leafy vine leash, the wild mutation calmed |
| B4 | 결정 정제 | `assets/images/ui/research/crystalRefine.webp` | a faceted cyan-violet abyss crystal resting on a tiny brass refining stand, one bright drop of light falling from it, polished and pure |
| B5 | 포자 감각 | `assets/images/ui/research/sporeSense.webp` | a pair of curious insect antennae sensing glowing lavender spores drifting nearby, faint curved sensing wave lines |
| B6 | 심연 휴식 | `assets/images/ui/research/abyssRest.webp` | a small beetle sleeping curled on a soft moss bed in a cozy cave nook, a few gold coins beside it and a crescent moon glow |

완성 예(B1):
> Use the attached image only as the art style reference: keep the same round badge with a thick light cream rim and the same painterly style. Do NOT copy its subject. Make the inner disc of the badge a deep violet night-cave color instead of cream. A single research icon for a cozy insect-collecting mobile game: a glowing lavender portal ring set in dark stone, with a short stone staircase leading straight down through it, a shortcut deeper into the cave. Centered inside the badge, one clear bold silhouette readable at 30 pixels. Style: glossy stylized mobile game icon, warm bark brown outlines, glowing lavender and soft cyan highlights on the deep violet disc, semi-realistic painterly shading, soft rim light, high detail. Transparent background outside the badge. Square 1:1 image. no text, no letters, no numbers, no labels, no watermark, no logo.
