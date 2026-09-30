# Bug Champ — 요정 그림 프롬프트 (Gemini · 23장)

> **쓰는 법**
> 1. 화풍을 맞추려면 기존 그림을 **함께 첨부**하세요.
>    - 1~8번(요정 동작 시트)·9~10번(알·둥지)·22번(배경): `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\character\idle.webp`
>    - 11~21번(아이템 아이콘): `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\materials\mineral.webp`
> 2. 그림마다 프롬프트 칸을 **통째로 복사 → Gemini 에 붙여넣기**. 그림마다 **새 대화창**에서 뽑으세요
>    (앞 대화의 그림이 섞여 나온 적이 있다).
> 3. 저장할 때 아래 **파일명** 칸을 복사해 붙여넣고 한 폴더에 모아 주세요.
> 4. 다 만드시면 폴더 경로를 알려 주세요. 배경 제거·워터마크 제거·크기 맞춤까지 하고 화면에 연결합니다.

## 무엇이 어디에 쓰이나

- **요정 8장(1~8) = 요정마다 동작 시트 1장**: 한 장에 **세 동작을 가로로 나란히** 그린다 —
  ① 날갯짓(날개 위) ② 날갯짓(날개 아래) ③ 스킬 시전. 받으면 세 칸으로 잘라 `fairy_이름_1` · `_2` · `_cast` 로 쓴다.
  ①② 를 번갈아 보여 주면 파닥이고(캐릭터 걷기와 같은 프레임 애니메이션), 스킬이 터질 때 ③ 으로 바뀐다.
  한 장에서 같이 그리므로 세 동작이 **같은 요정**으로 나온다. 위아래로 둥실 뜨는 움직임·반짝이 꼬리는 코드가 얹는다.
  ⚠️ 세 동작 사이 간격이 좁거나 겹치면 자를 수 없다 — 겹친 그림이 나오면 다시 뽑아 주세요. **등급(일반~신화)은 그림을 따로 뽑지 않는다** —
  코드가 등급 색의 빛 테두리·반짝임을 얹는다. 그래서 요정 그림은 **흰 배경 · 테두리·후광 없이** 받는다.
- 요정은 **곤충이 아니라 사람 모습의 판타지 요정**이다. 날개도 곤충 날개처럼 보이지 않게(빛·꽃잎·비단·깃털).
- 캐릭터가 오른쪽을 보고 걷기 때문에 요정도 **오른쪽을 향해 나는 옆모습**으로 받는다.
- **알(9)** 은 한 장만 — 등급 색은 코드가 입힌다(진주색으로 받는다). **둥지(10)** 는 비워 두고 알은 코드가 얹는다.
- 가속기 3장(11~13)은 **크기·화려함이 한눈에 커지게**, 속성석 7장(14~20)은 **색과 모양으로 능력치가 읽히게**.

---

