# 로드맵 난이도 버튼 4개 (한 장 시트)

2026-09-22 사장님 요청. 로드맵 화면 상단의 쉬움·보통·어려움·극한 버튼.

- **네 개를 한 장에** 그린다(모양·크기·두께를 똑같이 맞추려고). 받은 그림은 Claude 가
  네 조각으로 잘라 배경을 지우고 아래 경로에 넣는다.
- **글자는 그림에 넣지 않는다** — 한·영·일 세 언어라 글자는 코드가 버튼 위에 얹는다.
  그래서 버튼 가운데~오른쪽은 비워 둔 판이고, 왼쪽 끝에만 난이도 문양이 있다.
- **못 가는 난이도는 따로 그리지 않는다** — 같은 그림을 코드가 흑백 + 자물쇠로 만든다.

넣을 곳(Claude 가 처리):

```
C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\ui\tier
```

---

### 1. 난이도 버튼 4개

```
a sheet of four game UI buttons arranged in a 2x2 grid with wide even gaps between them, all four the exact same size and shape: wide horizontal rounded-rectangle plaques about three times wider than tall, thick carved rim, each plaque has one small round emblem medallion at its far left end and the rest of the plaque is an empty smooth panel with no marks (space for a label added later). top-left: EASY, fresh spring moss green plaque, emblem is a small green leaf sprout. top-right: NORMAL, cool river-stone blue plaque, emblem is a small blue mountain peak. bottom-left: HARD, glowing ember orange plaque, emblem is a small orange flame. bottom-right: EXTREME, deep crimson red plaque with dark charred edges, emblem is a small red horned beetle skull. difficulty clearly rises from calm to dangerous, each color strongly distinct, glossy game UI button, bold thick dark outline, cream rim light, strong readable silhouette, flat plain white background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, subtle ambient occlusion, mobile game art, crisp high detail, no text, no letters, no numbers, no watermark, no signature --ar 16:9 --style raw --v 7
```

파일명

```
tier_buttons
```

---

## 받은 뒤 Claude 가 하는 일

1. 2×2 로 잘라 `tier_0`(쉬움) · `tier_1`(보통) · `tier_2`(어려움) · `tier_3`(극한) 으로 저장
   (배경 제거 · 가로 600px · RGBA WebP q92).
2. 버튼 판을 그림으로 바꾸고 글자는 그 위에, 문양 오른쪽 빈 판에 얹는다.
3. 지금 난이도 = 원본 + 밝은 테두리 · 갈 수 있는 난이도 = 약간 어둡게 ·
   못 가는 난이도 = 흑백 + 자물쇠.
4. 그림이 없으면 지금의 색 + 아이콘 버튼으로 그대로 폴백한다.
