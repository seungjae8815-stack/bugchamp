# Bug Champ — 요정 아이콘 2장 · 스킬 효과 8장 (Gemini · 10장)

> **쓰는 법**
> 1. 화풍을 맞추려면 기존 그림을 **함께 첨부**하세요.
>    - 1~2번(아이콘): `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\materials\mineral.webp`
>    - 3~10번(스킬 효과): `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\fairies\fairy_ignis_cast.webp`
> 2. 그림마다 프롬프트 칸을 **통째로 복사 → Gemini 에 붙여넣기**. 그림마다 **새 대화창**에서 뽑으세요.
> 3. 저장할 때 아래 **파일명** 칸을 복사해 붙여넣고 한 폴더에 모아 주세요.
> 4. 다 만드시면 폴더 경로를 알려 주세요. 배경 제거·크기 맞춤까지 하고 연결합니다.
>    (코드는 이미 이 파일명을 찾게 돼 있습니다 — 그림이 없으면 지금처럼 아이콘·빛 원으로 보입니다.)

## 무엇이 어디에 쓰이나

- **1~2번**: 요정 탭 버튼(도감 · 자동 합성) — 작게(18px) 보이므로 **모양이 단순하고 굵게**.
- **3~10번**: 요정이 스킬을 쓰는 순간 터지는 효과. 코드가 크기를 키우며 0.8초 동안 보여 주고 사라지게 한다.
  - **공격형(상대 몬스터 위에 터짐)**: 이그니스 · 볼테아 · 루나리스
  - **회복·방어·버프형(우리 캐릭터 위에 터짐)**: 운디네 · 테라리엘 · 실피드 · 티타니아 · 아스테리아
  - 효과만 그린다 — **요정·캐릭터·몬스터는 그리지 않는다**. 가운데를 중심으로 둥글게 퍼지는 모양이어야 어느 자리에 얹어도 어울린다.

---

### 1. 요정 도감 아이콘

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a fairy collection book: a small closed storybook with a soft leaf-green cloth cover and a golden corner trim, a tiny glowing fairy-wing emblem pressed on the cover, two little sparkles floating above it. Simple chunky shape, readable at 18 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fairy_dex
```

### 2. 요정 자동 합성 아이콘

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for automatically merging fairies: three small glowing pink-gold orbs of fairy light swirling inward along curved trails and fusing into one larger bright star-shaped orb in the center, a few tiny sparkles. Simple chunky shape, readable at 18 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream) with a glowing pink-gold accent, semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no fairies, no people, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fairy_automerge
```

### 3. 이그니스 스킬 효과 — 불꽃 폭발 (상대에게)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game skill visual effect only: a round fiery explosion burst seen from the front, a bright yellow-white core blooming into layered orange and red flame petals, a ring of flying embers and small sparks scattering outward evenly in all directions, a few curls of light smoke at the edges. The effect is centered and radially balanced so it can be placed on top of a target. Hand-painted cozy storybook cartoon effect in the same art style as the reference (soft painterly shading, thin warm brown outline on the main shapes, saturated glowing accent colors). Single effect centered, square 1:1 image, plain flat pure white background, no ground, no cast shadow. no characters, no people, no fairies, no insects, no monsters, no text, no letters, no numbers, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fx_ignis
```

### 4. 운디네 스킬 효과 — 치유의 샘물 (우리 캐릭터에게)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game skill visual effect only: a gentle healing splash, a ring of clear aqua water droplets and small bubbles rising upward in a soft spiral around an empty center, tiny mint-green plus-shaped sparkles and a faint glowing teal circle at the bottom. The effect is centered and radially balanced so it can be placed around a character. Hand-painted cozy storybook cartoon effect in the same art style as the reference (soft painterly shading, thin warm brown outline on the main shapes, saturated glowing accent colors). Single effect centered, square 1:1 image, plain flat pure white background, no ground, no cast shadow. no characters, no people, no fairies, no insects, no monsters, no text, no letters, no numbers, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fx_undine
```

