# Bug Champ — 애니메이션 프레임 (한 장 = 2x2 포즈 시트)

> **방식**: 프레임을 낱장으로 만들지 않고, **한 이미지에 4개 포즈를 2×2 격자**로 그립니다.
> → 한 번 생성이라 **캐릭터 일관성 완벽**, 제가 **칸을 4개로 잘라** 각 프레임으로 만듭니다(배경제거·로고제거·리네임 포함).
> **만든 시트 1장을 Downloads에 두고 "캐릭터 시트 만들었어"** 하시면 제가 처리·배포합니다.
>
> **왜 편집으로?** *기존 캐릭터/보스 이미지를 Gemini에 첨부*하고 편집시키면 같은 캐릭터가 유지됩니다.
> **프레임이 없어도 게임은 동작**(자동 폴백). 넣는 만큼 애니가 켜집니다.

## 격자 규칙 (중요)
- **2×2 격자, 칸 사이 여백 있게, 각 칸에 캐릭터를 같은 크기·같은 위치로** 배치.
- **포즈 순서 고정** (제가 이 순서로 자릅니다):
  - **좌상 = 강타(내리침)** · **우상 = 준비(치켜듦)** · **좌하 = 비틀(피격)** · **우하 = 쓰러짐**
- 배경은 단색(제가 투명 처리), **글자/UI/로고 넣지 말 것**(no text, no logo).

---

## 1. 캐릭터 시트  (`idle.webp` 를 Gemini에 첨부)
> 결과 → 제가 잘라서 `character/attack_1.webp`(강타)·`attack_2.webp`(준비)·`death_1.webp`(비틀)·`death_2.webp`(쓰러짐) 로 저장.

**프롬프트 (idle 첨부 후 붙여넣기):**
```
Using this exact character (same outfit, hat, bag, colors), create a 2x2 sprite sheet on a plain flat pastel background, with clear even spacing between the four cells and the character at the same size and position in each cell. Side view. Four poses:
- top-left: swinging the butterfly net downward in a strong strike
- top-right: winding up with the net raised high behind the shoulder
- bottom-left: stumbling backward off-balance, dizzy
- bottom-right: fallen sitting on the ground, dazed and defeated
Consistent character in all four, plain background, no text, no logo, no watermark.
```

---

## 2. 보스 시트  (보스 `idle` 를 먼저 만들고 → 그걸 첨부)
> 먼저 보스 idle(`art_prompts_v2.md` STEP 8, 참나무숲 사슴벌레 = `oak_forest.webp`)을 만든 뒤, **그 이미지를 첨부**.
> 결과 → 제가 잘라서 `bosses/oak_forest_attack_1.webp`·`_attack_2.webp`·`_death_1.webp`·`_death_2.webp` 로 저장.

**프롬프트 (보스 idle 첨부 후):**
```
Using this exact boss creature (giant stag beetle, same design and colors), create a 2x2 sprite sheet on a plain flat background, clear even spacing between the four cells, boss at the same size and position in each cell. Side view facing left. Four poses:
- top-left: slamming its huge pincers/mandibles forward in a powerful strike
- top-right: rearing up with pincers raised high, menacing
- bottom-left: staggering and wounded, about to collapse
- bottom-right: flipped over on its back with legs up in the air, defeated
Consistent creature in all four, plain background, no text, no logo, no watermark.
```
> 다른 지역 보스도 같은 방식(잘린 파일 앞에 지역 id: `valley_stream_` 등).

### 2-1. 잿불의 군주 (`ember_ridge`) — ✅ 완료(2026-09-09)
> 2026-09-09 추가된 화(火) 지역의 보스. idle 은 `art_prompts_v2.md` STEP 16 으로
> 먼저 만들고, **그 이미지를 첨부**해서 아래를 넣는다.
> 결과 → `bosses/ember_ridge_attack_1.webp`·`_attack_2.webp`·`_death_1.webp`·`_death_2.webp`.

