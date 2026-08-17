# Bug Champ — AI 아트 생성 프롬프트 키트

**아트 디렉션**: 코지 자연주의 카툰 (cozy naturalist cartoon) — 친근한 반실사 곤충 + 따뜻한 숲 팔레트.
**제작 방식**: AI 생성 (Midjourney / Stable Diffusion). 스타일 레퍼런스 1장 + 시드 고정으로 일관성 확보.

> 팔레트(고정): 햇살 `#F3CE86` · 잎 `#3E7D4F` · 심록 `#1E3B28` · 나무 `#855A31` · 수액/강조 `#E3A62F`

---

## 0. 일관성 규칙 (가장 중요)

1. **스타일 키 이미지 1장 먼저 확정** — 마음에 드는 곤충 1마리(예: 장수풍뎅이)를 여러 번 뽑아 "이 스타일이다" 싶은 1장을 고른다.
2. 그 이미지를 **모든 후속 생성의 레퍼런스**로 사용:
   - Midjourney: `--sref <이미지URL> --sw 100`
   - Stable Diffusion: IP-Adapter / reference-only, 또는 같은 LoRA·체크포인트 고정
3. **스타일 접미사(아래 STYLE)를 모든 프롬프트에 그대로** 붙인다.
4. 한 배치 안에서는 `--seed` 고정 → 재현·비교 용이.
5. 곤충은 **동일 앵글(3/4 탑다운) · 중앙 정렬 · 동일 여백**. 등급 차이는 곤충 자체가 아니라 **프레임/오라**로 표현.

### STYLE (공통 접미사 — 그대로 복붙)
```
cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light,
hand-painted storybook texture, rounded friendly forms, muted earthy forest palette
(moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette,
mobile game art, crisp high detail, no text, no watermark, no signature
```

### 기술 세팅
| 대상 | 비율 | 배경 | 후처리 |
|---|---|---|---|
| 곤충 20종 | `--ar 1:1` | 균일한 파스텔 단색 | rembg로 투명 컷아웃 |
| 필드 배경 4종 | `--ar 9:16` | 풀씬 | 상/하단 여백 고려(HUD/탭 가림) |
| 트랩·재료 아이콘 | `--ar 1:1` | 단색 | rembg 투명 |
| 등급 프레임 5종 | `--ar 1:1` | 투명/단색 | 중앙 비우기 |

- Midjourney: `--style raw --v 7` 권장. 예) `... {STYLE} --ar 1:1 --style raw --v 7 --sref <key> --sw 100 --seed 12345`
- 투명 배경: MJ는 단색 배경으로 뽑고 `rembg i in.png out.png` 로 제거(권장). SD는 투명 지원 확장 사용 가능.
- 최종은 곤충 1024², 배경 1536×... 이상 업스케일 → **WebP 변환** 후 앱에 투입.

---

## 1. 필드 배경 ×4 (`assets/images/fields/`)

공통: `{장면 설명}, wide vertical composition, empty foreground space for UI, atmospheric depth, layered parallax friendly, {STYLE} --ar 9:16 --style raw`

| 파일명 | 장면 프롬프트(핵심) |
|---|---|
| `oak_forest` | lush oak forest clearing, dappled sunlight through canopy, mossy tree stumps, ferns, warm green tones |
| `valley_stream` | mountain valley stream, clear shallow water over smooth stones, mossy rocks, cool fresh light |
| `grass_field` | sunny grassland meadow, tall swaying grass, scattered wildflowers, bright open sky, warm afternoon |
| `night_mountain` | moonlit mountain forest at night, drifting fireflies, cool blue shadows with warm lantern glow, mysterious |

---

## 2. 곤충 일러스트 ×20 (`assets/images/bugs/`)

공통 템플릿:
```
a friendly stylized {SUBJECT}, full body, 3/4 top-down angle, centered, consistent padding,
plain soft pastel background, {STYLE} --ar 1:1 --style raw --sref <key> --sw 100
```

