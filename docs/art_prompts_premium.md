# Bug Champ — 고급 아트 프롬프트 (Gemini · 복붙용)

> 캐릭터 화풍(코지 자연주의 스토리북)에 **톤을 맞춘 고급 버전**입니다. 각 프롬프트는 **스타일이 이미 포함**되어 그대로 붙여넣으면 됩니다.
>
> **화풍 통일 팁(중요):** 각 이미지 생성 시 **완성된 캐릭터 이미지를 첨부**하고 프롬프트를 넣으면 톤·질감이 맞습니다.
> **비율:** 배경 = **16:9(가로)**, 서식지·보스·아이콘 = **1:1(정사각)**.
> **로고:** [Google AI Studio](https://aistudio.google.com) Imagen이면 코너 로고 없음(추천). Gemini 앱이면 찍혀도 제가 지웁니다.
> **누끼:** 서식지·보스·아이콘은 "plain flat pastel background"로 뽑으면 제가 배경 제거·정규화합니다.
> 만든 이미지는 **Downloads에 두고 "○○ 만들었어"** → 제가 처리·배포.

---

## A. 배경 (regions) · 16:9
저장: `packages/app/assets/images/regions/<id>.webp`

### A-1. 참나무 숲 `oak_forest.webp`
```
Wide 16:9 landscape game background: a lush ancient oak forest clearing bathed in warm afternoon sunlight filtering through a dense canopy, a soft mossy dirt path running across the middle, ferns, clover and little glowing mushrooms in the foreground, moss-draped roots, layered parallax depth with a distant misty blue tree line, dust motes and gentle god rays, an open uncluttered middle band for gameplay. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm golden-hour lighting and gentle rim light, painterly texture, clean confident linework, muted earthy forest palette of moss green, honey amber and warm bark brown, high detail, polished premium mobile game background art. no text, no watermark, no logo, no UI.
```

### A-2. 계곡 물가 `valley_stream.webp`
```
Wide 16:9 landscape game background: a serene mountain valley stream, clear shallow water flowing over smooth pebbles with soft reflections and gentle ripples, mossy rounded boulders and lush ferns along the banks, cool fresh morning daylight with soft mist, dragonflies drifting, layered parallax depth with distant pine ridges, an open uncluttered middle band for gameplay. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft natural lighting and gentle rim light, painterly texture, clean confident linework, muted earthy palette with cool teal water accents, high detail, polished premium mobile game background art. no text, no watermark, no logo, no UI.
```

### A-3. 풀숲 초원 `grass_field.webp`
```
Wide 16:9 landscape game background: a sunny rolling grassland meadow, tall swaying grass and scattered wildflowers catching warm light, a few dandelion seeds floating, a bright open blue sky with soft fluffy clouds, distant hills fading into haze, layered parallax depth, an open uncluttered middle band for gameplay. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm afternoon lighting, painterly texture, clean confident linework, bright fresh green and floral palette with honey accents, high detail, polished premium mobile game background art. no text, no watermark, no logo, no UI.
```

### A-4. 야산 밤숲 `night_mountain.webp`
```
Wide 16:9 landscape game background: a moonlit mountain forest at night, drifting glowing fireflies and soft bokeh, cool blue shadows warmed by a distant lantern glow, twisted old trees and gnarled roots, subtle drifting mist, a faint star-filled sky, layered parallax depth, an open uncluttered middle band for gameplay, mysterious but cozy mood. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, moonlight with warm amber rim light, painterly texture, clean confident linework, deep blue palette with glowing amber highlights, high detail, polished premium mobile game background art. no text, no watermark, no logo, no UI.
```

---

## B. 서식지 = 몬스터 (habitats) · 1:1 · 배경 제거용
저장: `packages/app/assets/images/habitats/<종류>.webp`
> 사물이 아니라 **눈·표정·팔다리가 있는 생물**로 그립니다(보스처럼 "귀엽지만 위협적"). 캐릭터/보스를 왼쪽(적 방향)으로 바라봄.
> 공통 스타일 문구는 각 프롬프트에 포함. 화풍 통일 위해 **캐릭터나 보스 이미지를 첨부**하면 좋습니다.

### B-1. 나무 몬스터 `tree.webp`
```
Square 1:1 game monster: a small living oak tree-creature (grumpy tree spirit / mini treant), a grouchy face formed in its gnarled bark with glowing amber eyes, short stubby root-legs, leafy branch-arms, patches of moss and a tiny mushroom on its shoulder, cute but cranky. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm golden-hour lighting and gentle rim light, painterly texture, clean confident linework, rounded friendly forms, muted earthy forest palette, expressive cute-but-menacing creature, high detail, polished premium mobile game monster art. Side view facing left, full body, centered on a plain flat pastel background for easy cutout. no text, no watermark, no logo, no signature, no UI.
```

### B-2. 식충 꽃 몬스터 `flower.webp`
```
Square 1:1 game monster: a carnivorous flower-creature, a large colorful blossom opening into a toothy grinning maw with a little tongue, a thick green leafy stem-body and two vine arms, dewy glossy petals, cute but snappy. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm golden-hour lighting and gentle rim light, painterly texture, clean confident linework, rounded friendly forms, fresh green and floral palette, expressive cute-but-menacing creature, high detail, polished premium mobile game monster art. Side view facing left, full body, centered on a plain flat pastel background for easy cutout. no text, no watermark, no logo, no signature, no UI.
```

### B-3. 바위 골렘 몬스터 `rock.webp`
```
Square 1:1 game monster: a small mossy rock golem-creature, a round boulder body with a craggy grumpy face and glowing crystal eyes, little stubby stone arms and legs, patches of green moss and small pebbles, sturdy and stubborn. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm golden-hour lighting and gentle rim light, painterly texture, clean confident linework, rounded friendly forms, muted earthy palette with cool grey stone, expressive cute-but-menacing creature, high detail, polished premium mobile game monster art. Side view facing left, full body, centered on a plain flat pastel background for easy cutout. no text, no watermark, no logo, no signature, no UI.
```

### B-4. 그루터기 몬스터 `stump.webp`
```
Square 1:1 game monster: an old tree-stump creature, a sleepy grumpy face carved in its concentric growth rings with half-closed glowing eyes, tiny red mushrooms and moss on top like eyebrows, little knobby root feet and short bark arms, mossy and drowsy. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm golden-hour lighting and gentle rim light, painterly texture, clean confident linework, rounded friendly forms, muted earthy forest palette, expressive cute-but-menacing creature, high detail, polished premium mobile game monster art. Side view facing left, full body, centered on a plain flat pastel background for easy cutout. no text, no watermark, no logo, no signature, no UI.
```

### B-5. 버섯 몬스터 `mushroom.webp`
```
Square 1:1 game monster: a red-capped toadstool mushroom-creature (myconid) with creamy white spots, a cute-creepy face under the cap with round glowing eyes, short stubby stem legs and little arms, faintly glowing gills and a small puff of spores, mischievous. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm golden-hour lighting and gentle rim light, painterly texture, clean confident linework, rounded friendly forms, muted earthy palette with warm red cap, expressive cute-but-menacing creature, high detail, polished premium mobile game monster art. Side view facing left, full body, centered on a plain flat pastel background for easy cutout. no text, no watermark, no logo, no signature, no UI.
```

> **선택(더 살리기):** 각 몬스터를 만든 뒤 그 이미지를 첨부해 **부서지는/쓰러지는 2포즈 시트**(멀쩡→퍽 터지며 쓰러짐)를 만들면 파괴 애니로 넣어드립니다(`<종류>_death_1/2.webp`).

---

## C. 보스 (bosses) · 1:1 · 배경 제거용
저장: `packages/app/assets/images/bosses/<지역id>.webp`

### C-1. 참나무 숲 보스 — 사슴벌레 군주 `oak_forest.webp`
```
Square 1:1 game boss: a giant majestic ancient stag beetle, bark-armored mossy carapace with glowing amber eyes, huge powerful curved mandibles, sturdy spiked legs, imposing yet stylized and friendly, side view facing left, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm golden-hour lighting and gentle rim light, painterly texture, clean confident linework, muted earthy forest palette with amber glow, high detail, polished premium mobile game boss art. no text, no watermark, no logo, no signature, no UI.
```

### C-2. 계곡 물가 보스 — 물장군 `valley_stream.webp`
```
Square 1:1 game boss: a giant armored water bug, flat glossy brown shield-like body dripping with water droplets, strong raptorial forelegs raised menacingly, sharp eyes, imposing yet stylized and friendly, side view facing left, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft natural lighting and gentle rim light, painterly texture, clean confident linework, muted earthy palette with cool teal water accents, high detail, polished premium mobile game boss art. no text, no watermark, no logo, no signature, no UI.
```

### C-3. 풀숲 초원 보스 — 사마귀 여왕 `grass_field.webp`
```
Square 1:1 game boss: a giant elegant praying mantis queen, slender vivid green body, raptorial arms raised gracefully like blades, a regal crown-like triangular head with keen eyes, imposing yet stylized and friendly, side view facing left, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm afternoon lighting and gentle rim light, painterly texture, clean confident linework, fresh green palette with honey accents, high detail, polished premium mobile game boss art. no text, no watermark, no logo, no signature, no UI.
```

### C-4. 야산 밤숲 보스 — 말벌 군주 `night_mountain.webp`
```
Square 1:1 game boss: a giant hornet sovereign, bold orange-yellow and black striped body, translucent shimmering wings, sharp stinger, a faint amber glow, menacing yet stylized and friendly, side view facing left, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, moody moonlit lighting with warm amber rim light, painterly texture, clean confident linework, deep blue and amber palette, high detail, polished premium mobile game boss art. no text, no watermark, no logo, no signature, no UI.
```

> **보스 애니메이션(선택):** 보스 idle을 만든 뒤 **그 이미지를 첨부**해 캐릭터처럼 포즈 시트(집게 내리침 / 치켜듦 / 비틀 / 뒤집힘)를 만들면 제가 잘라 넣습니다. (아래 예: 참나무 보스)
```
Use the attached boss creature as the exact reference (same design, colors, style). Draw a model sheet of the SAME boss in 4 poses, all at the same size on a plain flat pastel background, side view facing left, clear gaps between poses:
1) slamming its huge pincers/mandibles forward in a powerful strike
2) rearing up with pincers raised high, menacing
3) staggering and wounded, about to collapse
4) flipped over on its back with legs up in the air, defeated
Consistent creature and art style in all four. no text, no logo, no watermark.
```

---

## D. 아이콘 (재료·재화) · 1:1 · 배경 제거용
저장: `packages/app/assets/images/materials/<id>.webp` (훅은 제가 추가)
> 4개 재료는 **한 장에 4칸(2×2)** 로 뽑아도 됩니다(제가 잘라 씁니다). 낱개면 각각 1:1.

### D. 재료 4종 시트 (2×2 한 장)
```
Square 1:1 image, a clean 2x2 grid of four game resource icons on a plain flat pastel background, even spacing, each icon centered in its cell at the same size, glossy collectible item style with soft rim light and a subtle drop highlight:
- top-left: a shiny amber chitin shard (곤충 외골격 조각), faceted translucent brown
- top-right: a raw blue-grey mineral crystal cluster (미네랄)
- bottom-left: a glowing golden sap resin droplet (수액결정), honey-like and translucent
- bottom-right: a cute jar of green insect jelly (곤충젤리) with a glossy wobble
Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon with rich hand-painted detail, soft warm lighting and gentle rim light, clean confident linework, high detail, polished premium mobile game item icon art, readable silhouettes. no text, no watermark, no logo, no UI.
```
> 잘린 결과 파일명(제가 저장): `chitin.webp / mineral.webp / sap.webp / jelly.webp`

### (선택) 재화 아이콘
```
Square 1:1 game currency icon: a stack of shiny golden coins with a small beetle emblem, glossy, soft rim light, centered on a plain flat pastel background. Style: cozy naturalist storybook illustration, semi-realistic stylized cartoon, clean linework, high detail, polished premium mobile game icon. no text, no watermark, no logo, no UI.
```

---

## 우선순위 추천
1. **참나무 숲 배경**(`oak_forest.webp`) — 씬이 즉시 살아남
2. **서식지 5종**(나무·식물·바위·그루터기·버섯)
3. **참나무 숲 보스**(사슴벌레) → 이후 보스 포즈 시트
4. 나머지 지역 배경·보스 → 재료 아이콘
