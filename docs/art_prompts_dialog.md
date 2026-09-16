# Bug Champ — 팝업 창 틀 이미지 프롬프트 (Gemini)

> **쓰는 법**
> 1. 번호마다 프롬프트 칸을 **통째로 복사 → Gemini 에 붙여넣기**.
> 2. 저장할 때 아래 **파일명** 칸을 복사해 붙여넣고 **다운로드 폴더**에 저장하세요(확장자는 그대로).
> 3. 다 만드시면 "팝업 틀 만들었어"라고 알려 주세요. 제가 배경 제거·9분할 자르기·연결까지 합니다.
> 4. 화풍을 맞추려면 기존 아이콘 한 장을 **함께 첨부**하세요:
>    `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\upgrades\attack.webp`

---

## ⚠️ 이 그림들이 까다로운 이유 — "늘려도 안 지저분해야 한다"

팝업은 내용에 따라 **높이가 제각각**입니다(확률표는 길고 확인창은 짧습니다).
한 장을 그대로 늘리면 나무결이 고무처럼 늘어져 보입니다. 그래서 **9분할(9-slice)** 로 씁니다 —
네 모서리는 그대로 두고, 네 변과 가운데만 늘립니다.

그래서 그림이 반드시 이래야 합니다:

- **가운데는 거의 평평하게**(균일한 색·아주 약한 질감). 가운데에 무늬·못·글자·장식이 있으면
  늘어날 때 그것만 쭉 늘어집니다.
- **장식은 네 모서리에만**. 변(위·아래·좌·우)에는 **일정하게 반복되는 테두리**만 —
  변 가운데에 리본·자물쇠 같은 큰 장식이 있으면 늘릴 수 없습니다.
- **정사각 1:1**, 테두리 두께는 가장자리에서 **전체의 약 12%** 안쪽까지.
- **배경은 완전한 단색 마젠타**(`#FF00FF`) — 제가 투명으로 뺍니다. 흰색·회색은 쓰지 마세요
  (나무의 밝은 부분과 섞여 구멍이 납니다).
- **글자·숫자·로고 금지.**

---

## 1. 팝업 틀 (모든 팝업이 이걸 씁니다)

```
A square 1:1 UI panel frame for a cozy insect-collecting mobile game, drawn as a nine-slice stretchable frame. A thick carved dark-walnut wood border runs around all four edges with an evenly repeating rounded-plank pattern, so the border looks identical everywhere along each side and can be stretched without looking wrong. Small decorations ONLY in the four corners: tiny brass corner brackets with a single rivet, and a little moss sprig with two leaves tucked in each corner. The four straight sides carry no ornament other than the repeating wood grain. The entire inner area is a FLAT, almost featureless warm parchment panel in muted deep olive-green, with only a whisper of paper fiber texture and a soft inner shadow right against the wooden border - absolutely nothing in the middle. Style: glossy stylized mobile game UI, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, thick warm brown outline, high detail on the border only. Border thickness about 12% of the image width. Front view, flat-on, no perspective tilt, no drop shadow outside the frame. The background outside the frame is pure solid magenta #FF00FF. no text, no letters, no numbers, no watermark, no logo.
```

파일명

```
dialog_frame
```

---

## 2. 기본 버튼 (확인·실행 같은 강조 버튼)

```
A wide horizontal pill-shaped button for a cozy insect-collecting mobile game, drawn as a nine-slice stretchable button so its width can change. A honey-amber polished wooden button with a warm brass rim and a soft glossy highlight along the top edge. The left and right ends are rounded caps; the middle section is completely FLAT and uniform so it can be stretched - no ornament, no rivets, no grain lines running across the middle. A very subtle darker band along the bottom edge suggests thickness. Style: glossy stylized mobile game UI, cozy naturalist storybook palette (honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, thick warm brown outline. Aspect ratio 3:1, front view, flat-on, no perspective tilt, no drop shadow. The background outside the button is pure solid magenta #FF00FF. no text, no letters, no numbers, no watermark, no logo.
```

파일명

```
dialog_btn_primary
```

---

## 3. 보조 버튼 (취소·닫기)

```
A wide horizontal pill-shaped button for a cozy insect-collecting mobile game, drawn as a nine-slice stretchable button so its width can change. A muted weathered grey-brown wooden button with a thin dull iron rim, clearly quieter and less shiny than a golden button - this is the secondary choice. The left and right ends are rounded caps; the middle section is completely FLAT and uniform so it can be stretched - no ornament, no rivets, no grain lines running across the middle. Style: glossy stylized mobile game UI, cozy naturalist storybook palette (mossy grey-brown, faded bark, soft cream), semi-realistic painterly shading, soft rim light, thick warm brown outline. Aspect ratio 3:1, front view, flat-on, no perspective tilt, no drop shadow. The background outside the button is pure solid magenta #FF00FF. no text, no letters, no numbers, no watermark, no logo.
```

파일명

```
dialog_btn_secondary
```

---

## 적용 후 모습 (제가 하는 일)

| 그림 | 어디에 |
|---|---|
| `dialog_frame` | `showGameDialog` 배경 — **게임의 모든 팝업**이 한 번에 바뀝니다 |
| `dialog_btn_primary` | 팝업의 `FilledButton`(확인·뽑기·즉시완료 등) |
| `dialog_btn_secondary` | 팝업의 `TextButton`(취소·닫기) |

- 9분할 경계는 그림을 받아 보고 제가 잡습니다(가장자리에서 몇 %인지 재서 `centerSlice` 로 넣습니다).
- **아트가 없어도 게임은 지금 모습으로 동작**합니다(폴백) — 넣는 만큼 바뀝니다.
