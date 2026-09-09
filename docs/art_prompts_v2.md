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

## STEP 15 · 잿불 능선 배경 ✅ **완료**
저장: `packages/app/assets/images/regions/ember_ridge.webp` · 비율 **16:9**
```
Wide 16:9 landscape game background. A volcanic ridge at dusk, cooling lava cracks glowing molten orange between dark basalt rocks, drifting ash motes and heat haze, scorched sparse shrubs, distant hazy mountains, layered depth, open uncluttered middle ground for gameplay, warm ominous but cozy mood. Style: cozy naturalist cartoon, semi-realistic stylized, warm dusk lighting with ember glow, hand-painted storybook texture, charcoal and molten orange palette with dusty gold sky, mobile game background art, high detail. no text, no watermark, no logo, no UI.
```

## STEP 16 · 잿불 능선 보스 (잿불의 군주) ✅ **완료**
저장: `packages/app/assets/images/bosses/ember_ridge.webp` · 비율 **1:1**
```
Square 1:1 image. A giant volcanic fire beetle sovereign boss, heavy charcoal-black armored shell with glowing molten orange cracks running along the plates, ember sparks rising from its back, thick mandibles heated red at the tips, menacing but stylized and friendly, side view facing left, full body, centered on a plain flat pastel background for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, warm ember lighting with orange rim light, hand-painted storybook texture, charcoal and molten orange palette, clean readable silhouette, mobile game boss art, high detail. no text, no watermark, no logo, no signature, no UI.
```

공격·사망 프레임도 들어왔다(2x2 시트 → 4등분): `bosses/ember_ridge_attack_1.webp`
`_attack_2.webp` `_death_1.webp` `_death_2.webp`

> ⚠️ **중립 idle 포즈가 시트에 없어서** 기본 그림(`ember_ridge.webp`)에 곧추선
> `attack_2` 를 그대로 썼다. 평상시와 벼르는 자세가 같다는 뜻이라, 나중에
> 여유가 되면 서 있는 포즈 한 장을 따로 뽑아 덮어쓰면 된다.

> ⚠️ 위 프롬프트는 **왼쪽을 보게** 뽑는다 → `run_config.json` 의
> `ember_ridge.bossFlip` 은 **false** 여야 한다. 뽑힌 그림이 오른쪽을 보면
> 그 값을 `true` 로 바꾼다(캐릭터는 늘 화면 왼쪽에 선다).

---

## STEP 17 · 몬스터 20종 — **생물로, 4자세 시트 한 번에** ✅ 완료(2026-09-09)

> 2026-09-09 확정. 그전까지 때리는 대상이 **나무 덩어리·수풀 덩어리**(정물)였다.
> 그런데 화면에서 벌어지는 일은 전부 전투다 — 체력바가 붙고, 반격을 하고,
> 치명타가 터지고, 정예가 나오고, 곤충 셋이 달려들어 두들긴다.
> **행동은 전투인데 대상만 정물**이라 "몬스터가 아닌데?"로 읽혔다.
> 나무·바위라는 정체성은 그대로 두고 **눈·입·팔다리를 달아 생물로** 만든다.
> 이름도 「~깨비」(ko) / 「~ling」(en) / 「~の精」(ja) 로 통일했다.

### ⚠️ 대기 그림을 따로 뽑지 않는다
처음엔 "대기 1장 → 그걸 첨부해 모션 시트" 2단계로 잡았는데, 20종이면
**40번**을 돌려야 한다. **한 번에 2x2 시트로 네 자세를 다 뽑는다** — 같은
생성 안에서 나오므로 일관성도 오히려 더 좋다.

네 칸이 코드가 쓰는 네 상태와 정확히 맞는다:

| 칸 | 저장 파일 | 언제 나오나 |
|---|---|---|
| 좌상 | `<id>.webp` | 평소(대기) |
| 우상 | `<id>_attack_1.webp` | 나를 물러 **덤벼드는** 순간 |
| 좌하 | `<id>_attack_2.webp` | 물고 **되돌아가는** 자세 |
| 우하 | `<id>_hurt_1.webp` | 내가 때려서 **움찔**할 때 |

> ⚠️ 재생은 `attack_1 → attack_2` 순이다. **1번이 나가는 타격, 2번이 복귀**다.
> (보스 시트는 `1=내리치기 / 2=곧추서기` 라 반대로 헷갈리기 쉽다.)
> ⚠️ **사망 자세는 필요 없다.** 쓰러질 때 코드가 회전+페이드를 준다.
> 그림을 넣으면 그 회전이 위에 겹쳐 두 번 쓰러지는 것처럼 보인다.
> ⚠️ 네 칸을 **각자 트림하면 안 된다** — 여백이 달라 재생할 때 튄다.
> 합집합 bbox 로 함께 자른다(제가 처리한다).

> 저장: `packages/app/assets/images/habitats/` · 시트 비율 **1:1** · 배경 제거.
> 일부만 넣어도 된다 — 없는 자세는 조용히 대기 그림으로 내려간다.

> ✅ **20종 80장 전부 들어왔다**(2026-09-09).
> ⚠️ 뽑힌 그림이 **오른쪽을 보고 있어** 넣을 때 좌우반전했다. 적은 화면
> 오른쪽에 서서 **왼쪽(플레이어)** 을 봐야 한다 — 반대면 덤벼드는 게
> 물러나는 것처럼 보인다. 다시 뽑을 땐 방향을 먼저 확인할 것.
> 확인은 **개발자 모드 → 몬스터 → 몬스터·보스 그림/모션 보기**.