| id (파일명) | 한글명 | 등급 | SUBJECT (핵심 묘사) |
|---|---|---|---|
| `stag_dorcus` | 애사슴벌레 | 일반 | small glossy black stag beetle, short modest mandibles |
| `stag_saw` | 톱사슴벌레 | 일반 | stag beetle with long curved saw-toothed mandibles, amber-brown |
| `rhino_lesser` | 외뿔장수풍뎅이 | 일반 | small rhinoceros beetle with a single short horn, dark brown |
| `mantis_jumping` | 좀사마귀 | 일반 | small slender brown praying mantis, alert pose |
| `longhorn_saw` | 톱하늘소 | 일반 | brown longhorn beetle, serrated antennae, matte shell |
| `grasshopper_longheaded` | 방아깨비 | 일반 | long-headed green grasshopper, pointed face, long hind legs |
| `stag_flat` | 넓적사슴벌레 | 고급 | broad flat wide-jawed stag beetle, glossy jet black, powerful |
| `rhino_japanese` | 장수풍뎅이 | 고급 | classic rhinoceros beetle, Y-shaped horn, sturdy brown shell |
| `mantis_widebelly` | 넓적배사마귀 | 고급 | wide-bellied bright green praying mantis, raptorial arms |
| `longhorn_whitespot` | 알락하늘소 | 고급 | black longhorn beetle with white speckles, very long antennae |
| `katydid` | 여치 | 고급 | plump green katydid bush-cricket, long antennae |
| `stag_miyama` | 사슴벌레(미야마) | 희귀 | miyama stag beetle, fuzzy golden head flanges, large arched mandibles |
| `mantis_giant` | 왕사마귀 | 희귀 | large imposing green praying mantis, majestic stance |
| `longhorn_oak` | 참나무하늘소 | 희귀 | large brown oak longhorn beetle, extra-long banded antennae |
| `chafer_flower` | 장수꽃무지 | 희귀 | iridescent flower chafer beetle, metallic green-bronze shell |
| `stag_giant` | 왕사슴벌레 | 영웅 | giant black stag beetle, thick powerful curved mandibles, regal |
| `water_bug_giant` | 물장군 | 영웅 | giant water bug, flat brown body, strong raptorial forelegs |
| `stag_twospot` | 두점박이사슴벌레 | 영웅 | reddish-brown stag beetle with two bright spots on shell |
| `longhorn_relict` | 장수하늘소 | 전설 | colossal majestic relict longhorn beetle, long elegant body, heroic aura |
| `hornet_giant` | 장수말벌 | 전설 | stylized asian giant hornet, orange-yellow head, bold but not scary, dynamic |

> 등급 오라(선택): 프롬프트에 `soft {color} glow rim` 추가 — 일반 gray · 고급 green · 희귀 blue · 영웅 purple · 전설 gold. 단, **등급색은 프레임(§4)으로 처리 권장**(곤충 색 왜곡 방지).

---

## 3. 트랩 오브젝트 ×4 (`assets/images/traps/`)

공통: `cute game item, small object, 3/4 view, centered, plain background, {STYLE} --ar 1:1 --style raw`

| 파일명 | 프롬프트(핵심) |
|---|---|
| `sap_trap` | tree sap bait trap, amber honey dripping down bark, small wooden dish |
| `fruit_trap` | fruit bait trap, sliced watermelon and banana on a little dish |
| `light_trap` | UV lantern light trap, softly glowing bulb on a stand |
| `pitfall_trap` | buried cup pitfall trap set in soil with leaf litter rim |

## 4. 재료 아이콘 ×5 (`assets/images/materials/`)

공통: `glossy game item icon, single object, centered, plain background, {STYLE} --ar 1:1 --style raw`

| 파일명 | 프롬프트(핵심) |
|---|---|
| `chitin` | shiny chitin shell fragment, amber-brown, faceted |
| `mineral` | rough mineral crystal cluster, teal-blue |
| `sap` | golden sap crystal droplet, glowing honey amber |
| `jelly` | cute insect jelly cup, translucent, colorful |
| `fossil` | chipped wedge of pale sandstone rock with an amber-glowing beetle imprint embedded in its polished face, cracked edges |

