# 길드 그림 프롬프트 (1.0.15)

Gemini 에 기존 하단 메뉴 그림(예: 홈 메뉴) 한 장을 **스타일 참고로 첨부**하고, 아래 코드블록을 통째로 붙여넣는다.
받은 그림은 `C:\Users\Lenovo\Downloads` 에 아래 파일명으로 저장하면 내가 잘라서 넣는다.

⚠️ **Gemini 로고 대비(2026-10-05)**: Gemini 가 오른쪽 아래에 로고를 찍는다. 모든 프롬프트 끝에 "아래 15% 는 비운 배경" 문구를 넣어 두었다 — 받은 그림은 아래 15% 를 잘라 로고째 버린다.

- 하단 메뉴 → `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\ui\nav\guild.webp`
- 준비 중 그림 → `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\ui\guild_coming_soon.webp`

⚠️ 준비 중 그림에는 **글씨를 넣지 않는다** — "준비 중"은 게임이 한국어·영어·일본어로 그림 위에 얹는다.

---

## 하단 메뉴 (화면에서 약 28px — 물건 하나의 굵은 실루엣)

### 1. 길드

```
Use the attached image only as the art style reference. Do NOT copy its subject. Menu tab icon for Guild: a small heraldic wooden shield with a golden stag-beetle emblem in the center and two crossed leaf banners behind it, readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
nav_guild
```

---

## 길드 탭 "준비 중" 화면 (가로 4:3 · 가운데에 글씨 띠가 얹힌다)

### 2. 길드전 준비 중

```
Use the attached image only as the art style reference. Do NOT copy its subject. Wide illustration for a guild war that is still being prepared: two rival insect guild camps face each other across a forest clearing at golden dusk — on the left a camp of stag beetles and rhinoceros beetles under a moss-green banner, on the right a camp of mantises and wasps under a honey-amber banner. In the middle a half-built wooden arena with scaffolding, stacked logs, a hanging rope and small worker ants carrying planks, showing it is under construction. Fireflies glow in the air, warm lantern light, soft painterly depth. Keep the horizontal middle band of the image calm and less detailed (a text ribbon will be placed over it). Style: cozy naturalist storybook mobile game art, moss green, honey amber, warm bark brown, soft cream palette, semi-realistic painterly shading, soft rim light, high detail. Landscape 4:3 image, no characters cut in half at the edges. no text, no letters, no numbers, no signs with writing, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_coming_soon
```


# 길드 공개용 그림 (1.0.18, 2026-10-05 추가)

받은 그림은 `C:\Users\Lenovo\Downloads` 에 아래 파일명으로 저장하면 내가 배경을 지우고 잘라서
`C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\ui\guild\` 에 넣는다.
번호는 위 1·2번에 이어서 3번부터. **꼭 필요한 것(3~26, 24장)** 먼저, **있으면 좋은 것(27~47, 21장)** 은 나중에.
(Downloads 에서 겹치지 않게 파일명에 `guild_` 를 붙였다 — 앱 폴더에 넣을 때는 떼고 넣는다. 예: `guild_rank_elite` → `ui/guild/rank_elite.webp`. 넣을 때 `pubspec.yaml` assets 에 `assets/images/ui/guild/` 줄도 추가.)
ank_elite.webp`. 넣을 때 `pubspec.yaml` assets 에 `assets/images/ui/guild/` 줄도 추가.)
스타일 참고 그림(기존 하단 메뉴 그림 한 장) 첨부는 위와 같다.


## 꼭 필요한 것 ① 길드 문장(엠블럼) 10종

길드를 만들 때 고르는 문장. 목록·길드 화면 상단·길드전 대진에 뜬다(화면에서 약 40~64px). ⚠️ 문장 고르기 기능은 아직 없다 — 그림이 오면 만든다.

### 3. 길드 문장 — 장수풍뎅이

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a rhinoceros beetle with a big curved horn, seen from the front as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_01
```

---

### 4. 길드 문장 — 사슴벌레

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a stag beetle with two large crossed mandibles as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_02
```

---