### 참나무 숲

**나무깨비** — `habitats/tree.webp`
```
Square 1:1 image. A small round tree spirit creature: a leafy oak sapling whose trunk is its body, bark face, two stubby root legs, leafy crown like hair, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**그루터기깨비** — `habitats/stump.webp`
```
Square 1:1 image. A tree stump spirit creature: a mossy stump body with growth rings forming a face pattern, short root arms, tiny mushrooms on its shoulder, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**통나무깨비** — `habitats/log_pile.webp`
```
Square 1:1 image. A stacked-log spirit creature: three cut logs balanced as head, torso and legs, pale cut ends like eyes and mouth, bark skin, wobbling, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**고사리깨비** — `habitats/fern.webp`
```
Square 1:1 image. A fern spirit creature: a round mossy body crowned with curling fern fronds, frond arms unfurling, leafy tail, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**도토리깨비** — `habitats/acorn.webp`
```
Square 1:1 image. A tiny acorn spirit creature: a plump acorn body with its textured cap worn as a hat, oak-leaf wings on its back, small and cheeky, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

### 계곡 물가

**바위깨비** — `habitats/rock.webp`
```
Square 1:1 image. A mossy boulder spirit creature: a rounded grey stone body with green moss patches like eyebrows and hair, stubby pebble limbs, sturdy, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**갈대깨비** — `habitats/reed.webp`
```
Square 1:1 image. A reed spirit creature: a slender bundle of reeds forming a swaying body, fluffy brown seed heads as its head, thin grass arms, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**자갈깨비** — `habitats/pebble.webp`
```
Square 1:1 image. A pebble spirit creature: a cluster of smooth river stones stacked into a small round body, wet glossy sheen, water dripping, stubby stone limbs, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**유목깨비** — `habitats/driftwood.webp`
```
Square 1:1 image. A driftwood spirit creature: a bleached twisted branch body with smooth weathered grain, knot-hole eyes, long crooked driftwood arms, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

### 풀숲 초원

**꽃깨비** — `habitats/flower.webp`
```
Square 1:1 image. A wildflower spirit creature: a bushy round body of colorful blossoms, green leaf arms, a flower crown, cheerful, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**버섯깨비** — `habitats/mushroom.webp`
```
Square 1:1 image. A toadstool spirit creature: a big red white-spotted mushroom cap as its head over a plump pale stalk body, stubby legs, mischievous, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**억새깨비** — `habitats/tall_grass.webp`
```
Square 1:1 image. A pampas grass spirit creature: a tall tuft of silver-tipped grass forming a shaggy body, straw-toned, swaying, thin grass-blade arms, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**토끼풀깨비** — `habitats/clover.webp`
```
Square 1:1 image. A clover spirit creature: a small round body of bright green clover leaves, one white clover flower on its head like a puff, hopping, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**민들레깨비** — `habitats/dandelion.webp`
```
Square 1:1 image. A dandelion spirit creature: a yellow bloom face on a slim green stem body, a white seed-head puff shoulder, seeds drifting off it, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

### 야산 밤숲

**수정깨비** — `habitats/crystal_rock.webp`
```
Square 1:1 image. A crystal rock spirit creature: a dark grey stone body with pale blue crystal shards growing from its back and brow, faint inner glow in its eyes, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**고사목깨비** — `habitats/dead_tree.webp`
```
Square 1:1 image. A dead tree spirit creature: a bare twisted trunk body with peeling grey bark, leafless branch arms like claws, hollow glowing eyes, gaunt, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**이끼깨비** — `habitats/moss_boulder.webp`
```
Square 1:1 image. A moss-covered boulder spirit creature: a big round stone almost fully blanketed in thick deep-green moss, small ferns sprouting on its head, slow and heavy, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

### 잿불 능선

**현무암깨비** — `habitats/basalt.webp`
```
Square 1:1 image. A basalt spirit creature: a body built of hexagonal dark basalt columns of uneven height, sharp geometric shoulders, blocky stone limbs, stoic, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**불티깨비** — `habitats/ember_vent.webp`
```
Square 1:1 image. An ember spirit creature: a charred black rock body split by molten orange cracks, ember sparks rising from its shoulders, glowing eyes, restless, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

**잿더미깨비** — `habitats/ash_mound.webp`
```
Square 1:1 image. An ash spirit creature: a soft grey mound of ash forming a slouched body, a few glowing orange embers buried in it, a thin wisp of smoke from its head, drowsy, standing on stubby little legs, two big expressive eyes, a small simple mouth, alive, a creature not an object, drawn as a 2x2 sprite sheet on a plain flat pastel background, clear even spacing between the four cells, the creature at the same size and position in each cell, side view facing left. Four poses: top-left standing calmly at rest, alert and idle; top-right lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive; bottom-left pulling back after the strike, body coiled and leaning away to the right, recovering; bottom-right flinching from being hit, squeezing its eyes shut, body squashed and recoiling backward. Consistent creature in all four. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy palette, clean readable silhouette, mobile game enemy art, high detail. no text, no watermark, no logo, no signature, no UI.
```

---
## (선택) 나중에 — 도감 곤충 카드 20종
게임 화면엔 필수 아님. 도감/보관함 꾸밀 때 곤충 20종을 **3/4 위에서 본 뷰**로 만들어
`packages/app/assets/images/bugs/<종id>.webp` 로 넣고, `species.json` 각 항목에 `"image": "<종id>.webp"` 추가하면 표시됩니다.
필요할 때 종 목록·개별 묘사를 정리해 드릴게요.
