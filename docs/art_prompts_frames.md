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

---

## 3. (선택) 서식지 파괴 시트
서식지는 지금도 넘어지며 사라지는 코드 연출이 있어 없어도 됩니다. 원하면 **1×2 또는 2×2**로 정상→균열→파괴 포즈를 만들면
제가 잘라 `habitats/<종류>_death_1.webp`·`_death_2.webp` 로 넣습니다.

---

## 4. 처리·재생 규칙 (참고)
- 제가 시트를 받으면: **4등분 → 각 칸 배경투명·트림·로고제거 → 규칙 파일명으로 저장 → 배포**.
- 재생: 캐릭터 타격 `attack_1→2`·후퇴 `death_1→2` / 보스 달려듦 `attack_1→2`·죽음 `death_1→2` / 서식지 파괴 `death_1→2`.
- 없는 프레임은 자동 폴백(이전/idle). 하나씩 채우면 됩니다.