### 1. 이그니스 — 불꽃의 요정 · 동작 시트 1장(날갯짓 위·아래 + 스킬 시전)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Character animation sprite sheet of ONE small fantasy fairy, drawn THREE times side by side in a single horizontal row, the SAME character in every pose with the identical face, hair, outfit, colors, proportions and size. The character: A small fantasy fairy character named Ignis, the Fairy of Flame: a lively fairy girl with flame-red hair whose tips flicker like candle fire, bright amber eyes and a confident grin, wearing a dress of layered ember-orange petals with softly glowing edges, holding a tiny dancing flame in one open palm, a few floating sparks around her. Her wings are thin shimmering sheets of rising heat, translucent orange-gold with glowing veins, NOT insect wings. Pose 1 (left): flying facing right, wings raised UP at the top of a wingbeat. Pose 2 (middle): exactly the same as pose 1 except the wings are swept DOWN at the bottom of a wingbeat and the body sits very slightly lower. Pose 3 (right): skill-casting pose, thrusting her open palm forward as the tiny flame in her hand bursts into a bright fireball, wings spread open, the magic effect kept small and close to her body. All three poses face right in a three-quarter side view, full body, same scale, aligned on the same baseline, each pose centered in its own equal third of the image with WIDE empty white gaps between them so they never touch or overlap. Hand-painted cozy storybook cartoon in the same art style as the reference character (soft warm lighting, gentle painterly shading, thin warm brown outline, muted earthy palette with glowing accent colors), cute proportions about 3 heads tall, readable silhouette when shown small. A humanoid fairy with a human face and hands, not an insect. Plain flat pure white background, no ground, no cast shadow, no glow ring, no frames, no dividing lines, no panels. no text, no letters, no numbers, no labels, no watermark, no logo, no signature --ar 16:9
```

파일명

```
fairy_ignis_sheet
```

### 2. 운디네 — 샘물의 요정 · 동작 시트 1장(날갯짓 위·아래 + 스킬 시전)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Character animation sprite sheet of ONE small fantasy fairy, drawn THREE times side by side in a single horizontal row, the SAME character in every pose with the identical face, hair, outfit, colors, proportions and size. The character: A small fantasy fairy character named Undine, the Fairy of Springs: a gentle fairy girl with long flowing aqua-blue hair whose ends turn into falling water droplets, calm sea-green eyes and a soft smile, wearing a dress of rippling clear water layered over a lily-pad green bodice, holding a small glowing dewdrop between both hands, tiny bubbles drifting around her. Her wings are clear and shimmering like the surface of a spring pond, with faint ripple patterns, NOT insect wings. Pose 1 (left): flying facing right, wings raised UP at the top of a wingbeat. Pose 2 (middle): exactly the same as pose 1 except the wings are swept DOWN at the bottom of a wingbeat and the body sits very slightly lower. Pose 3 (right): skill-casting pose, raising the glowing dewdrop above her head as it bursts into a shimmering spray of healing water droplets, wings spread open, the magic effect kept small and close to her body. All three poses face right in a three-quarter side view, full body, same scale, aligned on the same baseline, each pose centered in its own equal third of the image with WIDE empty white gaps between them so they never touch or overlap. Hand-painted cozy storybook cartoon in the same art style as the reference character (soft warm lighting, gentle painterly shading, thin warm brown outline, muted earthy palette with glowing accent colors), cute proportions about 3 heads tall, readable silhouette when shown small. A humanoid fairy with a human face and hands, not an insect. Plain flat pure white background, no ground, no cast shadow, no glow ring, no frames, no dividing lines, no panels. no text, no letters, no numbers, no labels, no watermark, no logo, no signature --ar 16:9
```

파일명

```
fairy_undine_sheet
```