### 5. 길드 문장 — 사마귀

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a praying mantis raising both scythe arms as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_03
```

---

### 6. 길드 문장 — 나비

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a swallowtail butterfly with spread wings as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_04
```

---

### 7. 길드 문장 — 벌

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a honeybee in front of a small hexagon honeycomb as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_05
```

---

### 8. 길드 문장 — 반딧불이

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a glowing firefly with a warm yellow light at its tail as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_06
```

---

### 9. 길드 문장 — 잠자리

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a dragonfly with four long transparent wings spread as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_07
```

---

### 10. 길드 문장 — 무당벌레

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a red ladybug with black spots, wings slightly open as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_08
```

---

### 11. 길드 문장 — 개미

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a sturdy worker ant holding a leaf over its head as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_09
```

---

### 12. 길드 문장 — 매미

```
Use the attached image only as the art style reference. Do NOT copy its subject. Guild emblem icon: a rounded heraldic shield badge, inside it a cicada on a short twig with glassy veined wings as the central emblem, a small laurel of leaves at the bottom of the shield, readable at 40 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_emblem_10
```

---


## 꼭 필요한 것 ② 길드 코인 · 길드 보스


### 13. 길드 코인

```
Use the attached image only as the art style reference. Do NOT copy its subject. Currency icon for guild coins: a thick round bronze-gold coin stamped with a small heraldic shield and a stag-beetle silhouette, slightly tilted to show its thick ridged edge, a soft shine highlight, readable at 20 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_coin
```

---

### 14. 길드 보스

```
Use the attached image only as the art style reference. Do NOT copy its subject. Full-body boss monster for a weekly guild raid: a gigantic ancient armored queen hornet with cracked amber armor plates, glowing honey-orange eyes, a long stinger, tattered translucent wings, mossy growths and small crystals on its back, menacing but cute enough for an all-ages game, three-quarter front view, full body visible with margin around it. Single creature centered, square 1:1 image, plain flat pale sage-green background. Style: cozy naturalist storybook mobile game art, moss green, honey amber, warm bark brown, soft cream palette, semi-realistic painterly shading, soft rim light, high detail. no text, no letters, no numbers, no signs with writing, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_boss
```

---


## 꼭 필요한 것 ③ 직책 뱃지 2 · 멤버 등급 뱃지 4

멤버 목록 이름 옆(화면에서 약 18~24px) — 작게 보여도 구분되게 모양을 크게 다르게.

### 15. 직책 — 길드장

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small badge icon for guild leader: a golden crown with three leaf-shaped points and a honey-amber gem in the center, readable at 18 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_role_leader
```

---

### 16. 직책 — 부길드장

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small badge icon for vice guild leader: a silver crest shaped like a single upright leaf with a small blue gem, simpler and smaller-looking than a crown, readable at 18 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_role_deputy
```

---

### 17. 멤버 등급 — 새내기

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small rank badge icon for a guild member rank: a tiny green sprout with two round leaves growing from a small soil mound, readable at 20 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_rank_rookie
```

---

### 18. 멤버 등급 — 일꾼

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small rank badge icon for a guild member rank: a small wooden badge with a crossed shovel and a leaf, warm brown wood, readable at 20 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_rank_worker
```

---

### 19. 멤버 등급 — 정예

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small rank badge icon for a guild member rank: a bronze-gold star badge with a beetle horn motif at the top, readable at 20 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_rank_elite
```

---

