# 보스 44마리 아트 — Gemini 프롬프트 (2026-09-14)

> 난이도마다 보스 10 + 최종보스 1 = 11마리, 네 난이도 44마리. **전부 다른 종**.
> 검증된 순서: ① 대기 원화 1장 → ② 그 그림을 **첨부**하고 3동작 스트립 → ③ 같은 방식으로 나머지 3동작.
> 한 마리 = 이미지 3장. 6동작이 한 장에 나온다.

## 왜 이 순서인가 (한 번 겪은 것)
- 6동작을 한 장에 시키면 모델이 **앞모습·뒷모습 회전표**를 그려 버린다. **한 줄에 3개**가 안전하다.
- "동작 사이를 넓게 띄워라"를 꼭 넣는다. 붙어 있으면 뿔이 옆 동작에 걸려 못 자른다.
- 배경은 **순백색 단색**으로. 빛 번짐·안개·그림자가 들어가면 배경 제거가 지저분해진다.
- 생성 후 저에게 파일을 주시면 제가 잘라서(흰색 키잉) webp 6장으로 만들어 넣습니다.

## 저장 이름 (임시 — 새 구조 id 가 정해지면 제가 옮깁니다)
```
쉬움:   e01 ~ e10, e_final
보통:   n01 ~ n10, n_final
어려움: h01 ~ h10, h_final
극한:   x01 ~ x10, x_final
```
한 마리당 3장: `e01_idle.png`, `e01_strip1.png`(공격준비·공격·피격), `e01_strip2.png`(대기·쓰러지는중·쓰러짐)

---

## 공통 스타일 (모든 프롬프트 끝에 그대로 붙어 있음)
```
Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, clean dark outline, muted earthy palette with one warm accent color, clean readable silhouette, mobile game boss art, high detail. no text, no watermark, no logo, no signature, no UI, no ground shadow.
```

## ① 대기 원화 (비율 1:1)
`{설명}` 자리에 아래 표의 설명을 넣는다.
```
Square 1:1 image. Boss monster: {설명}. Standing in a calm idle pose, side view facing LEFT, full body visible, centered, on a PLAIN FLAT SOLID WHITE background: no scenery, no gradient, no glow, no fog. Crisp clean edges for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, clean dark outline, muted earthy palette with one warm accent color, clean readable silhouette, mobile game boss art, high detail. no text, no watermark, no logo, no signature, no UI, no ground shadow.
```

## ② 스트립 1 — 공격준비 · 공격 · 피격 (비율 3:2, ①의 그림을 첨부)
```
Sprite strip of this exact creature from the attached image: same design, same colors, same painting style. EXACTLY 3 poses side by side in ONE horizontal row, ALL in SIDE VIEW facing LEFT (never front view, never back view), same scale, WIDE EMPTY WHITE GAPS between them, none touching, plain flat solid white background, no ground shadow, no text. Left: attack wind-up, rearing up with its weapon (mandibles / stinger / claws) opening wide. Middle: attack strike, lunging low and forward to the left with the weapon snapped shut. Right: hurt, flinching backward with legs splayed and eyes squinting.
```

## ③ 스트립 2 — 대기 · 쓰러지는 중 · 쓰러짐 (비율 3:2, ①의 그림을 첨부)
```
Sprite strip of this exact creature from the attached image: same design, same colors, same painting style. EXACTLY 3 poses side by side in ONE horizontal row, ALL in SIDE VIEW facing LEFT (never front view, never back view), same scale, WIDE EMPTY WHITE GAPS between them, none touching, plain flat solid white background, no ground shadow, no text. Left: calm idle standing. Middle: collapsing, legs buckling, body sinking toward the ground. Right: defeated, lying flat on its side, weapon slack, eyes dimmed, a few small debris pieces scattered.
```

---

## 쉬움 (e01~e10, e_final) — `{설명}`

| id | 이름 | {설명} |
|---|---|---|
| e01 | 숲의 지배자 | a colossal ancient stag beetle, body armored in mossy oak bark plates, a crown of huge antler-like mandibles, glowing amber eyes, tiny mushrooms and ferns sprouting from its shell |
| e02 | 물가의 포식자 | a giant water scorpion, flat armored brown body glistening wet, long breathing tail, strong raptorial forelegs raised like blades, pale blue-green eyes, water droplets and a reed stuck to its back |
| e03 | 초원의 여왕 | a majestic queen grasshopper, long emerald body with golden wing edges, a crown-like ridge of thorns on her head, powerful spring legs, wildflowers and clover tangled on her back |
| e04 | 밤의 군주 | a huge moth lord, dark velvet wings with pale moon-like eye spots, feathered antennae, soft glowing dust around the wing tips, deep indigo and silver palette |
| e05 | 무쇠턱 폭군 | a brutish rhinoceros beetle tyrant, thick iron-grey armor plates with dents and rust, one massive curved horn, small burning-red eyes, chains and old nails embedded in its shell |
| e06 | 맹독 여제 | an elegant giant wasp empress, slender black body with hazard-yellow stripes, a long glowing green stinger, translucent wings, a thin crown of resin |
| e07 | 그림자 사마귀 | a lean shadow mantis, dark smoky-grey body with violet edges, huge scythe-like forearms, narrow glowing eyes, wisps of shadow trailing from its joints |
| e08 | 심연의 집게왕 | a hulking deep-cave earwig king, glossy black segmented body, enormous pincers at the tail, pale bioluminescent spots along its sides, damp stone dust on its back |
| e09 | 태고의 여왕개미 | a primordial queen ant, vast bronze abdomen with tribal-looking carved markings, thick armored head, a pair of small tattered wings, amber sap crystals growing on her body |
| e10 | 곤충 황제 | an imperial golden scarab, polished gold-and-emerald carapace, a horned ornate head like a crown, jewel-like eyes, faint sun rays engraved on its shell |
| e_final | 태초의 왕충 (최종) | the primordial king of all insects: a titanic ancient beetle-dragon hybrid, layered fossil-stone armor with cracks glowing molten gold, six massive legs, a mane of petrified roots, several horns, eyes like burning suns, clearly larger and more ornate than any other boss |

> 최종보스 ① 프롬프트에는 `Standing in a calm idle pose` 앞에 **"Epic scale, imposing and ornate,"** 를 덧붙인다.

## 보통 / 어려움 / 극한
쉬움 11마리가 끝나고 새 구조의 지역·이름이 정해지면 여기 이어서 적는다.
(같은 표 형식. 난이도가 오를수록 팔레트를 차갑고 어둡게, 장식은 많게.)
