# 아트 프롬프트 — 장비 · 캐릭터 화면 (붙여넣기용)

> **각 코드블록이 그대로 완성된 프롬프트다.** 공통 STYLE 이 이미 붙어 있으니
> 복사해서 넣기만 하면 된다. 파일은 코드블록 위에 적힌 경로 그대로 저장한다.
>
> ⚠️ **파일명이 틀리면 에러 없이 조용히 아이콘으로 폴백한다**(헌법 §6). 오타 주의.

| 형식 | 값 |
|---|---|
| 포맷 | `.webp` · **투명 배경** |
| 아이콘 크기 | 256×256 (정사각) |
| 앵글 | 부위별로 **동일 앵글 · 중앙 정렬 · 동일 여백** |

### ⚠️ AI 는 "투명 배경"을 요구해도 체크무늬를 **그려서** 준다

실측: 받은 그림의 **완전투명 픽셀이 0%**, 모서리 알파가 255 였다. 즉 투명이
아니라 회색 체크판이 **그림으로 칠해져** 있다. 그대로 넣으면 게임에서 회색
사각형이 그대로 보인다.

배치 스크립트가 **자동으로 누끼를 딴다** — 가장자리에서 이어진 밝은 무채색
영역만 지우므로, 그물의 크림색 같은 **안쪽 밝은 부분은 안 뚫린다**.
지운 비율을 출력하고, 5% 미만이면 경고한다.
이미 진짜 투명인 그림은 건드리지 않는다(`--no-cutout` 로 끌 수도 있다).

### 파일명을 손으로 바꿀 필요 없다

두 가지 중 편한 쪽을 쓰면 된다.

**A. 저장할 때 바로 그 이름으로** — 각 프롬프트 위에 경로가 적혀 있다. 그대로
`tool_grass.webp` 로 저장하면 끝이다. 확장자는 **`.png` 도 그대로 읽는다**
(변환 안 해도 된다).

**B. 번호로 저장하고 스크립트에 맡기기** — 80개를 하나씩 이름 붙이다 보면
반드시 하나는 틀린다(그리고 **에러 없이 조용히** 아이콘으로 돌아간다).

```powershell
cd packagespp
python tool\place_item_art.py --list --slot tool   # 뽑을 순서 확인
# 그 순서대로 01.png … 10.png 로 저장한 뒤
python tool\place_item_art.py --from C:rt --slot tool --dry   # 확인만
python tool\place_item_art.py --from C:rt --slot tool         # 배치
```

투명 배경을 유지한 채 **256×256 정사각 가운데 정렬**로 맞춰 넣는다 —
칸마다 크기가 들쭉날쭉하면 격자로 늘어놨을 때 티가 난다.

### ⚠️ 등급색은 그림에 넣지 않는다

각 항목 옆의 `등급색 FFxxxxxx` 는 **참고값이지 프롬프트에 넣을 것이 아니다.**
그 색은 코드가 **칸 테두리**로 이미 칠하고 있다(`items.json → tiers[].color`).
그림까지 그 색으로 물들이면 재질(구리·은·호박)이 뭉개지고, 테두리와 겹쳐
등급 구분이 오히려 흐려진다.

그림은 **재질 고유의 색**으로 그린다 — 구리는 구릿빛, 호박은 호박빛.

**작업 순서**: `채집도구` 10개를 먼저 뽑아 등급 사다리가 눈에 보이는지 확인한 뒤
나머지 7부위로 넘어간다. 80개를 한 번에 뽑으면 화풍이 흔들리고, 흔들린 걸 알았을 땐
이미 다 뽑은 뒤다. **첫 1장을 스타일 레퍼런스로 고정**할 것.

---

## 1. 장비 80개

### 채집도구 (`tool`)

