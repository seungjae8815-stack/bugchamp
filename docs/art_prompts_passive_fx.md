# Bug Champ — 패시브 스킬 효과 4장 (Gemini · 4장)

> **쓰는 법**
> 1. 첨부 이미지는 필요 없습니다. **반드시 새까만 검정 배경**이어야 합니다(검정이 투명으로 바뀝니다).
> 2. 그림마다 프롬프트 칸을 **통째로 복사 → Gemini 새 대화창에 붙여넣기**.
> 3. 저장할 때 아래 **파일명** 칸을 복사해 붙여넣고 `C:\Users\Lenovo\Downloads` 에 두세요.
> 4. 다 되면 알려 주세요. 4칸으로 잘라 투명하게 만들어 넣습니다(기존 스킬 효과 8장과 같은 도구).
>    코드는 이미 이 파일명을 찾게 돼 있습니다 — 넣는 순간 6초마다 캐릭터 위에 옅게 재생됩니다.

## 무엇이 어디에 쓰이나

- 패시브 스킬을 장착하면 **6초마다 한 종씩 캐릭터 위에 50% 투명도로** 재생됩니다(0.8초, 4장을 차례로).
- 액티브 효과처럼 터지는 느낌이면 "스킬이 발동했다"로 오해되므로, **은은하게 감도는 느낌**으로 썼습니다.
- 가운데에는 캐릭터가 서 있으므로 **가운데는 비우고 둘레만** 그립니다.
- 이 그림이 없어서 1.0.17 에서 Crashlytics 오류(`Unable to load asset: gatherer_hand_3.webp`)가 쌓였습니다. 앱 쪽 수정은 이미 했고, 그림을 넣으면 효과도 보이게 됩니다.

---

### 1. 채집가의 손 효과 (재료 발견 증가)

```
Effect: Gatherer's Hand passive aura — a gentle ring of small glowing amber and honey-gold sparkles shaped like tiny leaves, crystal flakes and seeds, slowly drifting upward and inward around the center, with a soft warm golden glow at the bottom. Calm and subtle, not an explosion. A horizontal sprite strip of 4 equal square frames side by side with small gaps, for a 2D mobile game visual effect, on a PURE SOLID BLACK background (#000000). Frame 1 the effect starts small, frame 2 grows, frame 3 at full strength, frame 4 fades out. No characters, no creatures, no people, no hands. The center of every frame stays mostly empty because a character will stand there; the effect surrounds that center. Bright glowing light only, as if drawn with additive light, vibrant game VFX with soft bloom glow, clean shapes readable on a small phone screen. no text, no letters, no numbers, no frame border, no watermark, no logo. Composition: keep the whole strip in the upper 85% of the image; the bottom 15% must be plain solid black only (it will be cropped off).
```

파일명

```
fx_gatherer_hand
```

### 2. 곤충학자의 눈 효과 (곤충 발견 증가)

```
Effect: Entomologist's Eye passive aura — a soft cyan-teal circular lens ring slowly expanding around the center, with faint scanning light lines sweeping around the ring and a few small glowing teal sparkles twinkling on it, like a magnifying focus searching the area. Calm and subtle, not an explosion. A horizontal sprite strip of 4 equal square frames side by side with small gaps, for a 2D mobile game visual effect, on a PURE SOLID BLACK background (#000000). Frame 1 the effect starts small, frame 2 grows, frame 3 at full strength, frame 4 fades out. No characters, no creatures, no people, no eyes, no insects. The center of every frame stays mostly empty because a character will stand there; the effect surrounds that center. Bright glowing light only, as if drawn with additive light, vibrant game VFX with soft bloom glow, clean shapes readable on a small phone screen. no text, no letters, no numbers, no frame border, no watermark, no logo. Composition: keep the whole strip in the upper 85% of the image; the bottom 15% must be plain solid black only (it will be cropped off).
```

파일명

```
fx_scholar_eye
```

### 3. 끈기 효과 (보스 피해 증가)

```
Effect: Tenacity passive aura — a steady crimson-orange flame-like energy aura rising in soft vertical streaks around the center, with a faint glowing red ring on the ground and a few small ember sparks floating upward, showing quiet determination. Calm and subtle, not an explosion. A horizontal sprite strip of 4 equal square frames side by side with small gaps, for a 2D mobile game visual effect, on a PURE SOLID BLACK background (#000000). Frame 1 the effect starts small, frame 2 grows, frame 3 at full strength, frame 4 fades out. No characters, no creatures, no people. The center of every frame stays mostly empty because a character will stand there; the effect surrounds that center. Bright glowing light only, as if drawn with additive light, vibrant game VFX with soft bloom glow, clean shapes readable on a small phone screen. no text, no letters, no numbers, no frame border, no watermark, no logo. Composition: keep the whole strip in the upper 85% of the image; the bottom 15% must be plain solid black only (it will be cropped off).
```

파일명

```
fx_tenacity
```

### 4. 군집 효과 (펫 곤충 공격 증가)

```
Effect: Swarm passive aura — many tiny glowing lime-green and yellow light motes orbiting around the center in two loose swirling rings, like a cloud of fireflies circling together, leaving short soft light trails. Calm and subtle, not an explosion. A horizontal sprite strip of 4 equal square frames side by side with small gaps, for a 2D mobile game visual effect, on a PURE SOLID BLACK background (#000000). Frame 1 the effect starts small, frame 2 grows, frame 3 at full strength, frame 4 fades out. No characters, no creatures, no people, no insects drawn in detail (only dots of light). The center of every frame stays mostly empty because a character will stand there; the effect surrounds that center. Bright glowing light only, as if drawn with additive light, vibrant game VFX with soft bloom glow, clean shapes readable on a small phone screen. no text, no letters, no numbers, no frame border, no watermark, no logo. Composition: keep the whole strip in the upper 85% of the image; the bottom 15% must be plain solid black only (it will be cropped off).
```

파일명

```
fx_swarm
```