### 3. 테라리엘 — 대지의 요정 · 동작 시트 1장(날갯짓 위·아래 + 스킬 시전)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Character animation sprite sheet of ONE small fantasy fairy, drawn THREE times side by side in a single horizontal row, the SAME character in every pose with the identical face, hair, outfit, colors, proportions and size. The character: A small fantasy fairy character named Terrariel, the Fairy of the Earth: a sturdy, cheerful fairy boy with braided moss-green hair sprouting two tiny leaves, warm brown eyes and freckles, wearing a little armored vest made of smooth river pebbles and bark over an earthy tunic, holding a small round stone shield carved with growth rings, a few tiny pebbles floating around him. His wings are thin polished slices of banded agate stone, translucent honey-brown, NOT insect wings. Pose 1 (left): flying facing right, wings raised UP at the top of a wingbeat. Pose 2 (middle): exactly the same as pose 1 except the wings are swept DOWN at the bottom of a wingbeat and the body sits very slightly lower. Pose 3 (right): skill-casting pose, bracing his round stone shield forward with both hands as a small ring of floating pebbles forms a barrier in front of him, wings spread open, the magic effect kept small and close to his body. All three poses face right in a three-quarter side view, full body, same scale, aligned on the same baseline, each pose centered in its own equal third of the image with WIDE empty white gaps between them so they never touch or overlap. Hand-painted cozy storybook cartoon in the same art style as the reference character (soft warm lighting, gentle painterly shading, thin warm brown outline, muted earthy palette with glowing accent colors), cute proportions about 3 heads tall, readable silhouette when shown small. A humanoid fairy with a human face and hands, not an insect. Plain flat pure white background, no ground, no cast shadow, no glow ring, no frames, no dividing lines, no panels. no text, no letters, no numbers, no labels, no watermark, no logo, no signature --ar 16:9
```

파일명

```
fairy_terrariel_sheet
```

### 4. 실피드 — 바람의 요정 · 동작 시트 1장(날갯짓 위·아래 + 스킬 시전)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Character animation sprite sheet of ONE small fantasy fairy, drawn THREE times side by side in a single horizontal row, the SAME character in every pose with the identical face, hair, outfit, colors, proportions and size. The character: A small fantasy fairy character named Sylphid, the Fairy of the Wind: a quick, playful fairy with short silvery mint hair swept back by the wind, bright pale-green eyes, wearing an airy white-and-mint tunic and a long flowing scarf trailing behind, in a fast dashing flying pose, swirling gusts of small green leaves around her. Her wings are long, slender and swept back like wind-cut feathers, pale mint and white, NOT insect wings. Pose 1 (left): flying facing right, wings raised UP at the top of a wingbeat. Pose 2 (middle): exactly the same as pose 1 except the wings are swept DOWN at the bottom of a wingbeat and the body sits very slightly lower. Pose 3 (right): skill-casting pose, dashing forward with her scarf whipping behind her, a small swirl of wind and leaves around her, wings spread open, the magic effect kept small and close to her body. All three poses face right in a three-quarter side view, full body, same scale, aligned on the same baseline, each pose centered in its own equal third of the image with WIDE empty white gaps between them so they never touch or overlap. Hand-painted cozy storybook cartoon in the same art style as the reference character (soft warm lighting, gentle painterly shading, thin warm brown outline, muted earthy palette with glowing accent colors), cute proportions about 3 heads tall, readable silhouette when shown small. A humanoid fairy with a human face and hands, not an insect. Plain flat pure white background, no ground, no cast shadow, no glow ring, no frames, no dividing lines, no panels. no text, no letters, no numbers, no labels, no watermark, no logo, no signature --ar 16:9
```

파일명

```
fairy_sylphid_sheet
```

