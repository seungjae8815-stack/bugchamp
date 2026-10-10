# Bug Champ — 프로필 그림 프롬프트 (Gemini · 시트 3장 = 프로필 20개 + 기본 1개)

> **쓰는 법**
> 1. 화풍을 맞추려면 기존 그림을 **함께 첨부**하세요:
>    `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\upgrades\attack.webp`
> 2. 시트마다 프롬프트 칸을 **통째로 복사 → Gemini 에 붙여넣기**. 시트마다 **새 대화창**에서 뽑으세요
>    (앞 대화의 그림이 섞여 나온 적이 있다).
> 3. 저장할 때 아래 **파일명** 칸을 복사해 붙여넣으세요(다운로드 폴더에 두시면 됩니다).
> 4. 다 받으시면 알려 주세요. 제가 칸마다 **잘라서 동그랗게 다듬고**(배경·로고 제거·크기 맞춤) 앱에 넣습니다.
> 5. 한 시트에서 몇 칸만 마음에 안 들면 그 시트만 다시 뽑으면 됩니다(잘라 쓰는 거라 섞어 써도 됩니다).

## 그림이 쓰이는 곳
- 내 프로필 창에서 고르기 → **채팅 · 랭킹 · 결투 순위표 · 결투장 · 왕충 선발대회** 이름 옆에 동그랗게(24~48px) 보인다.
- 고르지 않은 사람은 **기본 프로필**(21번) — 일부러 수수하게 그려서 "나만의 것으로 바꾸고 싶게" 한다.
- 작은 크기에서 서로 구분되도록 **곤충마다 바탕 원 색을 다르게** 했다.
- **테두리는 그림에 그리지 않고 앱에서 그린다**(작게 줄이면 그려 넣은 테가 뭉개지고 칸마다 굵기가 달라진다). 그림은 "색 원 + 곤충"만.
- 앱이 동그랗게 잘라 쓰므로 **더듬이·뿔·큰턱·날개가 원 밖으로 나오면 안 된다** — 프롬프트에 "원 안에 여백을 두고, 긴 더듬이는 안으로 말기"를 넣었다. 받은 뒤 삐져나온 칸이 있으면 그 시트만 다시 뽑는다.

## 칸 배치표 (잘라 넣을 때 쓰는 이름)

| 시트 | 칸 | 번호 · 그림 | 저장 이름(제가 붙임) |
|---|---|---|---|
| A | 1줄 왼쪽 · 가운데 · 오른쪽 | 1 사슴벌레 탐험가 · 2 장수풍뎅이 챔피언 · 3 사마귀 검객 | avatar_01 · 02 · 03 |
| A | 2줄 | 4 무당벌레 꽃왕관 · 5 꿀벌 꿀국자 · 6 반딧불이 등불 | avatar_04 · 05 · 06 |
| A | 3줄 | 7 장수말벌 비행 고글 · 8 호랑나비 목도리 · 9 개미 광부 | avatar_07 · 08 · 09 |
| B | 1줄 | 10 잠자리 조종사 · 11 매미 가수 · 12 물장군 물방울 | avatar_10 · 11 · 12 |
| B | 2줄 | 13 비단벌레 보석 · 14 하늘소 긴 더듬이 · 15 방아깨비 밀짚모자 | avatar_13 · 14 · 15 |
| B | 3줄 | 16 소똥구리 금빛 태양 · 17 긴꼬리산누에나방 달빛 · 18 바구미 학자 안경 | avatar_16 · 17 · 18 |
| C | 한 줄 왼쪽 · 가운데 · 오른쪽 | 19 귀뚜라미 바이올린 · 20 애벌레 새싹 모자 · 21 **기본 프로필** | avatar_19 · avatar_20 · avatar_default |

---

### 1. 시트 A (프로필 1~9)

```
Use the attached image only as the art style reference. Do NOT copy its subject. A sheet of nine separate round profile avatar icons for a cozy insect-collecting mobile game, arranged in a neat 3 by 3 grid with wide, even gaps of plain background between them; no circle touches another or the image edges, and all nine circles are exactly the same size. Every avatar is a perfect solid colored circle (no rim, no ring, no outline around the circle — the frame will be added later) with a charming stylized insect character inside it, shown as a head-and-shoulders portrait facing the viewer, with big glossy friendly eyes and a gentle smile, centered and filling about 80% of the circle, readable at 40 pixels. IMPORTANT: every part of each character — antennae, horns, mandibles, wings, legs and accessories — stays completely inside its own circle with a clear margin from the circle's edge; nothing pokes out of the circle; long antennae curl inward to fit inside the circle. Row 1 left: a stag beetle with large curved mandibles wearing a tiny khaki explorer pith helmet, on a moss-green circle. Row 1 middle: a rhinoceros beetle with a big curved horn wearing a small gold champion medal on a red ribbon, on a honey-amber circle. Row 1 right: a praying mantis raising both scythe arms proudly, wearing a small red headband, on a crimson circle. Row 2 left: a round ladybug wearing a tiny white daisy flower crown, on a soft pink circle. Row 2 middle: a fuzzy honeybee holding a little wooden honey dipper dripping honey, on a sunny yellow circle. Row 2 right: a firefly whose tail glows warmly like a lantern, on a deep night-blue circle with tiny stars. Row 3 left: a giant hornet wearing brown leather aviator goggles pushed up on its head, on a bright orange circle. Row 3 middle: a swallowtail butterfly with patterned wings wearing a small knitted scarf, on a sky-blue circle. Row 3 right: an ant wearing a yellow miner's helmet with a glowing lamp, on an earthy brown circle. Style: glossy stylized mobile game avatar icons, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream) with each circle in its own clear color, semi-realistic painterly shading, soft rim light, bold readable silhouettes, thick warm brown outlines on the characters, high detail, all nine drawn with the same lighting, scale and framing. Plain flat pale cream background around the circles. Square 1:1 image. no text, no letters, no numbers, no labels, no border around the whole sheet, no watermark, no logo. Composition: keep all nine circles in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```
파일명
```
avatars_sheet_a
```