> `fossil`(화석 조각)은 제련 전용 재료다(§2.7 공방). **곤충 화석**이어야 한다 —
> 암모나이트 같은 일반 화석으로 뽑으면 이 게임의 재료로 안 읽힌다.
> 규격: 배경 제거 후 최대변 660px, RGBA WebP(quality 92). 기존 4종과 같은
> **굵은 갈색 외곽선 + 크림색 림라이트**가 있어야 14px 아이콘에서 구분된다.

## 4b. 버프 아이콘 ×5 (`assets/images/buffs/`)

광고/제작으로 발동하는 일시 버프. 파일명 = `BuffKind.key`. 40px에서 읽히는 강한 실루엣 + 테마색 오라.

공통: `glossy game buff skill icon, single centered emblem, bold readable silhouette, soft {color} glow rim, plain background, {STYLE} --ar 1:1 --style raw --sref <key> --sw 100`

| 파일명 | 오라색 | 프롬프트(핵심 Subject) |
|---|---|---|
| `goldRush` | honey amber `#E0A32E` | overflowing heap of shiny gold coins with one big glowing coin on top, warm sparkles |
| `xpBoost` | leaf green `#3E7D4F` | open glowing insect field-guide book with an upward arrow of light and rising sparks |
| `frenzy` | crimson `#B5432E` | crossed beetle horn / mandible blades wrapped in fierce warm-red flame aura, sharp and aggressive |
| `gatherer` | steel blue `#2E6DA4` | bulging treasure pouch spilling crafting materials — a chitin shard, teal mineral crystal, amber sap droplet |
| `luckyWind` | violet `#7E57C2` | glowing four-leaf clover in a gentle breeze with one small lucky butterfly and drifting leaf motes |

> `no text, no letters, no frame border` 는 STYLE에 이미 포함. 투명 배경은 단색으로 뽑고 `rembg` 로 컷아웃.

## 4c. UI 버튼 아이콘 ×4 (`assets/images/ui/`)

채집함·랭킹의 도구 버튼(2026-08-16). **20~26px로 그려진다** — 버프 아이콘(40px)보다
훨씬 작으므로 디테일보다 **실루엣 하나**로 승부해야 한다. 요소를 두 개 이상 넣으면
그 크기에서 뭉개진다.

아래 4개는 **그대로 복붙**하면 되는 완성 프롬프트다(공통 규칙 + STYLE 접미사 포함).
`<key>` 자리에만 §0에서 정한 스타일 키 이미지 URL을 넣는다. 키가 없으면
`--sref <key> --sw 100` 부분만 지우고 쓴다.

**① `dex.webp`** — 채집함 앱바(도감)
```
closed leather-bound field guide book with a brass beetle emblem on the cover, warm amber page edges, glossy game UI button icon, single centered object, bold simple silhouette readable at 24px, thick warm brown outline, cream rim light, honey amber accent, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**② `auto_synth.webp`** — 장착 펫 아래 도구 줄(자동 합성)
```
three small glowing amber orbs merging into one larger radiant orb, upward spark trail, glossy game UI button icon, single centered object, bold simple silhouette readable at 24px, thick warm brown outline, cream rim light, honey amber accent, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**③ `auto_release.webp`** — 자동 합성 옆(자동 분해)
```
open hand releasing a beetle upward into light, two crafting material shards falling back down, glossy game UI button icon, single centered object, bold simple silhouette readable at 24px, thick warm brown outline, cream rim light, honey amber accent, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature, no hammer, no anvil --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**④ `rank_stage.webp`** — 랭킹 '진행도' 축
```
pennant flag planted on a small rocky summit, honey amber cloth, upward motion, glossy game UI button icon, single centered object, bold simple silhouette readable at 24px, thick warm brown outline, cream rim light, honey amber accent, plain background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature, no map pin, no location marker --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

> **규격**: 배경 제거 후 정사각 256×256 이상, RGBA WebP(quality 92), 파일명 그대로.
> 넣기만 하면 코드 수정 없이 자동으로 그림으로 바뀐다(없으면 Material 아이콘 폴백 —
> `gameImage(path, fallback:)` 구조라 파일이 없어도 앱은 정상 동작한다).
>
> ⚠️ `auto_release`(자동 분해)는 **분해를 놓아주는 것으로 표현**한다. 부수는 그림
> (망치·조각남)으로 뽑으면 공방 제련(`hammer`·`anvil`)과 헷갈린다.
> `rank_stage`는 지도 핀 모양을 피한다 — 원래 📍였는데 "위치"로 읽혀 진행도로 안 보였다.

