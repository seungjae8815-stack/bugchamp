# 앱 아이콘 개편 프롬프트 (2026-10-15)

지금 아이콘: 어두운 배경 + 어두운 상상 곤충(뿔 셋·집게) → 작게 보면 무엇인지 안 읽히고, 게임 그림체(따뜻한 동화풍)와 다르다.
목표: **스토어 목록에서 0.5초 안에 "장수풍뎅이·사슴벌레 게임"으로 읽히는 밝은 아이콘.**

순서: 1번 시트(시안 4개)를 받아 하나를 고른다 → 2번에서 고른 시안만 1024 크기로 다시 받는다.
받은 그림은 아래 15% 를 잘라 Gemini 로고째 버린다(시트는 각 칸을 잘라 본다).

---

### 1. 아이콘 시안 시트 (2×2)

```
A 2x2 sheet of four different mobile game app icon concepts, each in its own rounded-square tile with wide even gaps between tiles, no text, no letters, no numbers anywhere. Order from top-left: (1) top-left: a Japanese rhinoceros beetle and a stag beetle locking horns head-on in a fierce shoving match on top of a round wooden tree-stump arena, a bright golden impact burst between them, low camera angle, both beetles large and filling the tile; (2) top-right: a single heroic Japanese rhinoceros beetle seen from the front three-quarter view, its big forked horn raised proudly, glossy chestnut-brown shell with a warm rim light, standing on mossy wood, filling almost the whole tile; (3) bottom-left: a cheerful young boy explorer in a khaki bucket hat with a feather, holding up a big shiny rhinoceros beetle in both hands with a proud grin, a bug net over his shoulder, only head, shoulders and the beetle visible, the beetle large in the foreground; (4) bottom-right: a giant stag beetle with huge jagged mandibles standing on a tree stump under a small golden champion crown floating above it, sparkles around. Style for all four: warm hand-drawn storybook illustration like a premium mobile game, clean dark-brown ink outlines, painterly soft shading, rich saturated colors, bright warm background of sunlit forest green fading to golden yellow, strong silhouette and high contrast so the beetle reads clearly at very small size, centered subject, no border frame, no UI. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```
파일명
```
app_icon_concepts
```

---

### 2. 고른 시안 — 큰 아이콘 1장

1번에서 고른 칸의 설명을 아래 `[SUBJECT]` 자리에 그대로 넣는다(예: 1번 칸을 골랐다면 "a Japanese rhinoceros beetle and a stag beetle locking horns ...").

```
A single square mobile game app icon, full-bleed artwork filling the entire square edge to edge (no rounded corners, no border, no frame), no text, no letters, no numbers. Subject: [SUBJECT]. Style: warm hand-drawn storybook illustration like a premium mobile game, clean dark-brown ink outlines, painterly soft shading, rich saturated colors, bright warm background of sunlit forest green fading to golden yellow, strong silhouette and high contrast so the beetle reads clearly even at 48 pixels, the subject large and centered, filling about 80 percent of the square. Composition: keep the main subject and everything important in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```
파일명
```
app_icon_new
```

---

## 받은 뒤 할 일 (Claude)
- 아래 15% 를 잘라 정사각형으로 맞추기 → Play 512×512 · App Store 1024×1024(투명 없음) · 안드로이드 적응형 아이콘(앞·배경 분리 여유 확인).
- 바꾸는 파일: `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\icon\app_icon.png` → `flutter_launcher_icons` 다시 생성 · `C:\Users\Lenovo\Desktop\coding\BugChamp\store_assets\app_icon_512.png`.
- 아이콘은 앱 빌드에 들어가므로 **다음 버전 빌드**와 함께 나간다. 스토어 목록 아이콘만 먼저 바꾸는 것은 Play 스토어 등록정보 실험(A/B)으로 시험해 볼 수 있다.