### 5. 볼테아 — 천둥의 요정 · 동작 시트 1장(날갯짓 위·아래 + 스킬 시전)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Character animation sprite sheet of ONE small fantasy fairy, drawn THREE times side by side in a single horizontal row, the SAME character in every pose with the identical face, hair, outfit, colors, proportions and size. The character: A small fantasy fairy character named Voltea, the Fairy of Thunder: an energetic, mischievous fairy girl with spiky pale-gold hair crackling with static, bright violet eyes, wearing a skirt shaped like a small dark storm cloud and a yellow top, tiny electric-yellow lightning arcs jumping between her fingertips. Her wings are angular and crystal-like with glowing lightning-bolt veins in electric yellow, NOT insect wings. Pose 1 (left): flying facing right, wings raised UP at the top of a wingbeat. Pose 2 (middle): exactly the same as pose 1 except the wings are swept DOWN at the bottom of a wingbeat and the body sits very slightly lower. Pose 3 (right): skill-casting pose, pointing forward with one finger as a short zig-zag lightning bolt sparks from it, her hair standing on end, wings spread open, the magic effect kept small and close to her body. All three poses face right in a three-quarter side view, full body, same scale, aligned on the same baseline, each pose centered in its own equal third of the image with WIDE empty white gaps between them so they never touch or overlap. Hand-painted cozy storybook cartoon in the same art style as the reference character (soft warm lighting, gentle painterly shading, thin warm brown outline, muted earthy palette with glowing accent colors), cute proportions about 3 heads tall, readable silhouette when shown small. A humanoid fairy with a human face and hands, not an insect. Plain flat pure white background, no ground, no cast shadow, no glow ring, no frames, no dividing lines, no panels. no text, no letters, no numbers, no labels, no watermark, no logo, no signature --ar 16:9
```

파일명

```
fairy_voltea_sheet
```

### 6. 루나리스 — 달그림자의 요정 · 동작 시트 1장(날갯짓 위·아래 + 스킬 시전)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Character animation sprite sheet of ONE small fantasy fairy, drawn THREE times side by side in a single horizontal row, the SAME character in every pose with the identical face, hair, outfit, colors, proportions and size. The character: A small fantasy fairy character named Lunaris, the Fairy of the Moonshade: a quiet, mysterious fairy with long indigo-silver hair and a crescent-moon hairpin, softly glowing pale eyes, wearing a hooded cloak the deep violet of the night sky dotted with tiny stars, holding a small curved crescent-moon blade that glows silver. Her wings are like torn translucent night silk, dark violet fading to a silver crescent glow at the edges, NOT insect wings. Pose 1 (left): flying facing right, wings raised UP at the top of a wingbeat. Pose 2 (middle): exactly the same as pose 1 except the wings are swept DOWN at the bottom of a wingbeat and the body sits very slightly lower. Pose 3 (right): skill-casting pose, swinging her crescent-moon blade forward, leaving a short glowing silver crescent slash, wings spread open, the magic effect kept small and close to her body. All three poses face right in a three-quarter side view, full body, same scale, aligned on the same baseline, each pose centered in its own equal third of the image with WIDE empty white gaps between them so they never touch or overlap. Hand-painted cozy storybook cartoon in the same art style as the reference character (soft warm lighting, gentle painterly shading, thin warm brown outline, muted earthy palette with glowing accent colors), cute proportions about 3 heads tall, readable silhouette when shown small. A humanoid fairy with a human face and hands, not an insect. Plain flat pure white background, no ground, no cast shadow, no glow ring, no frames, no dividing lines, no panels. no text, no letters, no numbers, no labels, no watermark, no logo, no signature --ar 16:9
```

파일명

```
fairy_lunaris_sheet
```

### 7. 티타니아 — 꽃의 여왕 · 동작 시트 1장(날갯짓 위·아래 + 스킬 시전)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Character animation sprite sheet of ONE small fantasy fairy, drawn THREE times side by side in a single horizontal row, the SAME character in every pose with the identical face, hair, outfit, colors, proportions and size. The character: A small fantasy fairy character named Titania, the Queen of Blossoms: an elegant, kind fairy queen with long wavy strawberry-blonde hair woven with small blossoms, a delicate golden flower crown, warm rose eyes, wearing a flowing gown of layered rose-pink and cream flower petals, one hand raised gracefully, tiny petals drifting around her. Her wings are large and made of soft overlapping flower petals in pink and cream with golden edges, NOT insect wings. Pose 1 (left): flying facing right, wings raised UP at the top of a wingbeat. Pose 2 (middle): exactly the same as pose 1 except the wings are swept DOWN at the bottom of a wingbeat and the body sits very slightly lower. Pose 3 (right): skill-casting pose, spreading both arms wide as a small swirl of glowing flower petals bursts around her, her crown shining, wings spread open, the magic effect kept small and close to her body. All three poses face right in a three-quarter side view, full body, same scale, aligned on the same baseline, each pose centered in its own equal third of the image with WIDE empty white gaps between them so they never touch or overlap. Hand-painted cozy storybook cartoon in the same art style as the reference character (soft warm lighting, gentle painterly shading, thin warm brown outline, muted earthy palette with glowing accent colors), cute proportions about 3 heads tall, readable silhouette when shown small. A humanoid fairy with a human face and hands, not an insect. Plain flat pure white background, no ground, no cast shadow, no glow ring, no frames, no dividing lines, no panels. no text, no letters, no numbers, no labels, no watermark, no logo, no signature --ar 16:9
```

파일명

```
fairy_titania_sheet
```

### 8. 아스테리아 — 별빛의 수호자 · 동작 시트 1장(날갯짓 위·아래 + 스킬 시전)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Character animation sprite sheet of ONE small fantasy fairy, drawn THREE times side by side in a single horizontal row, the SAME character in every pose with the identical face, hair, outfit, colors, proportions and size. The character: A small fantasy fairy character named Asteria, the Guardian of Starlight: a calm, brave protector fairy with starry silver-white hair and a slim silver circlet with a small star, steady blue eyes, wearing light armor of pale gold and starlight blue with a short flowing white cape, holding a small star-shaped shield in front of her. Her wings are soft wings of white light sprinkled with tiny star sparkles, NOT insect wings. Pose 1 (left): flying facing right, wings raised UP at the top of a wingbeat. Pose 2 (middle): exactly the same as pose 1 except the wings are swept DOWN at the bottom of a wingbeat and the body sits very slightly lower. Pose 3 (right): skill-casting pose, holding her star-shaped shield high as it flares into a small glowing dome of starlight around her, wings spread open, the magic effect kept small and close to her body. All three poses face right in a three-quarter side view, full body, same scale, aligned on the same baseline, each pose centered in its own equal third of the image with WIDE empty white gaps between them so they never touch or overlap. Hand-painted cozy storybook cartoon in the same art style as the reference character (soft warm lighting, gentle painterly shading, thin warm brown outline, muted earthy palette with glowing accent colors), cute proportions about 3 heads tall, readable silhouette when shown small. A humanoid fairy with a human face and hands, not an insect. Plain flat pure white background, no ground, no cast shadow, no glow ring, no frames, no dividing lines, no panels. no text, no letters, no numbers, no labels, no watermark, no logo, no signature --ar 16:9
```