```
Using this exact boss creature (giant volcanic fire beetle with charcoal-black armored shell and glowing molten orange cracks, same design and colors), create a 2x2 sprite sheet on a plain flat background, clear even spacing between the four cells, boss at the same size and position in each cell. Side view facing left. Four poses:
- top-left: lunging forward and slamming its red-hot mandibles down, ember sparks bursting from the impact
- top-right: rearing up with its shell cracks flaring bright molten orange, heat haze rising, menacing
- bottom-left: staggering and wounded, the glow in its cracks dimming to dull red, smoke trailing
- bottom-right: flipped over on its back with legs up, cracks gone dark and cooled to grey ash, defeated
Consistent creature in all four, plain background, no text, no logo, no watermark.
```

> 💡 이 보스는 **빛(용암 균열)이 상태를 말한다** — 다른 보스와 달리 죽는 포즈에서
> 빛이 꺼지게 잡았다. 자세만 바꾸고 빛을 그대로 두면 쓰러졌는데 멀쩡해 보인다.

---

## 3. 몬스터 타격 모션 (2026-09-09) — 20종 각각

몬스터(`habitats/`)도 **자기 타격 모션**이 필요하다. 지금은 플레이어를 때릴 때
앞으로 튀어나오는 이동만 있고 자세는 그대로라, 무는 건지 밀리는 건지 안 보인다.
코드는 이미 `habitats/<id>_attack_1.webp` · `_attack_2.webp` 를 찾는다 —
**그림만 넣으면 바로 재생된다**(`play_screen.dart` 의 `_enemyLunge`).

### 재생 순서 ⚠️ 먼저 읽을 것
`_enemyLunge` 가 1 에서 0 으로 줄면서 **`attack_1` → `attack_2`** 순으로 넘어간다.
즉 **1번이 먼저 나가는 타격**이고 **2번이 되돌아오는 자세**다.
보스 시트(§2)는 `1=내리치기 / 2=곧추서기` 로 잡혀 있어 헷갈리기 쉽다 —
몬스터는 **1=덤벼듦 / 2=물러남** 으로 잡는다.

### 만드는 법
종별 idle(STEP 17 로 만든 `habitats/<id>.webp`)을 **첨부**하고 아래를 넣는다.
20종 모두 같은 프롬프트를 쓴다 — 첨부한 그림이 종을 정한다.

```
Using this exact creature (same design, colors and proportions), create a 1x2 sprite sheet on a plain flat background, clear even spacing between the two cells, the creature at the same size and position in both cells. Side view facing left. Two poses:
- left cell: lunging forward to attack, body stretched toward the left, mouth open, limbs thrown forward, aggressive
- right cell: pulling back after the strike, body coiled and leaning away to the right, recovering
Consistent creature in both, plain background, no text, no logo, no watermark.
```

> 결과 → 제가 반으로 잘라 `habitats/<id>_attack_1.webp`(덤벼듦)·`_attack_2.webp`(물러남) 로 저장.
> ⚠️ 두 칸을 **각자 트림하면 안 된다** — 여백이 달라 재생할 때 몬스터가 튄다.
> 합집합 bbox 로 함께 자른다(잿불 보스에서 그렇게 했다).

### 사망 프레임은 **안 만들어도 된다**
쓰러질 때 코드가 **회전(1.3rad) + 아래로 밀기 + 페이드**를 준다. 그림 없이도
넘어가며 사라진다. 굳이 `_death_1/2` 를 넣으면 그 회전이 **위에 겹쳐** 두 번
쓰러지는 것처럼 보인다 — 넣을 거면 그림에서는 자세를 거의 안 눕히는 게 낫다.

---

## 4. 처리·재생 규칙 (참고)
- 제가 시트를 받으면: **4등분 → 각 칸 배경투명·트림·로고제거 → 규칙 파일명으로 저장 → 배포**.
- 재생: 캐릭터 타격 `attack_1→2`·후퇴 `death_1→2` / 보스 달려듦 `attack_1→2`·죽음 `death_1→2` / 서식지 파괴 `death_1→2`.
- 없는 프레임은 자동 폴백(이전/idle). 하나씩 채우면 됩니다.
