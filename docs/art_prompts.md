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

## 4. 재료 아이콘 ×4 (`assets/images/materials/`)

공통: `glossy game item icon, single object, centered, plain background, {STYLE} --ar 1:1 --style raw`

| 파일명 | 프롬프트(핵심) |
|---|---|
| `chitin` | shiny chitin shell fragment, amber-brown, faceted |
| `mineral` | rough mineral crystal cluster, teal-blue |
| `sap` | golden sap crystal droplet, glowing honey amber |
| `jelly` | cute insect jelly cup, translucent, colorful |

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