파일명

```
fairy_asteria_sheet
```

### 9. 요정 알

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game item illustration of a single magical fairy egg: a smooth oval egg with a pearly white shell, faint swirling rainbow shimmer across the surface, a few tiny glowing star specks and a delicate curling silver vine pattern, a soft gentle glow from within. Upright, straight-on front view, no perspective tilt. Hand-painted cozy storybook style matching the reference (soft warm lighting, gentle painterly shading, thin warm brown outline). Single object centered, square 1:1 image, plain flat pure white background, no nest, no ground, no cast shadow, no glow ring, no frame. no insects, no text, no letters, no numbers, no watermark, no logo --ar 1:1
```

파일명

```
fairy_egg
```

### 10. 요정 둥지

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game illustration of an EMPTY fairy nest where a magical egg will be placed: a round, cozy nest woven from thin silver twigs, soft green moss and scattered flower petals, with two tiny glowing mushrooms and a few small fireflies-of-light (just glowing dots, no insects) at the rim, a soft warm light glowing up from the empty hollow in the middle. Slightly elevated front view so the empty hollow is visible. The center of the nest is EMPTY, no egg, no objects inside. Hand-painted cozy storybook style matching the reference (soft warm lighting, gentle painterly shading, thin warm brown outline, muted earthy palette). Single object centered, landscape 4:3 image, plain flat pure white background, no ground, no cast shadow. no characters, no insects, no text, no letters, no numbers, no watermark, no logo --ar 4:3
```

파일명

```
fairy_nest
```

### 11. 가속기 (30분)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a small time accelerator item: a tiny simple hourglass with a light wooden frame, filled with softly glowing pink fairy sand flowing down, a couple of little sparkles. Small and humble looking, the smallest of a set of three. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
acc30m
```

### 12. 가속기 (2시간)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a medium time accelerator item: an ornate hourglass with a polished silver frame, filled with glowing sky-blue fairy sand flowing down, two small feathered wings on the sides of the frame, several sparkles. Noticeably fancier than a plain wooden hourglass, the middle of a set of three. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
acc2h
```