### 20. 멤버 등급 — 원로

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small rank badge icon for a guild member rank: an ornate amber medallion with a golden oak-leaf wreath and a tiny crown on top, the most precious-looking, readable at 20 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_rank_elder
```

---


## 꼭 필요한 것 ④ 길드 내부 탭 아이콘 6

길드 화면 위 탭(화면에서 약 22px).

### 21. 탭 — 미션

```
Use the attached image only as the art style reference. Do NOT copy its subject. Tab icon for the guild mission tab: a rolled parchment quest scroll tied with a green ribbon and a small leaf, readable at 22 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_tab_mission
```

---

### 22. 탭 — 보스

```
Use the attached image only as the art style reference. Do NOT copy its subject. Tab icon for the guild boss tab: a fierce hornet head with glowing eyes on a small round red shield, readable at 22 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_tab_boss
```

---

### 23. 탭 — 길드전

```
Use the attached image only as the art style reference. Do NOT copy its subject. Tab icon for the guild war tab: two crossed wooden swords over a small banner flag, readable at 22 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_tab_war
```

---

### 24. 탭 — 성장

```
Use the attached image only as the art style reference. Do NOT copy its subject. Tab icon for the guild growth tab: a young sapling with glowing leaves and a small upward arrow made of leaves, readable at 22 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_tab_growth
```

---

### 25. 탭 — 상점

```
Use the attached image only as the art style reference. Do NOT copy its subject. Tab icon for the guild shop tab: a small wooden market stall with a leaf-green awning and a coin pouch, readable at 22 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_tab_shop
```

---

### 26. 탭 — 멤버

```
Use the attached image only as the art style reference. Do NOT copy its subject. Tab icon for the guild members tab: three small round insect friends (beetle, ant, ladybug) standing together, readable at 22 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_tab_members
```

---


## 있으면 좋은 것 ① 미션 지역 카드 6

미션 게시판 카드 배경(가로 4:3, 카드 위에 글씨·버튼이 얹힌다 — 아래쪽 1/3 은 단순하게).

### 27. 미션 지역 — 숲

```
Use the attached image only as the art style reference. Do NOT copy its subject. Wide background illustration for a guild quest card: a sunlit deep forest path with giant ferns and mossy roots, small insects visible far in the scene, no main character. Keep the bottom third simple and calm (text and buttons will be placed over it). Landscape 4:3 image. Style: cozy naturalist storybook mobile game art, moss green, honey amber, warm bark brown, soft cream palette, semi-realistic painterly shading, soft rim light, high detail. no text, no letters, no numbers, no signs with writing, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_mission_forest
```

---

### 28. 미션 지역 — 동굴

```
Use the attached image only as the art style reference. Do NOT copy its subject. Wide background illustration for a guild quest card: a glowing crystal cave entrance with luminous mushrooms, small insects visible far in the scene, no main character. Keep the bottom third simple and calm (text and buttons will be placed over it). Landscape 4:3 image. Style: cozy naturalist storybook mobile game art, moss green, honey amber, warm bark brown, soft cream palette, semi-realistic painterly shading, soft rim light, high detail. no text, no letters, no numbers, no signs with writing, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_mission_cave
```

---

### 29. 미션 지역 — 늪

```
Use the attached image only as the art style reference. Do NOT copy its subject. Wide background illustration for a guild quest card: a misty swamp with lily pads, cattails and twisted roots, small insects visible far in the scene, no main character. Keep the bottom third simple and calm (text and buttons will be placed over it). Landscape 4:3 image. Style: cozy naturalist storybook mobile game art, moss green, honey amber, warm bark brown, soft cream palette, semi-realistic painterly shading, soft rim light, high detail. no text, no letters, no numbers, no signs with writing, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_mission_swamp
```

---

### 30. 미션 지역 — 유적

```
Use the attached image only as the art style reference. Do NOT copy its subject. Wide background illustration for a guild quest card: overgrown ancient stone ruins with vines and a broken archway, small insects visible far in the scene, no main character. Keep the bottom third simple and calm (text and buttons will be placed over it). Landscape 4:3 image. Style: cozy naturalist storybook mobile game art, moss green, honey amber, warm bark brown, soft cream palette, semi-realistic painterly shading, soft rim light, high detail. no text, no letters, no numbers, no signs with writing, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_mission_ruins
```

---

### 31. 미션 지역 — 협곡

```
Use the attached image only as the art style reference. Do NOT copy its subject. Wide background illustration for a guild quest card: a warm red-rock canyon with a rope bridge and dry shrubs, small insects visible far in the scene, no main character. Keep the bottom third simple and calm (text and buttons will be placed over it). Landscape 4:3 image. Style: cozy naturalist storybook mobile game art, moss green, honey amber, warm bark brown, soft cream palette, semi-realistic painterly shading, soft rim light, high detail. no text, no letters, no numbers, no signs with writing, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_mission_canyon
```

---

### 32. 미션 지역 — 초원

```
Use the attached image only as the art style reference. Do NOT copy its subject. Wide background illustration for a guild quest card: a wide flower meadow with tall grass and a gentle breeze, small insects visible far in the scene, no main character. Keep the bottom third simple and calm (text and buttons will be placed over it). Landscape 4:3 image. Style: cozy naturalist storybook mobile game art, moss green, honey amber, warm bark brown, soft cream palette, semi-realistic painterly shading, soft rim light, high detail. no text, no letters, no numbers, no signs with writing, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_mission_meadow
```

---


## 있으면 좋은 것 ② 길드전 일차 아이콘 7

길드전 탭의 7일 줄(화면에서 약 24px).

### 33. 길드전 — 1일 육성

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for guild war day theme: a speckled insect egg in a soft nest of leaves with a small heart, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_war_breed
```