## 4d. 이벤트 강화 카드 ×8 (`assets/images/ui/cards/`)

「왕충 선발대회」에서 웨이브를 깰 때마다 고르는 카드(docs/event_ranking_prize.md).
**40px 정도로 그려진다** — 카드 프레임은 앱이 그리므로 **오브젝트만** 뽑는다.
파일명 = `event.json → cards.list[].id`. 없으면 이모지로 폴백하므로 급하지 않다.

> ⚠️ 프롬프트에 `no card frame, no border` 를 넣는다. 카드 테두리까지 그려 오면
> 앱이 그리는 테두리와 이중이 된다(UI 아이콘에서 이미 겪었다 — §4c).

**`heal_s.webp`** — 응급 처치
```
a single glowing green dewdrop with a soft cross-shaped light inside, gentle healing sparkles, glossy game reward card icon, single centered object on a plain background, bold simple silhouette readable at 40px, thick warm brown outline, cream rim light, no card frame, no border, no UI panel, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**`heal_l.webp`** — 완전 회복
```
a large radiant emerald droplet overflowing with green light, ring of healing motes around it, glossy game reward card icon, single centered object on a plain background, bold simple silhouette readable at 40px, thick warm brown outline, cream rim light, no card frame, no border, no UI panel, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**`atk_s.webp`** — 예리한 턱
```
a pair of sharp beetle mandibles angled like blades, honey amber highlights on the edges, glossy game reward card icon, single centered object on a plain background, bold simple silhouette readable at 40px, thick warm brown outline, cream rim light, no card frame, no border, no UI panel, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**`atk_l.webp`** — 맹공
```
crossed beetle horns wreathed in fierce warm-red flame aura, aggressive and heavy, glossy game reward card icon, single centered object on a plain background, bold simple silhouette readable at 40px, thick warm brown outline, cream rim light, no card frame, no border, no UI panel, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**`def_s.webp`** — 단단한 표피
```
a thick layered chitin shield plate, hexagonal armor texture, steel-blue sheen over brown, glossy game reward card icon, single centered object on a plain background, bold simple silhouette readable at 40px, thick warm brown outline, cream rim light, no card frame, no border, no UI panel, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**`hp_s.webp`** — 강인한 체격
```
a stout armored beetle thorax seen head-on, broad and heavy, warm red heart glow at its center, glossy game reward card icon, single centered object on a plain background, bold simple silhouette readable at 40px, thick warm brown outline, cream rim light, no card frame, no border, no UI panel, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**`revive.webp`** — 생명의 이슬
```
a single luminous dewdrop falling onto a curled sleeping larva, soft golden resurrection glow, glossy game reward card icon, single centered object on a plain background, bold simple silhouette readable at 40px, thick warm brown outline, cream rim light, no card frame, no border, no UI panel, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

**`skip.webp`** — 우회로
```
a swirling spiral of wind and drifting leaves forming a portal, cool teal glow, glossy game reward card icon, single centered object on a plain background, bold simple silhouette readable at 40px, thick warm brown outline, cream rim light, no card frame, no border, no UI panel, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1 --style raw --v 7 --sref <key> --sw 100
```

## 4e. 이벤트 전단지 머리그림 ×1 (`assets/images/ui/event/flyer_bg.webp`)

이벤트를 누르면 뜨는 **전단지 한 장**의 머리그림(`features/event/event_intro.dart`).
페이지를 넘기는 방식이었다가 전단지로 바꿨다 — 대회 안내는 상품·참가법·주의사항을
**한눈에 훑는** 정보라, 넘겨야 보이면 마지막 장의 주의사항을 아무도 안 읽는다.

**가로로 넓게(220×110 안팎) 들어가고 글자는 앱이 얹으므로, 그림에 텍스트를 넣지 않는다.**

```
three heroic beetles standing shoulder to shoulder on a mossy log facing an oncoming tide of insect silhouettes, a golden trophy glowing behind them, wide banner composition, empty space at the edges, tournament poster mood, no text, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 2:1 --style raw --v 7 --sref <key> --sw 100
```

> **규격**: 카드는 배경 제거 후 256×256↑, 전단지 머리그림은 1024×512↑, 둘 다 RGBA WebP(quality 92).
> 배경 제거는 §4c 의 교훈 그대로 — **문턱 60 + 알파 1px 침식**이 필요하다
> (크림 림라이트가 배경과 채널차 33 이라 32 에서는 한 끗 차이로 안 지워진다).

## 4f. 오행 아이콘 ×5 (`assets/images/ui/element/`)

지금은 이모지(🔥💧🌿⚙️⛰️)를 쓴다. **기기 폰트마다 모양·색이 제각각**이라
"상극!" 처럼 순간적으로 읽혀야 하는 자리에서 눈에 안 들어온다. 그림으로 바꾸면
전투 이름표·다음 적 속성 예고·상극 표시가 **전부 같은 언어**로 통일된다.

파일명 = enum 이름 그대로: `wood.png` `fire.png` `earth.png` `metal.png` `water.png`
(없으면 이모지로 자동 폴백하므로 한 장씩 넣어도 된다).

**작게(13~20px) 쓰이므로 디테일보다 실루엣과 색이다.** 곤충을 그리지 말 것 —
곤충 그림 옆에 붙는 아이콘이라 같이 있으면 뭉친다.

공통 꼬리: `flat vector game icon, bold simple silhouette, thick clean outline, centered on transparent background, high contrast, readable at 16px, no text, no watermark --ar 1:1 --style raw --v 7`

| 파일 | 색 | 앞부분 프롬프트 |
|---|---|---|
| `wood.png` | 초록 `#6FCF6F` | `a single curled young leaf sprout, fresh spring green, glossy highlight,` |
| `fire.png` | 주황 `#FF6B4A` | `a single teardrop flame, orange to yellow gradient core, warm glow,` |
| `earth.png` | 황토 `#D2A56A` | `a rounded mountain rock with a flat top and one crack, ochre and warm brown,` |
| `metal.png` | 은회 `#CBD3DA` | `a polished hexagonal metal nut with a bright specular streak, cool silver steel,` |
| `water.png` | 파랑 `#4AA8FF` | `a single water droplet with a crescent highlight, deep to light blue gradient,` |