### 13. 가속기 (8시간)

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a large, precious time accelerator item: a grand hourglass with an ornate gold frame set with small violet gems, filled with glowing violet starry fairy sand with tiny stars flowing down, large golden feathered wings spread on both sides, radiant sparkles. Clearly the most luxurious of a set of three. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
acc8h
```

### 14. 속성석 — 공격

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a magic attribute stone of ATTACK: a faceted ruby-red crystal gem shaped like a rising flame, with a warm inner glow and a tiny spark on top. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
stone_attack
```

### 15. 속성석 — 체력

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a magic attribute stone of HEALTH: a smooth emerald-green crystal gem shaped like a plump heart, with a soft healing inner glow and a tiny leaf sprout on top. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
stone_hp
```

### 16. 속성석 — 방어

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a magic attribute stone of DEFENSE: a sturdy honey-amber topaz crystal gem cut in the shape of a small round shield, with visible ring patterns inside and a warm steady glow. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
stone_defense
```

### 17. 속성석 — 공격속도

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a magic attribute stone of SPEED: a slender mint-green and white crystal gem twisted like a swirling gust of wind, with small wisps of air curling around it. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
stone_attackSpeed
```

### 18. 속성석 — 치명 피해

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a magic attribute stone of CRITICAL DAMAGE: a sharp electric-yellow citrine crystal gem shaped like a lightning bolt, crackling with tiny bright sparks. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
stone_critDamage
```

### 19. 속성석 — 보스 피해

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a magic attribute stone of BOSS DAMAGE: a deep violet amethyst crystal gem shaped like a crescent moon with a sharp silver edge like a blade, glowing with a cold silver light. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
stone_bossDamage
```

### 20. 속성석 — 곤충 기여

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a magic attribute stone of COMPANION POWER: a soft rose-quartz pink crystal gem shaped like a five-petal flower blossom, with a warm golden center and a gentle glow. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
stone_petShare
```

### 21. 요정 가루

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for fairy dust, a leveling material: a small round glass vial with a cork stopper, filled with glittering pale-gold and lilac fairy dust, a little of the shimmering dust spilling out in a sparkling swirl. readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fairy_dust
```

### 22. 요정 화면 배경

```
Use the attached image only as the art style reference. Do NOT copy its subject. Vertical mobile game menu background for a hidden fairy glade at twilight: a small magical clearing in a deep forest, a ring of softly glowing mushrooms, tall flower stems with luminous blossoms, drifting motes of golden light, a gentle moonlit mist and a faint shimmering fairy ring on the mossy ground. All of the scene detail is in the TOP THIRD of the image only. The lower two-thirds fades smoothly into a very dark, calm, plain deep forest-green and indigo shadow with almost no detail, so that cards and text can sit on top of it. Soft vignette at the edges, atmospheric depth, hand-painted cozy storybook style matching the reference (soft warm lighting, gentle painterly shading, muted earthy palette with glowing accents), no characters, no fairies, no insects, no people, no text, no letters, no numbers, no logo, no watermark, no signature --ar 9:16
```

파일명

```
fairy_bg
```

### 23. 캐릭터 화면 요정 탭 아이콘

> 첨부: `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\ui\tab\skills.webp` — 옆 탭 아이콘과 같은 모양으로(캐릭터 화면 [능력치][요정][스킬] 탭에 들어간다).
> 이 한 장만 `assets/images/ui/tab/` 에 들어간다(나머지는 `assets/images/fairies/`).

```
Use the attached image only as the art style reference, matching its framing, size and look exactly (a single glowing object sitting on a small mossy mound with a few leaves, soft glow and tiny sparkles around it). Do NOT copy its subject. Game tab icon for FAIRIES: a small glowing fairy lantern made of a translucent glass flower bud, inside it a tiny silhouette of a winged fairy made of soft golden light, two delicate translucent petal-like wings unfolding from the sides of the bud, resting on a small mossy mound with a few leaves. readable at 20 pixels. Hand-painted cozy storybook game icon, soft painterly shading, thin warm brown outline, muted earthy palette with a warm golden glow. Single object centered, square 1:1 image, plain flat pure white background. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo --ar 1:1
```

파일명

```
fairy
```