---

### 34. 길드전 — 2일 제련

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for guild war day theme: a small anvil with a hammer and a glowing amber spark, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_war_forge
```

---

### 35. 길드전 — 3일 사냥

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for guild war day theme: a bug-catching net with a wooden handle, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_war_hunt
```

---

### 36. 길드전 — 4일 결투

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for guild war day theme: two beetle horns clashing with a small impact spark, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_war_duel
```

---

### 37. 길드전 — 5일 수련

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for guild war day theme: a wooden training dummy with a leaf headband, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_war_train
```

---

### 38. 길드전 — 6일 보스

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for guild war day theme: a cracked amber hornet mask, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_war_boss
```

---

### 39. 길드전 — 7일 대결

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for guild war day theme: a golden trophy cup with two crossed beetle horns behind it, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_war_clash
```

---


## 있으면 좋은 것 ③ 길드 없음 화면 · 성장 탭 아이콘 7


### 40. 길드 없음 화면

```
Use the attached image only as the art style reference. Do NOT copy its subject. Wide welcoming illustration: a cozy guild hall built inside a giant hollow tree stump, warm lantern light glowing from round windows, a big banner with a stag-beetle emblem above the wooden door, friendly insects (beetles, ants, a ladybug, a butterfly) waving and inviting the viewer in, fireflies in the dusk air. Keep the top third calm and simple (a title will be placed over it). Landscape 4:3 image. Style: cozy naturalist storybook mobile game art, moss green, honey amber, warm bark brown, soft cream palette, semi-realistic painterly shading, soft rim light, high detail. no text, no letters, no numbers, no signs with writing, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_none
```

---

### 41. 성장 — 출석

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for a guild growth menu: a wooden guild signboard post with a green check-mark leaf pinned on it, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_attend
```

---

### 42. 성장 — 스킬 — 공격

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for a guild growth menu: a sharp golden beetle horn with a small red glow, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_skill_attack
```

---

### 43. 성장 — 스킬 — 체력

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for a guild growth menu: a red heart shaped from two leaves with a small glow, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_skill_hp
```

---

### 44. 성장 — 스킬 — 골드

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for a guild growth menu: a small stack of gold coins with a sparkle, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_skill_gold
```

---

### 45. 성장 — 스킬 — 재료

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for a guild growth menu: a pile of chitin shards and a mineral crystal, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_skill_material
```

---

### 46. 성장 — 스킬 — 경험치

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for a guild growth menu: a glowing green book with a leaf bookmark, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_skill_xp
```

---

### 47. 성장 — 스킬 — 미션 보상

```
Use the attached image only as the art style reference. Do NOT copy its subject. Small icon for a guild growth menu: an open treasure chest with a quest scroll on top, readable at 24 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, subtle drop shadow, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt. no text, no letters, no numbers, no border, no frame, no watermark, no logo. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```

파일명

```
guild_skill_mission
```

---


## 새로 안 그려도 되는 것

- 길드 티어 브론즈~다이아: 결투 리그 그림 `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\ui\league\*.png` 를 그대로 쓴다.
- 상점의 요정 가루·스킬 조각·화석·재료: 기존 그림을 쓴다.