> **규격**: 배경 제거 후 128×128↑ RGBA PNG. 색은 표의 HEX 에 맞춘다 — 앱이 같은
> 색으로 이름·테두리를 칠하므로(`labels.dart → elementColor`) 그림만 다른 색이면
> 따로 논다.
>
> ⚠️ 다섯 장을 **한 번에 같은 조건으로** 뽑을 것. 하나씩 뽑으면 굵기·광택이 갈려
> 나란히 놓았을 때 한 세트로 안 보인다(재료 아이콘에서 겪은 문제 §4).

## 5. 등급 프레임 ×5 (`assets/images/frames/`)

공통: `ornate rounded card frame border, gem accents, empty transparent center, mobile gacha rarity frame, {STYLE} --ar 1:1`
파일명·색: `common` gray · `uncommon` green · `rare` blue · `epic` purple · `legendary` gold(빛나는).

---

## 6. 작업 순서 (임팩트 우선)

1. **스타일 키 이미지 확정** (곤충 1마리)
2. **필드 배경 ×4** — 화면 인상 가장 큼
3. **트랩 ×4 + 재료 ×4** — 홈/인벤 즉시 반영
4. **곤충 ×20** — key 레퍼런스로 배치 생성
5. **등급 프레임 + UI 이펙트**

## 7. 앱 결합 (파일명 = JSON id)

- 넣는 위치: `packages/app/assets/images/{bugs,fields,traps,materials,frames}/`
- 파일명은 **JSON id와 동일**하게 (`stag_dorcus.webp` ↔ species.json `id:"stag_dorcus"`).
- 데이터에 경로 필드 추가 예정: `species.json→"image"`, `fields.json→"bg"`, `traps.json→"icon"`.
- 애셋이 아직 없으면 **현재 아이콘/색으로 자동 폴백** → 하나씩 채워 넣으면 점진적으로 게임이 살아난다.