### 2. 시트 B (프로필 10~18)

```
Use the attached image only as the art style reference. Do NOT copy its subject. A sheet of nine separate round profile avatar icons for a cozy insect-collecting mobile game, arranged in a neat 3 by 3 grid with wide, even gaps of plain background between them; no circle touches another or the image edges, and all nine circles are exactly the same size. Every avatar is a perfect solid colored circle (no rim, no ring, no outline around the circle — the frame will be added later) with a charming stylized insect character inside it, shown as a head-and-shoulders portrait facing the viewer, with big glossy friendly eyes and a gentle smile, centered and filling about 80% of the circle, readable at 40 pixels. IMPORTANT: every part of each character — antennae, horns, mandibles, wings, legs and accessories — stays completely inside its own circle with a clear margin from the circle's edge; nothing pokes out of the circle; long antennae curl inward to fit inside the circle. Row 1 left: a dragonfly with shimmering wings wearing round pilot goggles, on a teal circle. Row 1 middle: a cicada wearing tiny headphones with a small floating music note, on a lime-green circle. Row 1 right: a giant water bug with strong front legs surrounded by a few clear water bubbles, on an aqua-cyan circle. Row 2 left: an iridescent jewel beetle shining emerald-to-violet with small sparkles, on a deep purple circle. Row 2 middle: a longhorn beetle with very long striped antennae curling gracefully, on a slate blue-grey circle. Row 2 right: a long-headed green grasshopper wearing a small straw hat, on a wheat-gold circle. Row 3 left: a scarab beetle holding up a small shining golden sun disk, on a warm sandy-beige circle. Row 3 middle: a pale green luna moth with feathery antennae and a small crescent moon behind it, on a soft moonlit mint circle. Row 3 right: a weevil with a long snout wearing tiny round scholar glasses, on a lavender circle. Style: glossy stylized mobile game avatar icons, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream) with each circle in its own clear color, semi-realistic painterly shading, soft rim light, bold readable silhouettes, thick warm brown outlines on the characters, high detail, all nine drawn with the same lighting, scale and framing. Plain flat pale cream background around the circles. Square 1:1 image. no text, no letters, no numbers, no labels, no border around the whole sheet, no watermark, no logo. Composition: keep all nine circles in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```
파일명
```
avatars_sheet_b
```

### 3. 시트 C (프로필 19~20 + 기본 프로필)

```
Use the attached image only as the art style reference. Do NOT copy its subject. A sheet of three separate round profile avatar icons for a cozy insect-collecting mobile game, arranged in one horizontal row with wide, even gaps of plain background between them; no circle touches another or the image edges, and all three circles are exactly the same size. Every avatar is a perfect solid colored circle (no rim, no ring, no outline around the circle — the frame will be added later) with its content centered inside, readable at 40 pixels. IMPORTANT: every part of each character — antennae, legs, accessories — stays completely inside its own circle with a clear margin from the circle's edge; nothing pokes out of the circle. Left: a charming stylized cricket character shown as a head-and-shoulders portrait facing the viewer, big glossy friendly eyes and a gentle smile, holding a tiny wooden violin, on a warm red-brown circle. Middle: a chubby cheerful green caterpillar character facing the viewer, big glossy friendly eyes, wearing a tiny sprouting-leaf hat, on a fresh leaf-green circle. Right: the plain default avatar — a muted sage-grey circle with a simple flat cream-colored beetle silhouette in the center, no face, no eyes, no accessories, minimal and calm, clearly plainer than the other two. Style: glossy stylized mobile game avatar icons, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading on the left and middle characters, soft rim light, bold readable silhouettes, thick warm brown outlines, high detail, all three circles drawn with the same scale and framing. Plain flat pale cream background around the circles. Landscape 16:9 image. no text, no letters, no numbers, no labels, no border around the whole sheet, no watermark, no logo. Composition: keep all three circles in the upper 85% of the image; the bottom 15% must be plain empty background only (it will be cropped off).
```
파일명
```
avatars_sheet_c
```