**풀잎 잠자리채** — `assets/images/items/tool_grass.webp` · 등급색 `FF9E9E9E`
```
game item icon of a bug-catching net with a woven grass hoop, woven from dried grass blades, humble and rustic, frayed edges, plain twine binding, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**나무 잠자리채** — `assets/images/items/tool_wood.webp` · 등급색 `FF8D6E63`
```
game item icon of a bug-catching net with a carved wooden handle, carved from pale wood, visible grain, simple hand-tooled finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**가죽 포충망** — `assets/images/items/tool_leather.webp` · 등급색 `FFA1887F`
```
game item icon of a butterfly net with a leather-wrapped grip, tanned brown leather, hand-stitched seams, worn soft edges, brass rivets, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**구리 핀셋** — `assets/images/items/tool_copper.webp` · 등급색 `FFBF6A3A`
```
game item icon of a pair of long copper insect tweezers, hammered copper, warm reddish metal with faint green patina spots, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**무쇠 집게** — `assets/images/items/tool_iron.webp` · 등급색 `FF90A4AE`
```
game item icon of a pair of heavy iron collecting tongs, dark forged iron, hammer marks, sturdy and heavy, matte finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**은빛 포충망** — `assets/images/items/tool_silver.webp` · 등급색 `FF64B5F6`
```
game item icon of a wide butterfly net with a silver rim, polished silversmith work, cool bright reflections, fine engraved filigree, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**황금 유인봉** — `assets/images/items/tool_gold.webp` · 등급색 `FFFFD54F`
```
game item icon of a golden lure rod dripping with sweet sap, ornate gold, warm rich luster, delicate scrollwork, small gem accents, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**키틴 집게발** — `assets/images/items/tool_chitin.webp` · 등급색 `FF4DB6AC`
```
game item icon of a pair of chitin pincers shaped like beetle mandibles, made from teal insect chitin exoskeleton plates, tougher than metal, glossy segmented shell, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**갑충 창** — `assets/images/items/tool_carapace.webp` · 등급색 `FF9575CD`
```
game item icon of a short spear made of beetle carapace, master-crafted purple beetle carapace, iridescent shifting sheen, layered armored plates, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**호박 지휘봉** — `assets/images/items/tool_amber.webp` · 등급색 `FFFF9800`
```
game item icon of a ceremonial amber baton of the legendary bug catcher, translucent glowing amber resin with a fossilized insect sealed inside, warm orange inner light, legendary artifact, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

---

### 모자 (`hat`)

**풀잎 두건** — `assets/images/items/hat_grass.webp` · 등급색 `FF9E9E9E`
```
game item icon of a simple grass hood, woven from dried grass blades, humble and rustic, frayed edges, plain twine binding, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**밀짚모자** — `assets/images/items/hat_wood.webp` · 등급색 `FF8D6E63`
```
game item icon of a straw sun hat for a bug collector, carved from pale wood, visible grain, simple hand-tooled finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**가죽 모자** — `assets/images/items/hat_leather.webp` · 등급색 `FFA1887F`
```
game item icon of a leather explorer hat, tanned brown leather, hand-stitched seams, worn soft edges, brass rivets, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**구리 투구** — `assets/images/items/hat_copper.webp` · 등급색 `FFBF6A3A`
```
game item icon of a copper helmet, hammered copper, warm reddish metal with faint green patina spots, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**무쇠 투구** — `assets/images/items/hat_iron.webp` · 등급색 `FF90A4AE`
```
game item icon of an iron helmet, dark forged iron, hammer marks, sturdy and heavy, matte finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**은빛 삿갓** — `assets/images/items/hat_silver.webp` · 등급색 `FF64B5F6`
```
game item icon of a wide silver conical sedge hat, polished silversmith work, cool bright reflections, fine engraved filigree, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**황금 관** — `assets/images/items/hat_gold.webp` · 등급색 `FFFFD54F`
```
game item icon of a golden crown, ornate gold, warm rich luster, delicate scrollwork, small gem accents, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**키틴 두건** — `assets/images/items/hat_chitin.webp` · 등급색 `FF4DB6AC`
```
game item icon of a chitin hood with antenna-like ridges, made from teal insect chitin exoskeleton plates, tougher than metal, glossy segmented shell, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**갑충 투구** — `assets/images/items/hat_carapace.webp` · 등급색 `FF9575CD`
```
game item icon of a beetle carapace helmet with a horn crest, master-crafted purple beetle carapace, iridescent shifting sheen, layered armored plates, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**호박 왕관** — `assets/images/items/hat_amber.webp` · 등급색 `FFFF9800`
```
game item icon of an amber diadem crown, translucent glowing amber resin with a fossilized insect sealed inside, warm orange inner light, legendary artifact, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

