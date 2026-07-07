# Bug Champ — 업그레이드 아이콘 프롬프트 (Gemini · 복붙용)

> 능력치 강화 15종의 아이콘. **재료 아이콘과 같은 반짝이는 게임 아이콘 스타일**입니다.
>
> **방법:** 아래처럼 **한 장에 여러 개(격자, 칸 사이 여백)**로 뽑으면 제가 **자동 검출·슬라이스**합니다.
> 순서는 각 시트에 적힌 **번호 순(좌→우, 위→아래)**. 낱개 1:1로 뽑아도 됩니다.
> **화풍 통일:** 완성된 **재료 아이콘(예: `sap.webp` 또는 `chitin.webp`)을 첨부**하고 프롬프트를 넣으세요.
> 배경은 단색(연한 세이지그린), 제가 배경 제거·정규화합니다. **글자·테두리·로고 넣지 말 것.**
> 만들면 **Downloads에 두고 "업그레이드 아이콘 만들었어"** → 제가 처리·연결.

**공통 스타일(각 프롬프트에 이미 포함):** glossy stylized mobile game UI icon, single centered emblem, soft rim light and subtle drop shadow, clean bold readable silhouette, cozy naturalist storybook palette (moss green, honey amber, warm bark brown), semi-realistic painterly shading, high detail. plain flat pale sage-green background. no text, no border, no watermark, no logo.

---

## 시트 1 · 전투 (5개)
저장(제가): `upgrades/attack · attackSpeed · crit · critDamage · bossDamage .webp`
```
A grid of 5 glossy game UI icons, evenly spaced with clear gaps, each centered at the same size on a plain flat pale sage-green background. In order:
1) 채집력: a polished wooden butterfly net with golden power/impact lines around it
2) 손놀림: a hand swinging a net blurred with fast yellow motion streaks (speed)
3) 급소 노리기: a red crosshair target reticle with a bright glint, aiming
4) 강타: a big golden impact burst star with a cracked shockwave
5) 투지: a fiery amber flame shaped like a fighting spirit / burning ember
Style: glossy stylized mobile game UI icons, soft rim light and subtle drop shadow, clean bold readable silhouettes, cozy naturalist storybook palette, semi-realistic painterly shading, high detail. no text, no border, no watermark, no logo.
```

## 시트 2 · 생존 (3개)
저장: `upgrades/maxHp · defense · regen .webp`
```
A grid of 3 glossy game UI icons, evenly spaced with clear gaps, each centered at the same size on a plain flat pale sage-green background. In order:
1) 근성: a sturdy glossy red heart with a small green leaf (vitality)
2) 맷집: a rounded shield made of bark and green leaves (toughness)
3) 회복력: a fresh green sprouting leaf with a soft healing sparkle
Style: glossy stylized mobile game UI icons, soft rim light and subtle drop shadow, clean bold readable silhouettes, cozy naturalist storybook palette, semi-realistic painterly shading, high detail. no text, no border, no watermark, no logo.
```

## 시트 3 · 보상 (4개)
저장: `upgrades/reward · xp · bugFind · materialFind .webp`
```
A grid of 4 glossy game UI icons (2x2), evenly spaced with clear gaps, each centered at the same size on a plain flat pale sage-green background. In order:
1) 판매 수완: a shiny golden coin with a small upward arrow and sparkle
2) 채집 지식: an open field-guide book with a green bookmark ribbon
3) 곤충 감각: a magnifying glass over a small glowing beetle
4) 꼼꼼한 손질: a pair of bronze tweezers holding a shiny amber gem
Style: glossy stylized mobile game UI icons, soft rim light and subtle drop shadow, clean bold readable silhouettes, cozy naturalist storybook palette, semi-realistic painterly shading, high detail. no text, no border, no watermark, no logo.
```

## 시트 4 · 편의 (3개)
저장: `upgrades/moveSpeed · boost · bugBuff .webp`
```
A grid of 3 glossy game UI icons, evenly spaced with clear gaps, each centered at the same size on a plain flat pale sage-green background. In order:
1) 발걸음: a brown leather hiking boot with light wind/motion streaks (speed)
2) 집중력: a glowing concentric focus ring with a bright spark in the center
3) 도감 통달: an open glowing insect encyclopedia with a small butterfly rising from it
Style: glossy stylized mobile game UI icons, soft rim light and subtle drop shadow, clean bold readable silhouettes, cozy naturalist storybook palette, semi-realistic painterly shading, high detail. no text, no border, no watermark, no logo.
```

---

## 참고 (제가 처리)
- 각 시트를 받으면 **자동 검출→배경제거→정규화→규칙 파일명 저장→`upgrades/` 훅 연결**.
- 파일명 규칙(업그레이드 코드 id): `attack, attackSpeed, crit, critDamage, bossDamage, maxHp, defense, regen, reward, xp, bugFind, materialFind, moveSpeed, boost, bugBuff`.
- 지금은 Material 아이콘(플레이스홀더)이라, 이미지 넣으면 자동 교체되게 훅을 준비해두겠습니다.