### 5. 테라리엘 스킬 효과 — 조약돌 방벽 (우리 캐릭터에게)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game skill visual effect only: a protective earth barrier, a ring of smooth floating river pebbles and small agate stones circling an empty center, joined by a faint translucent honey-brown dome of light with carved growth-ring patterns, a few tiny leaves drifting. The effect is centered and radially balanced so it can be placed around a character. Hand-painted cozy storybook cartoon effect in the same art style as the reference (soft painterly shading, thin warm brown outline on the main shapes, saturated glowing accent colors). Single effect centered, square 1:1 image, plain flat pure white background, no ground, no cast shadow. no characters, no people, no fairies, no insects, no monsters, no text, no letters, no numbers, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fx_terrariel
```

### 6. 실피드 스킬 효과 — 순풍 (우리 캐릭터에게)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game skill visual effect only: a swift tailwind swirl, several curved pale mint and white wind ribbons spiraling around an empty center, a few small light-green leaves and soft feathers caught in the gust, thin speed streaks. The effect is centered and radially balanced so it can be placed around a character. Hand-painted cozy storybook cartoon effect in the same art style as the reference (soft painterly shading, thin warm brown outline on the main shapes, saturated glowing accent colors). Single effect centered, square 1:1 image, plain flat pure white background, no ground, no cast shadow. no characters, no people, no fairies, no insects, no monsters, no text, no letters, no numbers, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fx_sylphid
```

### 7. 볼테아 스킬 효과 — 번개 표식 (상대에게)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game skill visual effect only: a crackling lightning strike mark, a bright yellow-white electric burst in the center with jagged violet and gold lightning bolts branching outward, a thin glowing target ring around it, small electric sparks popping. The effect is centered and radially balanced so it can be placed on top of a target. Hand-painted cozy storybook cartoon effect in the same art style as the reference (soft painterly shading, thin warm brown outline on the main shapes, saturated glowing accent colors). Single effect centered, square 1:1 image, plain flat pure white background, no ground, no cast shadow. no characters, no people, no fairies, no insects, no monsters, no text, no letters, no numbers, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fx_voltea
```

### 8. 루나리스 스킬 효과 — 달그림자 베기 (상대에게)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game skill visual effect only: a crescent moonlight slash, a large curved silver-blue crescent blade of light cutting diagonally across the center, a soft deep-indigo shadow trail behind it, tiny silver star sparkles scattering. The effect is centered and balanced so it can be placed on top of a target. Hand-painted cozy storybook cartoon effect in the same art style as the reference (soft painterly shading, thin warm brown outline on the main shapes, saturated glowing accent colors). Single effect centered, square 1:1 image, plain flat pure white background, no ground, no cast shadow. no characters, no people, no fairies, no insects, no monsters, no text, no letters, no numbers, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fx_lunaris
```

### 9. 티타니아 스킬 효과 — 꽃의 축복 (우리 캐릭터에게)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game skill visual effect only: a blooming blessing aura, a ring of pink and white flower petals and small blossoms swirling around an empty center, golden pollen sparkles floating upward, a faint glowing rose-gold circle at the bottom. The effect is centered and radially balanced so it can be placed around a character. Hand-painted cozy storybook cartoon effect in the same art style as the reference (soft painterly shading, thin warm brown outline on the main shapes, saturated glowing accent colors). Single effect centered, square 1:1 image, plain flat pure white background, no ground, no cast shadow. no characters, no people, no fairies, no insects, no monsters, no text, no letters, no numbers, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fx_titania
```

### 10. 아스테리아 스킬 효과 — 별빛 수호 (우리 캐릭터에게)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game skill visual effect only: a radiant guardian starlight, a large glowing five-pointed golden star of light behind an empty center with soft white rays, a ring of small twinkling stars orbiting around it, a faint protective halo. The effect is centered and radially balanced so it can be placed around a character. Hand-painted cozy storybook cartoon effect in the same art style as the reference (soft painterly shading, thin warm brown outline on the main shapes, saturated glowing accent colors). Single effect centered, square 1:1 image, plain flat pure white background, no ground, no cast shadow. no characters, no people, no fairies, no insects, no monsters, no text, no letters, no numbers, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fx_asteria
```