---

### 상의 (`top`)

**풀잎 조끼** — `assets/images/items/top_grass.webp` · 등급색 `FF9E9E9E`
```
game item icon of a woven grass vest, woven from dried grass blades, humble and rustic, frayed edges, plain twine binding, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**나무껍질 조끼** — `assets/images/items/top_wood.webp` · 등급색 `FF8D6E63`
```
game item icon of a plain cotton vest, carved from pale wood, visible grain, simple hand-tooled finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**가죽 자켓** — `assets/images/items/top_leather.webp` · 등급색 `FFA1887F`
```
game item icon of a leather jacket, tanned brown leather, hand-stitched seams, worn soft edges, brass rivets, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**구리 흉갑** — `assets/images/items/top_copper.webp` · 등급색 `FFBF6A3A`
```
game item icon of a copper breastplate, hammered copper, warm reddish metal with faint green patina spots, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**무쇠 흉갑** — `assets/images/items/top_iron.webp` · 등급색 `FF90A4AE`
```
game item icon of an iron breastplate, dark forged iron, hammer marks, sturdy and heavy, matte finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**은빛 예복** — `assets/images/items/top_silver.webp` · 등급색 `FF64B5F6`
```
game item icon of a silver-trimmed robe, polished silversmith work, cool bright reflections, fine engraved filigree, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**황금 예복** — `assets/images/items/top_gold.webp` · 등급색 `FFFFD54F`
```
game item icon of a golden ceremonial robe, ornate gold, warm rich luster, delicate scrollwork, small gem accents, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**키틴 자켓** — `assets/images/items/top_chitin.webp` · 등급색 `FF4DB6AC`
```
game item icon of a chitin jacket with segmented plates, made from teal insect chitin exoskeleton plates, tougher than metal, glossy segmented shell, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**갑충 흉갑** — `assets/images/items/top_carapace.webp` · 등급색 `FF9575CD`
```
game item icon of a beetle carapace cuirass, master-crafted purple beetle carapace, iridescent shifting sheen, layered armored plates, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**호박 로브** — `assets/images/items/top_amber.webp` · 등급색 `FFFF9800`
```
game item icon of a flowing amber robe, translucent glowing amber resin with a fossilized insect sealed inside, warm orange inner light, legendary artifact, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

---

### 하의 (`bottom`)

> ⚠️ **10개 모두 바지(trousers) 실루엣이다.** 한 줄에 다른 형태가 섞이면
> "같은 부위인가?" 싶어진다 — 등급 차이는 **재질로만** 낸다.
> 모든 프롬프트에 "both legs visible, waist at top and two leg openings at bottom"
> 이 들어가 있어 형태가 흔들리지 않는다.

