# Bug Champ — 결투 탭 그림 프롬프트 (Gemini · 4장)

> **쓰는 법**
> 1. 화풍을 맞추려면 기존 그림을 **함께 첨부**하세요.
>    - 1번(배경): `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\duel\arena_wood_side.webp`
>    - 2~4번(칸·아이콘): `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\upgrades\attack.webp`
> 2. 그림마다 프롬프트 칸을 **통째로 복사 → Gemini 에 붙여넣기**. 그림마다 **새 대화창**에서 뽑으세요
>    (앞 대화의 그림이 섞여 나온 적이 있다 — 참나무하늘소에 사마귀 앞다리).
> 3. 저장할 때 아래 **파일명** 칸을 복사해 붙여넣고 한 폴더에 모아 주세요.
> 4. 다 만드시면 폴더 경로를 알려 주세요. 배경 제거·워터마크 제거·크기 맞춤까지 하고 화면에 연결합니다.

## 화면 구성과 그림이 들어갈 자리

```
┌────────────────────────────┐
│  [배경 1: 결투장 로비 — 위쪽이 장면] │
│  ┌───┐ ┌───┐ ┌───┐          │  ← 출정 칸 3개 = 그림 2(받침대 틀)
│  │ 1 │ │ 2 │ │ 3 │          │
│  └───┘ └───┘ └───┘          │
│  [회복실 = 그림 3] [훈련소 = 그림 4] │
│  ── 리그 엠블럼 · 순위표 ──      │  ← 배경 아래쪽은 어둡고 조용해야 글씨가 읽힌다
│  1위 …  2위 …                 │
│  [내 순위]  [전투 시작]          │
└────────────────────────────┘
```

- 지금 화면이 밋밋한 이유: 배경이 단색 회색이고, 출정 칸이 빈 상자라 "곤충을 내보내는 곳"이라는 느낌이 없다.
- 배경 위쪽 1/3 에 **결투장 입구 장면**(여기가 곤충 결투장이라는 한눈에 보이는 장소감), 아래 2/3 는 순위표가
  올라가므로 **어둡고 무늬 없이** 둔다. 출정 칸은 **받침대(시상대) 틀**로 바꿔 곤충이 올라선 느낌을 준다.

---

### 1. 결투장 로비 배경

```
Use the attached image only as the art style reference. Do NOT copy its subject. Vertical mobile game menu background for an insect wrestling stadium lobby deep in a forest at dusk: the entrance of a grand arena built inside a giant hollow oak tree, carved bark arches, rows of tiny wooden bleachers made of bark and acorn caps, strings of glowing firefly lanterns, small leaf-shaped pennant banners in moss green and honey amber, a round mossy stump fighting ring glimpsed through the arch in the distance. All of the scene detail is in the TOP THIRD of the image only. The lower two-thirds fades smoothly into a very dark, calm, plain deep forest-brown shadow with almost no detail, so that a list of text can sit on top of it. Soft warm vignette at the edges, atmospheric depth, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), no characters, no insects, no people, no text, no letters, no numbers, no logo, no watermark, no signature --ar 9:16
```

파일명

```
battle_hub_bg
```

### 2. 출정 칸 받침대 틀

```
Use the attached image only as the art style reference. Do NOT copy its subject. A single empty display slot for a mobile game team-selection screen: a tall rounded-rectangle frame made of carved warm bark with small moss tufts and two tiny acorn caps at the top corners, and at the bottom inside the frame a small round tree-stump podium with visible growth rings where a beetle will stand. The inside of the frame above the podium is completely EMPTY and plain dark wood-brown, with no objects and no insects. Straight-on front view, flat, no perspective tilt, symmetrical. Style: glossy stylized mobile game UI element, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, thick warm brown outline, high detail. Single object centered, portrait 3:4 image, plain flat pale sage-green background around the frame. no text, no letters, no numbers, no watermark, no logo --ar 3:4
```

파일명

```
squad_slot
```

### 3. 회복실 아이콘

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a bug recovery room: a cozy little bed made from a curled green leaf with a soft moss pillow, a small glowing dewdrop healing potion in a tiny acorn cup beside it, and a little white leaf bandage with a green cross, gentle healing sparkles, readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo.
```

파일명

```
hub_recovery
```

### 4. 훈련소 아이콘

```
Use the attached image only as the art style reference. Do NOT copy its subject. Game icon for a bug training ground: a tiny dumbbell made of a twig bar with two acorns as weights, leaning against a small wooden training dummy shaped like a round beetle with a painted target on its shell, a few little effort sparkles, readable at 28 pixels. Style: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail. Single object centered, square 1:1 image, plain flat pale sage-green background, front view, no perspective tilt, NO drop shadow. no real insects, no text, no letters, no numbers, no border, no frame, no watermark, no logo.
```

파일명

```
hub_training
```

---

### 5. 심연 주간 순위 배너 (랭킹 → 심연 탭 맨 위)

참고 그림(화풍): `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\duel\battle_hub_bg.webp`
화면 맨 위를 가로로 채우고, 아래쪽 1/3 위에 "심연 주간 순위" 글씨와 남은 시간이 얹힌다 — 그래서 **아래쪽은 어둡고 조용하게**.

```
Use the attached image only as the art style reference. Do NOT copy its subject. Wide mobile game banner illustration of "the Abyss": a vast bottomless chasm opening beneath the roots of a giant ancient oak tree deep in a forest, seen from the rim looking down. Twisting roots and mossy rock ledges spiral downward like endless floors, each ledge lit by clusters of glowing violet and teal bioluminescent mushrooms and crystals, faint drifting spores and fireflies, a cold misty glow rising from far below, and a few pairs of tiny glowing insect eyes hidden in the darkness of the depths. Mysterious and adventurous, not scary. The upper two-thirds holds the scene detail; the lower third fades smoothly into a very dark, calm, plain deep indigo-black with almost no detail, so a title can sit on top of it. Cozy naturalist cartoon, semi-realistic stylized, hand-painted storybook texture, rounded friendly forms, palette of deep indigo, violet, teal glow and warm bark brown, soft rim light, atmospheric depth, no characters, no people, no text, no letters, no numbers, no logo, no watermark, no signature --ar 2:1
```

파일명

```
abyss_banner
```
