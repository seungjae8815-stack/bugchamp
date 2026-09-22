# 스킬 조각 그림 7장 + 액티브 스킬 효과음 7개

2026-09-20 사장님 요청.

- 그림: Gemini 에 코드블록을 그대로 붙여넣는다. 받은 파일은 배경을 지우고
  **최대변 660px · RGBA WebP(quality 92)** 로 저장해 아래 경로에 넣는다.
- 소리: Pixabay 에서 검색어로 받아 **WAV** 로 변환해 아래 경로에 넣는다.

```
C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\ui\skill
```
```
C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\sounds
```

파일이 없어도 게임은 정상으로 돈다 — 그림은 등급색 다이아로, 소리는 무음으로
넘어간다(§6 폴백). 하나씩 채워 넣으면 된다.

---

# A. 스킬 조각 그림 ×7

스킬 화면 헤더와 승급 팝업에서 **14~15px** 로 쓴다. 작아서 실루엣이 전부다.

- **스킬 조각** = 깨진 결정 파편 (모아서 그 스킬을 연다)
- **만능 조각** = 육각 코인 (어느 스킬에나 쓴다 — 파편과 모양부터 달라야 한다)

### 1. 일반 조각

```
a single chipped crystal shard, dull blue-grey stone, matte facets, plain and humble, glossy game currency icon, single centered object, bold thick dark outline, cream rim light, strong readable silhouette, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7
```

파일명

```
shard_common
```

### 2. 희귀 조각

```
a single chipped crystal shard, vivid blue glass, glowing inner light, sharp facets, glossy game currency icon, single centered object, bold thick dark outline, cream rim light, strong readable silhouette, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7
```

파일명

```
shard_rare
```

### 3. 영웅 조각

```
a single chipped crystal shard, deep purple amethyst, violet inner glow, two small floating motes, glossy game currency icon, single centered object, bold thick dark outline, cream rim light, strong readable silhouette, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7
```

파일명

```
shard_epic
```

### 4. 전설 조각

```
a single chipped crystal shard, molten amber-orange, burning inner core, small ember sparks, glossy game currency icon, single centered object, bold thick dark outline, cream rim light, strong readable silhouette, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7
```

파일명

```
shard_legendary
```

### 5. 희귀 만능 조각

```
a hexagonal metal coin token with a blue crystal set in the center, engraved rim, wildcard emblem, glossy game currency icon, single centered object, bold thick dark outline, cream rim light, strong readable silhouette, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7
```

파일명

```
shard_wild_rare
```

### 6. 영웅 만능 조각

```
a hexagonal metal coin token with a purple crystal set in the center, engraved rim, wildcard emblem, glossy game currency icon, single centered object, bold thick dark outline, cream rim light, strong readable silhouette, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7
```

파일명

```
shard_wild_epic
```

### 7. 전설 만능 조각

```
a hexagonal gold coin token with an amber-orange crystal set in the center, engraved rim, radiant wildcard emblem, glossy game currency icon, single centered object, bold thick dark outline, cream rim light, strong readable silhouette, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7
```

파일명

```
shard_wild_legendary
```

---

# B. 액티브 스킬 효과음 ×7

`assets/sounds/skill_{스킬id}.wav` 로 저장하면 코드가 자동으로 찾아 쓴다.

**공통 조건**

- **0.4 ~ 1.0초.** 길면 다음 발동과 겹친다(개발자 모드 `쿨타임 없음` 이 0.9초 간격).
- **꼬리를 자른다.** 잔향이 길면 타격음(`hit.wav`)과 뭉친다.
- 음량은 기존 `hit.wav` 보다 **조금 크게** — 스킬은 특별해야 한다.
- Pixabay 필터: **Sound Effects** 항목에서, 길이 **0–2초**로 좁히면 고르기 쉽다.

### 1. 유인 수액 (일반 · 재료 획득)

Pixabay 검색어 — 위에서부터 차례로 들어 본다.

```
liquid drip pour
```
```
magic sparkle collect
```
```
item pickup
```

끈적한 수액이 떨어지고 뭔가 모이는 느낌. **금속성이 아닌** 부드러운 소리.

파일명

```
skill_lure_sap
```

### 2. 질풍 채집 (희귀 · 공격속도)

```
whoosh fast wind
```
```
speed boost swoosh
```
```
air swipe
```

바람이 훅 지나가는 소리. 짧고 위로 올라가는 느낌(피치가 올라가는 것)이 좋다.

파일명

```
skill_gale_hunt
```

### 3. 포충망 휘두르기 (희귀 · 광역 피해)

```
net swing whoosh
```
```
sword swipe swoosh
```
```
fabric whip
```

천이 공기를 가르는 소리. 칼날처럼 날카롭지 않고 **퍽** 하고 걸리는 끝맛이 있으면 좋다.

파일명

```
skill_net_sweep
```

### 4. 여왕의 부름 (영웅 · 곤충 강화)

```
magic buff power up
```
```
fantasy summon chime
```
```
insect buzz swarm
```

부름에 응답하는 느낌. 벌레 날갯짓 소리가 섞이면 이 게임답다.

파일명

```
skill_queen_call
```

### 5. 회심의 일격 (전설 · 폭발 피해)

```
heavy impact hit
```
```
critical hit punch
```
```
epic slam impact
```

가장 세야 한다. **저음**이 묵직하게 깔리는 것으로 고른다 — 보스 막타에 ×2 로 터진다.

파일명

```
skill_crit_strike
```

### 6. 번데기 방벽 (전설 · 무적)

```
magic shield activate
```
```
barrier force field
```
```
protection spell
```

감싸는 느낌. **닫히는** 소리(끝이 막히는)가 방벽에 맞는다.

파일명

```
skill_pupa_guard
```

### 7. 탈피 (전설 · 부활)

```
magic revive heal
```
```
holy resurrection chime
```
```
shimmer rise up
```

살아나는 소리. 위로 올라가는 반짝임 + 숨을 돌리는 여운. 7개 중 **유일하게 1초를
살짝 넘겨도 된다** — 쓰러질 뻔한 순간에만 뜨는 연출이라 겹칠 일이 없다.

파일명

```
skill_molting
```

---

## 넣고 나서

효과음은 `packages\app\assets\sounds\` 에 넣기만 하면 끝이다(폴더가 통째로
등록돼 있다). 그림은 `packages\app\assets\images\ui\skill\` 에 넣는다.
둘 다 파일명이 곧 id 라 코드·JSON 을 고칠 필요가 없다(§6).