**풀잎 바지** — `assets/images/items/bottom_grass.webp` · 등급색 `FF9E9E9E`
```
game item icon of trousers woven from dried grass blades, frayed hems, twine waistband, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**나무껍질 반바지** — `assets/images/items/bottom_wood.webp` · 등급색 `FF8D6E63`
```
game item icon of short work trousers of pale wood-fiber cloth with visible wood grain, wooden button, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**가죽 바지** — `assets/images/items/bottom_leather.webp` · 등급색 `FFA1887F`
```
game item icon of brown tanned leather trousers, hand-stitched seams, small brass rivets, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**구리 갑옷바지** — `assets/images/items/bottom_copper.webp` · 등급색 `FFBF6A3A`
```
game item icon of armored trousers plated with hammered copper, warm reddish metal, faint green patina, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**무쇠 갑옷바지** — `assets/images/items/bottom_iron.webp` · 등급색 `FF90A4AE`
```
game item icon of armored trousers plated with dark forged iron, hammer marks, sturdy and heavy, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**은빛 바지** — `assets/images/items/bottom_silver.webp` · 등급색 `FF64B5F6`
```
game item icon of silver-trimmed trousers, cool bright reflections, fine engraved filigree along the seams, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**황금 예복바지** — `assets/images/items/bottom_gold.webp` · 등급색 `FFFFD54F`
```
game item icon of golden ceremonial trousers, rich warm luster, delicate scrollwork, small gem accents, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**키틴 바지** — `assets/images/items/bottom_chitin.webp` · 등급색 `FF4DB6AC`
```
game item icon of trousers plated with teal insect chitin, glossy segmented shell, tougher than metal, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**갑충 갑옷바지** — `assets/images/items/bottom_carapace.webp` · 등급색 `FF9575CD`
```
game item icon of armored trousers of purple beetle carapace, iridescent shifting sheen, layered plates, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**호박 바지** — `assets/images/items/bottom_amber.webp` · 등급색 `FFFF9800`
```
game item icon of trousers of translucent glowing amber resin with a fossilized insect sealed inside, warm orange inner light, legendary artifact, empty trousers laid flat facing the viewer, both legs visible, waist at top and two leg openings at bottom, no character wearing them, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```
---

### 신발 (`shoes`)

**짚신** — `assets/images/items/shoes_grass.webp` · 등급색 `FF9E9E9E`
```
game item icon of straw sandals, woven from dried grass blades, humble and rustic, frayed edges, plain twine binding, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**나무 나막신** — `assets/images/items/shoes_wood.webp` · 등급색 `FF8D6E63`
```
game item icon of wooden clogs, carved from pale wood, visible grain, simple hand-tooled finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**가죽 부츠** — `assets/images/items/shoes_leather.webp` · 등급색 `FFA1887F`
```
game item icon of leather boots, tanned brown leather, hand-stitched seams, worn soft edges, brass rivets, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**구리 군화** — `assets/images/items/shoes_copper.webp` · 등급색 `FFBF6A3A`
```
game item icon of copper military boots, hammered copper, warm reddish metal with faint green patina spots, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**무쇠 군화** — `assets/images/items/shoes_iron.webp` · 등급색 `FF90A4AE`
```
game item icon of iron military boots, dark forged iron, hammer marks, sturdy and heavy, matte finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**은빛 샌들** — `assets/images/items/shoes_silver.webp` · 등급색 `FF64B5F6`
```
game item icon of silver sandals, polished silversmith work, cool bright reflections, fine engraved filigree, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**황금 장화** — `assets/images/items/shoes_gold.webp` · 등급색 `FFFFD54F`
```
game item icon of golden tall boots, ornate gold, warm rich luster, delicate scrollwork, small gem accents, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**키틴 부츠** — `assets/images/items/shoes_chitin.webp` · 등급색 `FF4DB6AC`
```
game item icon of chitin boots, made from teal insect chitin exoskeleton plates, tougher than metal, glossy segmented shell, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**갑충 발톱신** — `assets/images/items/shoes_carapace.webp` · 등급색 `FF9575CD`
```
game item icon of beetle-claw boots with sharp toe claws, master-crafted purple beetle carapace, iridescent shifting sheen, layered armored plates, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**호박 신발** — `assets/images/items/shoes_amber.webp` · 등급색 `FFFF9800`
```
game item icon of amber shoes, translucent glowing amber resin with a fossilized insect sealed inside, warm orange inner light, legendary artifact, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

---

### 목걸이 (`necklace`)

**풀잎 목걸이** — `assets/images/items/necklace_grass.webp` · 등급색 `FF9E9E9E`
```
game item icon of a grass cord necklace, woven from dried grass blades, humble and rustic, frayed edges, plain twine binding, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**씨앗 목걸이** — `assets/images/items/necklace_wood.webp` · 등급색 `FF8D6E63`
```
game item icon of a seed bead necklace, carved from pale wood, visible grain, simple hand-tooled finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**가죽끈 목걸이** — `assets/images/items/necklace_leather.webp` · 등급색 `FFA1887F`
```
game item icon of a leather cord necklace, tanned brown leather, hand-stitched seams, worn soft edges, brass rivets, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**구리 사슬** — `assets/images/items/necklace_copper.webp` · 등급색 `FFBF6A3A`
```
game item icon of a copper chain necklace, hammered copper, warm reddish metal with faint green patina spots, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**무쇠 사슬** — `assets/images/items/necklace_iron.webp` · 등급색 `FF90A4AE`
```
game item icon of an iron chain necklace, dark forged iron, hammer marks, sturdy and heavy, matte finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**은빛 목걸이** — `assets/images/items/necklace_silver.webp` · 등급색 `FF64B5F6`
```
game item icon of a silver necklace, polished silversmith work, cool bright reflections, fine engraved filigree, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**황금풍뎅이 목걸이** — `assets/images/items/necklace_gold.webp` · 등급색 `FFFFD54F`
```
game item icon of a golden scarab beetle necklace, ornate gold, warm rich luster, delicate scrollwork, small gem accents, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**키틴 목걸이** — `assets/images/items/necklace_chitin.webp` · 등급색 `FF4DB6AC`
```
game item icon of a chitin necklace, made from teal insect chitin exoskeleton plates, tougher than metal, glossy segmented shell, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**갑충 목가리개** — `assets/images/items/necklace_carapace.webp` · 등급색 `FF9575CD`
```
game item icon of a beetle carapace gorget collar, master-crafted purple beetle carapace, iridescent shifting sheen, layered armored plates, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**호박 펜던트** — `assets/images/items/necklace_amber.webp` · 등급색 `FFFF9800`
```
game item icon of an amber pendant, translucent glowing amber resin with a fossilized insect sealed inside, warm orange inner light, legendary artifact, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

---

### 반지 (`ring`)

**풀 매듭 반지** — `assets/images/items/ring_grass.webp` · 등급색 `FF9E9E9E`
```
game item icon of a knotted grass ring, woven from dried grass blades, humble and rustic, frayed edges, plain twine binding, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**나무 반지** — `assets/images/items/ring_wood.webp` · 등급색 `FF8D6E63`
```
game item icon of a wooden ring, carved from pale wood, visible grain, simple hand-tooled finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**가죽 고리** — `assets/images/items/ring_leather.webp` · 등급색 `FFA1887F`
```
game item icon of a leather band ring, tanned brown leather, hand-stitched seams, worn soft edges, brass rivets, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**구리 반지** — `assets/images/items/ring_copper.webp` · 등급색 `FFBF6A3A`
```
game item icon of a copper ring, hammered copper, warm reddish metal with faint green patina spots, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**무쇠 반지** — `assets/images/items/ring_iron.webp` · 등급색 `FF90A4AE`
```
game item icon of an iron ring, dark forged iron, hammer marks, sturdy and heavy, matte finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**은빛 반지** — `assets/images/items/ring_silver.webp` · 등급색 `FF64B5F6`
```
game item icon of a silver ring, polished silversmith work, cool bright reflections, fine engraved filigree, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**황금 반지** — `assets/images/items/ring_gold.webp` · 등급색 `FFFFD54F`
```
game item icon of a golden ring, ornate gold, warm rich luster, delicate scrollwork, small gem accents, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**키틴 반지** — `assets/images/items/ring_chitin.webp` · 등급색 `FF4DB6AC`
```
game item icon of a chitin ring, made from teal insect chitin exoskeleton plates, tougher than metal, glossy segmented shell, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**갑충 인장** — `assets/images/items/ring_carapace.webp` · 등급색 `FF9575CD`
```
game item icon of a beetle carapace signet ring, master-crafted purple beetle carapace, iridescent shifting sheen, layered armored plates, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**호박 반지** — `assets/images/items/ring_amber.webp` · 등급색 `FFFF9800`
```
game item icon of an amber ring, translucent glowing amber resin with a fossilized insect sealed inside, warm orange inner light, legendary artifact, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

---

### 채집함 (`box`)

**풀잎 바구니** — `assets/images/items/box_grass.webp` · 등급색 `FF9E9E9E`
```
game item icon of a woven grass collecting basket, woven from dried grass blades, humble and rustic, frayed edges, plain twine binding, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**종이 표본함** — `assets/images/items/box_wood.webp` · 등급색 `FF8D6E63`
```
game item icon of a paper specimen box, carved from pale wood, visible grain, simple hand-tooled finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**가죽 채집가방** — `assets/images/items/box_leather.webp` · 등급색 `FFA1887F`
```
game item icon of a leather collecting satchel, tanned brown leather, hand-stitched seams, worn soft edges, brass rivets, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**구리 상자** — `assets/images/items/box_copper.webp` · 등급색 `FFBF6A3A`
```
game item icon of a copper specimen chest, hammered copper, warm reddish metal with faint green patina spots, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**무쇠 상자** — `assets/images/items/box_iron.webp` · 등급색 `FF90A4AE`
```
game item icon of an iron specimen chest, dark forged iron, hammer marks, sturdy and heavy, matte finish, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**은빛 진열장** — `assets/images/items/box_silver.webp` · 등급색 `FF64B5F6`
```
game item icon of a silver display cabinet, polished silversmith work, cool bright reflections, fine engraved filigree, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**황금 진열장** — `assets/images/items/box_gold.webp` · 등급색 `FFFFD54F`
```
game item icon of a golden display cabinet, ornate gold, warm rich luster, delicate scrollwork, small gem accents, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**키틴 사육통** — `assets/images/items/box_chitin.webp` · 등급색 `FF4DB6AC`
```
game item icon of a chitin breeding terrarium, made from teal insect chitin exoskeleton plates, tougher than metal, glossy segmented shell, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**갑충 표본함** — `assets/images/items/box_carapace.webp` · 등급색 `FF9575CD`
```
game item icon of a beetle carapace specimen case, master-crafted purple beetle carapace, iridescent shifting sheen, layered armored plates, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**호박 보관함** — `assets/images/items/box_amber.webp` · 등급색 `FFFF9800`
```
game item icon of an amber storage case, translucent glowing amber resin with a fossilized insect sealed inside, warm orange inner light, legendary artifact, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

---

## 2. 캐릭터 화면

**메인 캐릭터 초상** — `assets/images/character/portrait.webp` · 512×512
```
character portrait of a friendly young bug collector, upper body, straw hat, satchel strap, holding a butterfly net over the shoulder, warm smile, facing viewer, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

