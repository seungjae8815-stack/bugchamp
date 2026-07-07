# Bug Champ — 아트 생성 (Gemini용 · 복붙 순서 체크리스트)

> **이 파일 하나만 보시면 됩니다.** 각 STEP 프롬프트는 **공통 스타일이 이미 포함**되어 그대로 복붙하면 됩니다.
> **Gemini(구글) 이미지 생성용**으로 정리했습니다(Midjourney 플래그 `--ar` 등은 뺐어요).
> 위에서부터 하나씩 만들어 저장 경로에 넣으면 이모지 대신 자동 표시됩니다.
> (이전 `art_prompts.md`는 도감용 곤충 카드 — 지금 게임 화면엔 불필요)

## ⚠️ Gemini 로고/워터마크 안 나오게 (꼭 읽기)
- **가장 확실한 방법: [Google AI Studio](https://aistudio.google.com) 의 Imagen 사용.**
  → 코너에 붙는 **눈에 보이는 반짝이 로고가 없습니다**(추적용 SynthID 워터마크는 눈에 안 보이므로 게임엔 무방).
- **Gemini 앱(gemini.google.com)** 으로 만들면 이미지 **우측 하단에 컬러 ✦ 로고**가 찍힙니다 → **잘라내기(크롭)로 제거**:
  - **캐릭터·서식지·보스**는 어차피 **배경 제거(rembg 등)** 를 하니, 피사체를 **중앙에 크게** 두면 코너 로고는 배경과 함께 지워집니다.
  - **배경(regions)** 만 투명이 아니므로 → 코너 살짝 **크롭**하거나 여백 넉넉히 뽑아 자르기.
- 프롬프트에는 항상 **"no text, no watermark, no logo, no UI"** 를 넣어뒀습니다(앱이 나중에 찍는 로고는 프롬프트로 못 막지만, 그림 안에 글자/로고가 생기는 건 줄여줍니다).

## 공통 안내
- **넣는 위치**: 각 STEP의 `저장:` 경로 그대로. 파일명은 **정확히** 그대로. 최종 **WebP** 권장(PNG도 OK).
- **비율**: Gemini/AI Studio 에서 **비율(aspect ratio) 설정**을 — 캐릭터·서식지·보스 = **정사각(1:1)**, 배경 = **가로(16:9)**. (프롬프트 앞에도 문구로 넣어놨어요.)
- **투명 배경**(캐릭터·서식지·보스): "plain flat background"로 뽑은 뒤 **배경 제거**(무료 `rembg`, remove.bg, 포토샵). 배경(regions)만 투명 아님.
- **일관성(선택)**: STEP 1 캐릭터를 마음에 들게 뽑은 뒤, Gemini에 **그 이미지를 첨부**하고 "이 화풍/톤으로" 라고 하면 이후 것들이 통일됩니다.
- 넣고 나서 **앱 다시 실행(재빌드)** 하면 반영됩니다.

---

# 1지역(참나무 숲) — 먼저 이것부터 (STEP 1~8)

## STEP 1 · 캐릭터 (화풍 기준)
저장: `packages/app/assets/images/character/idle.webp` · 비율 **1:1**
```
Square 1:1 image. A cute bug-collector adventurer standing in an idle pose, side view facing right, holding a butterfly net resting on the shoulder, a small satchel of glass jars at the hip, wearing an explorer hat, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette, clean readable silhouette, mobile game character art, high detail. no text, no watermark, no logo, no signature, no UI.
```

## STEP 2 · 참나무 숲 배경
저장: `packages/app/assets/images/regions/oak_forest.webp` · 비율 **16:9**
```
Wide 16:9 landscape game background. A lush oak forest clearing, warm afternoon sunlight through the canopy, a mossy dirt path across the middle, ferns bushes and small mushrooms, layered depth with a distant misty tree line, open uncluttered middle ground for gameplay. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette, mobile game background art, high detail. no text, no watermark, no logo, no UI.
```

## STEP 3 · 서식지: 나무
저장: `packages/app/assets/images/habitats/tree.webp` · 비율 **1:1**
```
Square 1:1 image. A small round leafy oak sapling tree with a sturdy brown trunk, side view, rooted on the ground, a game object, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette, clean readable silhouette, mobile game art, high detail. no text, no watermark, no logo, no signature, no UI.
```

## STEP 4 · 서식지: 바위
저장: `packages/app/assets/images/habitats/rock.webp` · 비율 **1:1**
```
Square 1:1 image. A mossy grey boulder cluster with small pebbles and patches of green moss, side view, sitting on the ground, a game object, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette, clean readable silhouette, mobile game art, high detail. no text, no watermark, no logo, no signature, no UI.
```

## STEP 5 · 서식지: 꽃덤불
저장: `packages/app/assets/images/habitats/flower.webp` · 비율 **1:1**
```
Square 1:1 image. A bushy cluster of colorful wildflowers with green leaves, side view, growing from the ground, a game object, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette, clean readable silhouette, mobile game art, high detail. no text, no watermark, no logo, no signature, no UI.
```

## STEP 6 · 서식지: 그루터기
저장: `packages/app/assets/images/habitats/stump.webp` · 비율 **1:1**
```
Square 1:1 image. An old weathered tree stump with visible growth rings and moss, a few tiny mushrooms on the side, side view, on the ground, a game object, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette, clean readable silhouette, mobile game art, high detail. no text, no watermark, no logo, no signature, no UI.
```

## STEP 7 · 서식지: 버섯
저장: `packages/app/assets/images/habitats/mushroom.webp` · 비율 **1:1**
```
Square 1:1 image. A cluster of large red-capped toadstool mushrooms with white spots, side view, on the ground, a game object, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette, clean readable silhouette, mobile game art, high detail. no text, no watermark, no logo, no signature, no UI.
```

## STEP 8 · 참나무 숲 보스 (숲의 지배자)
저장: `packages/app/assets/images/bosses/oak_forest.webp` · 비율 **1:1**
```
Square 1:1 image. A giant majestic ancient stag beetle boss, mossy bark-armored shell, huge powerful mandibles, glowing amber eyes, imposing but friendly stylized, side view facing left, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, muted earthy forest palette, clean readable silhouette, mobile game boss art, high detail. no text, no watermark, no logo, no signature, no UI.
```

> 여기까지 넣으면 **초반(1지역) 전체가 그림으로** 보입니다. 나머지는 진행하며 만들어도 됩니다.

---

# 2~4지역 (STEP 9~14) — 서식지는 1지역 것 공용, 배경·보스만 추가

## STEP 9 · 계곡 물가 배경
저장: `packages/app/assets/images/regions/valley_stream.webp` · 비율 **16:9**
```
Wide 16:9 landscape game background. A mountain valley stream, clear shallow water flowing over smooth stones, mossy rocks and ferns, cool fresh daylight, layered depth, open uncluttered middle ground for gameplay. Style: cozy naturalist cartoon, semi-realistic stylized, soft natural lighting, hand-painted storybook texture, muted earthy palette with cool teal water, mobile game background art, high detail. no text, no watermark, no logo, no UI.
```

## STEP 10 · 계곡 물가 보스 (물가의 포식자)
저장: `packages/app/assets/images/bosses/valley_stream.webp` · 비율 **1:1**
```
Square 1:1 image. A giant water bug boss, armored flat brown body, strong raptorial forelegs raised, dripping water, menacing but stylized and friendly, side view facing left, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft natural lighting, gentle rim light, hand-painted storybook texture, muted earthy palette with cool accents, clean readable silhouette, mobile game boss art, high detail. no text, no watermark, no logo, no signature, no UI.
```

## STEP 11 · 풀숲 초원 배경
저장: `packages/app/assets/images/regions/grass_field.webp` · 비율 **16:9**
```
Wide 16:9 landscape game background. A sunny grassland meadow, tall swaying grass, scattered wildflowers, bright open blue sky with soft clouds, warm afternoon light, layered depth, open uncluttered middle ground for gameplay. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm lighting, hand-painted storybook texture, bright fresh green and floral palette, mobile game background art, high detail. no text, no watermark, no logo, no UI.
```

## STEP 12 · 풀숲 초원 보스 (초원의 여왕)
저장: `packages/app/assets/images/bosses/grass_field.webp` · 비율 **1:1**
```
Square 1:1 image. A giant elegant praying mantis queen boss, slender bright green body, raptorial arms raised gracefully, a regal crown-like head, imposing but stylized and friendly, side view facing left, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm lighting, gentle rim light, hand-painted storybook texture, fresh green palette, clean readable silhouette, mobile game boss art, high detail. no text, no watermark, no logo, no signature, no UI.
```

## STEP 13 · 야산 밤숲 배경
저장: `packages/app/assets/images/regions/night_mountain.webp` · 비율 **16:9**
```
Wide 16:9 landscape game background. A moonlit mountain forest at night, drifting glowing fireflies, cool blue shadows with warm lantern glow, twisted old trees, subtle mist, layered depth, open uncluttered middle ground for gameplay, mysterious cozy mood. Style: cozy naturalist cartoon, semi-realistic stylized, moonlight with warm accents, hand-painted storybook texture, deep blue palette with amber highlights, mobile game background art, high detail. no text, no watermark, no logo, no UI.
```

## STEP 14 · 야산 밤숲 보스 (밤의 군주)
저장: `packages/app/assets/images/bosses/night_mountain.webp` · 비율 **1:1**
```
Square 1:1 image. A giant asian hornet sovereign boss, bold orange-yellow and black body, translucent wings, faint glow, menacing but stylized and friendly, side view facing left, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, moody night lighting with warm rim light, hand-painted storybook texture, deep blue and amber palette, clean readable silhouette, mobile game boss art, high detail. no text, no watermark, no logo, no signature, no UI.
```

---

## (선택) 나중에 — 도감 곤충 카드 20종
게임 화면엔 필수 아님. 도감/보관함 꾸밀 때 곤충 20종을 **3/4 위에서 본 뷰**로 만들어
`packages/app/assets/images/bugs/<종id>.webp` 로 넣고, `species.json` 각 항목에 `"image": "<종id>.webp"` 추가하면 표시됩니다.
필요할 때 종 목록·개별 묘사를 정리해 드릴게요.