## 2-2. 캐릭터 걷기 (씬 애니메이션)

> ⚠️ **두 장을 같은 프롬프트·같은 시드로** 뽑는다. 옷·모자·비율이 조금만
> 달라져도 번갈아 보여줄 때 **덜덜 떨린다**. `walk_1` 을 레퍼런스로 넣고
> `walk_2` 를 만드는 것이 가장 안전하다.
>
> 지금 있는 스프라이트는 `idle` · `attack` · `death` 뿐이라 캐릭터가 서 있기만 한다.

**walk_1** — `assets/images/character/walk_1.webp` · 512×512
```
side view full body of a friendly young bug collector walking, left leg forward mid-stride, right arm swung forward, body at its lowest point, straw hat, shoulder satchel, butterfly net carried over the right shoulder, short brown hair, facing right, full body from head to feet inside frame, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**walk_2** — `assets/images/character/walk_2.webp` · 512×512
```
side view full body of a friendly young bug collector walking, right leg forward mid-stride, left arm swung forward, body bobbed slightly up, straw hat, shoulder satchel, butterfly net carried over the right shoulder, short brown hair, facing right, full body from head to feet inside frame, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```
### 공방 — 모루와 망치를 **따로** 뽑는다

> ⚠️ 지금 `anvil.webp` 에는 망치가 **얹혀 있다**. 그 위에서 망치를 또 휘두르면
> 망치가 두 개로 보인다. 두 장으로 나눠야 내리치는 연출이 된다.
>
> 두 장을 뽑으면 코드가 자동으로 새 파일을 쓴다(없으면 지금 그림으로 폴백).
> **크기 감각을 맞춰서** 뽑을 것 — 망치 머리가 모루 상판 폭의 절반쯤이면 좋다.

**모루(망치 없음)** — `assets/images/ui/anvil_base.webp` · 256×256
```
game ui icon of a blacksmith anvil on a worn wooden stump, nothing resting on the anvil, empty clean anvil top surface, no hammer, no tools, front three-quarter view, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**망치(단독)** — `assets/images/ui/hammer.webp` · 256×256
```
game ui icon of a single blacksmith hammer with a wooden handle and a chunky metal head, diagonal pose with the head at the upper left and the handle running to the lower right, handle end at the bottom right corner of the frame, whole hammer inside frame, centered, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

> 망치는 **자루 끝을 축으로** 회전한다. 그래서 자루가 오른쪽 아래로 뻗고
> 머리가 왼쪽 위에 있는 자세여야 자연스럽게 내리친다.

> 씬은 홈 화면과 **같은 파일 규약**(`{상태}_{프레임}.webp`)을 쓴다.
> `walk_1`·`walk_2` 를 넣으면 코드 수정 없이 걷기 애니메이션이 붙는다.

---

## 3. UI 프레임 (선택 · 고급화용)

> 없어도 된다 — 지금도 등급 색 테두리로 구분된다. 1·2번이 끝난 뒤 판단할 것.

**장비 칸 프레임** — `assets/images/ui/slot_frame.webp` · 128×128
```
game ui frame for a square inventory slot, ornate carved wood with brass corner fittings, empty transparent center, symmetrical, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**풀잎 등급 광택** — `assets/images/ui/tier_glow_grass.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, dull grey colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**나무 등급 광택** — `assets/images/ui/tier_glow_wood.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, warm brown colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**가죽 등급 광택** — `assets/images/ui/tier_glow_leather.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, ochre tan colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**구리 등급 광택** — `assets/images/ui/tier_glow_copper.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, copper orange colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**무쇠 등급 광택** — `assets/images/ui/tier_glow_iron.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, steel grey colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**은 등급 광택** — `assets/images/ui/tier_glow_silver.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, sky blue colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**황금 등급 광택** — `assets/images/ui/tier_glow_gold.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, golden yellow colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**키틴 등급 광택** — `assets/images/ui/tier_glow_chitin.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, teal colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**갑충 등급 광택** — `assets/images/ui/tier_glow_carapace.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, violet purple colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

**호박 등급 광택** — `assets/images/ui/tier_glow_amber.webp` · 128×128
```
soft radial glow overlay for a game item rarity frame, bright amber orange colored aura, subtle sparkle particles, empty transparent center, isolated on transparent background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature
```

---

## 4. 넣은 뒤 확인

1. ⚠️ `pubspec.yaml` 은 **폴더마다 한 줄씩** 등록해야 한다(`assets/images/items/` 처럼).
   새 폴더를 만들었으면 등록부터 — 안 하면 파일이 앱에 **아예 안 실린다**.
   `items/` 는 등록해뒀다.
2. 캐릭터 탭에서 아이콘이 그림으로 바뀌는지 확인. **안 바뀌면 파일명 오타**다.
3. 8×10 을 한 화면에서 보고 **크기·여백이 균일한지** 확인.
