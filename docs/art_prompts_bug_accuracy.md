# Bug Champ — 곤충 고증 바로잡기 (Gemini)

> 2026-10-20 문의 "종마다 애벌레도 장수풍뎅이, 사슴벌레 이미지라도 최소 좀 맞게" + 곤충학과 유저 지적
> ("왕사슴벌레를 유럽사슴벌레로 그려 놨다 — 루카누스 계열이랑 도르쿠스는 아예 다른 종").
>
> **왜 틀렸나**: 처음 프롬프트(`pet_stage_prompts.md`)가 생김새를 한 줄로만 적었고(두점박이 = "등에 밝은 점 두 개" — 실제는 앞가슴의 검은 점),
> 전투 프레임(`art_prompts.md §2b`)은 `--cref` 로 **그 틀린 그림을 기준**으로 삼아 틀린 생김새가 그대로 이어졌다.
> 이번엔 **화풍만** 기존 그림에서 가져오고, 생김새는 아래 해부 설명(+ 가능하면 실제 사진)으로 정한다.
>
> **쓰는 법**
> 1. 첨부 ① 화풍: 칸마다 적힌 기존 그림 한 장(생김새는 따라 하지 말라고 프롬프트에 적혀 있다).
> 2. 첨부 ② 실제 사진(권장): 그 종 **수컷 성충/애벌레 실물 사진** 한 장 — 검색해서 받은 사진이면 된다. 생김새가 가장 정확해진다.
> 3. 프롬프트 칸을 통째로 복사 → Gemini 에 붙여넣기.
> 4. **파일명** 칸 그대로 `C:\Users\Lenovo\Downloads` 에 저장.
> 5. "고증 그림 만들었어"라고 알려 주면 배경 제거·자르기·크기 맞춤 후 앱에 넣는다.
>    성충: `python tool/place_bug_frames.py --from C:\Users\Lenovo\Downloads --only <id>` · 애벌레·번데기: 배경 제거 → 512px webp.
>
> **우선순위**: A(문의 대상 — 애벌레·번데기) → B(크게 틀린 성충 9종) → C(B 를 바꾼 종의 유료 스킨).
> 그림이 없는 칸은 지금 그림으로 조용히 내려가므로(`art.dart → bugFamilyFallback`) **하나씩 넣어도 된다.**

---

## A. 애벌레·번데기 (15장)

**애벌레 = 무리별 3장**: 사슴벌레(사슴벌레과)와 장수풍뎅이(풍뎅이과 장수풍뎅이아과)·꽃무지(꽃무지아과)는 애벌레가 다르다
(사슴벌레 = 털이 적고 매끈 · 장수풍뎅이 = 크고 주름·털·옆구리 숨구멍이 뚜렷 · 꽃무지 = 다리가 아주 짧고 **등으로 기어 다닌다**).
같은 사슴벌레과 안에서는 애벌레가 거의 같아서(전문가도 항문 모양·크기로 가른다) 종마다 그리면 같은 그림 6장이 된다.
**번데기 = 종마다 9장**: 딱정벌레 번데기는 고치가 아니라 **다리·더듬이·큰턱·뿔이 몸에 붙어 드러나는 모양**(나용)이라 종이 보인다.
지금 공통 번데기(형태 없는 덩어리)가 가장 크게 틀린 그림이다.

화풍 첨부 ①: `D:\coding\BugChamp\packages\app\assets\images\bugs\stage_scarab_larva.png`

공통 꼬리말(각 프롬프트 끝에 이미 들어 있다):
`Style: detailed painterly naturalist illustration with a soft dark outline, matching the attached style image. Single isolated subject, plain flat pale sage-green background touching the outline directly, no ground, no shadow, no glow, no text, no watermark. Square 1:1.`

### A1. 사슴벌레 애벌레 (사슴벌레 6종 공통)

```
Use the first attached image only as the art style reference. Do NOT copy its anatomy. If a second photo is attached, follow its anatomy exactly. Subject: a stag beetle grub (Lucanidae larva, e.g. Dorcus / Lucanus): plump C-shaped creamy-white grub, smooth soft skin with only sparse fine hairs, rounded glossy orange-amber head capsule with strong dark-tipped mandibles, three pairs of well-developed orange-tinted legs, small orange spiracle dots along each side, rear abdomen only slightly enlarged. Strict side profile, head facing RIGHT. Style: detailed painterly naturalist illustration with a soft dark outline, matching the attached style image. Single isolated subject, plain flat pale sage-green background touching the outline directly, no ground, no shadow, no glow, no text, no watermark. Square 1:1.
```

파일명

```
stage_stag_larva
```

### A2. 장수풍뎅이 애벌레 (장수풍뎅이·외뿔장수풍뎅이 공통)

```
Use the first attached image only as the art style reference. Do NOT copy its anatomy. If a second photo is attached, follow its anatomy exactly. Subject: a rhinoceros beetle grub (Dynastinae larva, Trypoxylus dichotomus): very large heavy C-shaped grub, creamy white with a grey-blue tint in the swollen rear abdomen, skin deeply folded into wrinkles and covered with short stiff reddish-brown bristles, a row of distinct dark brown oval spiracles along each side, dark reddish-brown head capsule with black mandibles, three pairs of short legs. Strict side profile, head facing RIGHT. Style: detailed painterly naturalist illustration with a soft dark outline, matching the attached style image. Single isolated subject, plain flat pale sage-green background touching the outline directly, no ground, no shadow, no glow, no text, no watermark. Square 1:1.
```

파일명

```
stage_rhino_larva
```

### A3. 꽃무지 애벌레 (장수꽃무지)

```
Use the first attached image only as the art style reference. Do NOT copy its anatomy. If a second photo is attached, follow its anatomy exactly. Subject: a flower chafer grub (Cetoniinae larva): thick stout C-shaped creamy-white grub with a broad rounded rear, very short tiny legs, small brown head capsule, back covered with rows of short stiff brown bristles; it crawls on its back in real life, so draw it lying on its back with the tiny legs up and the bristly back on the bottom. Side profile, head facing RIGHT. Style: detailed painterly naturalist illustration with a soft dark outline, matching the attached style image. Single isolated subject, plain flat pale sage-green background touching the outline directly, no ground, no shadow, no glow, no text, no watermark. Square 1:1.
```

파일명

```
stage_chafer_larva
```

### A4~A12. 번데기 (종마다)

공통 앞말: 아래 `<SPECIES>` 자리만 칸마다 다르다.

```
Use the first attached image only as the art style reference. Do NOT copy its anatomy. If a second photo is attached, follow its anatomy exactly. Subject: the pupa of <SPECIES>. Beetle pupae are exarate: NOT a cocoon and NOT a smooth shell — legs, antennae, wing pads and the mandibles or horns are folded tightly against the underside and clearly visible as separate sculpted parts; segmented abdomen with small paired lobes along the sides; waxy semi-translucent pale cream body turning amber. Lying on its back-side curve, strict side profile, head facing RIGHT. Style: detailed painterly naturalist illustration with a soft dark outline, matching the attached style image. Single isolated subject, plain flat pale sage-green background touching the outline directly, no ground, no shadow, no glow, no text, no watermark. Square 1:1.
```

| 파일명 | `<SPECIES>` 자리에 넣을 말 |
|---|---|
| `stag_dorcus_pupa` | `a male Korean Dorcus stag beetle (Dorcus rectus): short stout mandibles curving inward with one small inner tooth, folded forward under the head` |
| `stag_saw_pupa` | `a male saw stag beetle (Prosopocoilus inclinatus): long mandibles strongly arched forward then downward, a row of saw teeth along the inner edge` |
| `stag_flat_pupa` | `a male flat stag beetle (Dorcus titanus castanicolor): very flat broad body, long nearly straight mandibles with a row of many small inner teeth and one larger tooth near the base` |
| `stag_miyama_pupa` | `a male miyama stag beetle (Lucanus maculifemoratus): large curved mandibles with forked tips, head with ear-like lateral flanges behind the eyes` |
| `stag_giant_pupa` | `a male giant stag beetle (Dorcus hopei): broad head, thick smoothly arched caliper-like mandibles with one large blunt inner tooth, simple pointed tips (NOT forked)` |
| `stag_twospot_pupa` | `a male two-spotted stag beetle (Prosopocoilus astacoides blanchardi): long slender gently curved mandibles with fine teeth, pale amber body` |
| `rhino_japanese_pupa` | `a male Japanese rhinoceros beetle (Trypoxylus dichotomus): long head horn with a twice-forked tip lying folded down along the underside, short forked thoracic horn bump on the pronotum, amber-orange colour` |
| `rhino_lesser_pupa` | `a male Eophileurus chinensis rhinoceros beetle: small slim body, one short slender upright horn on the head, pronotum with a central lengthwise groove, no thoracic horn` |
| `chafer_flower_pupa` | `a male stag-horned flower chafer (Dicronocephalus adamsi): front of the head extended into two forward antler-like horns, very long front legs folded along the body` |

### A13~A15. 방아깨비·여치 (지금 공통 그림이 여치형이라 방아깨비와 안 맞는다)

화풍 첨부 ①: `D:\coding\BugChamp\packages\app\assets\images\bugs\stage_ortho_larva.png`

| 파일명 | 프롬프트 |
|---|---|
| `grasshopper_longheaded_larva` | `Use the first attached image only as the art style reference. Do NOT copy its anatomy. If a second photo is attached, follow its anatomy exactly. Subject: an early nymph of the oriental longheaded grasshopper (Acrida cinerea): tiny wingless very slender elongated green body, long cone-shaped head pointing forward and upward, short flat sword-shaped antennae, very long thin hind legs. Strict side profile, head facing RIGHT. Style: detailed painterly naturalist illustration with a soft dark outline, matching the attached style image. Single isolated subject, plain flat pale sage-green background touching the outline directly, no ground, no shadow, no glow, no text, no watermark. Square 1:1.` |
| `grasshopper_longheaded_pupa` | 위와 같고 Subject 만: `a late-instar nymph of the oriental longheaded grasshopper (Acrida cinerea): long slender green body, long cone-shaped head, short flat sword-shaped antennae, very long hind legs, small triangular wing buds on the back (this insect has no true pupa).` |
| `katydid_egg` | `Use the first attached image only as the art style reference. Subject: three separate long flat oval katydid eggs (Gampsocleis), pale grey-beige, laid side by side — katydids lay single eggs with an ovipositor, NOT an egg pod. Style: detailed painterly naturalist illustration with a soft dark outline. Plain flat pale sage-green background touching the outline directly, no ground, no shadow, no glow, no text, no watermark. Square 1:1.` |

---

## B. 크게 틀린 성충 9종 (전투 프레임 시트 — 가로 3칸)

화풍 첨부 ①: `D:\coding\BugChamp\packages\app\assets\images\bugs\stag_dorcus_adult_1.webp` (생김새가 맞는 쪽 그림)
**첨부 ② 실제 수컷 사진을 꼭 붙이길 권한다** — 성충은 문의한 유저처럼 아는 사람이 바로 알아본다.

공통 골격(§2b 와 같다 — `left:`/`center:`/`right:` 절이 칸을 가르는 장치라 지우지 않는다). `<ANATOMY>`·`<CENTER>` 만 종마다 다르다.

```
Use the first attached image only as the art style reference (painting style, eyes, outline, palette). Do NOT copy its anatomy. If a second photo is attached, follow its anatomy exactly. Character pose sheet of the same insect: <ANATOMY> Anatomy rules: exactly six legs (three on the near side, three partly hidden on the far side), correct antennae for this species, no extra horns or spikes. Three poses in one horizontal row, identical creature at identical size standing on the same ground line, strict side profile facing right, evenly spaced with wide even gaps, no dividing lines, no panel borders, no numbers, no labels, plain flat pale sage-green background; left: standing idle, weight settled, all legs planted, calm ready stance; center: <CENTER>; right: recoiling from a heavy hit, knocked backward and tilted up, legs buckling underneath, head thrown back, off balance. Cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark. Wide 3:1 image.
```

| 파일명 | 지금 그림의 문제 | `<ANATOMY>` | `<CENTER>` |
|---|---|---|---|
| `stag_giant` | 끝이 갈라진 가는 큰턱 = *Lucanus* 생김새(유저 지적) | `a male Korean giant stag beetle (Dorcus hopei): glossy jet-black, broad parallel-sided body, smooth shiny elytra, wide flat head without ear-like flanges, thick heavy mandibles smoothly arched inward like calipers with ONE large blunt inner tooth at about the middle and simple pointed tips (NOT forked, NOT long and thin like Lucanus), short elbowed antennae with a small comb-like club.` | `lunging seize, thick arched mandibles thrown wide open and reaching out to clamp, front of the body reared up` |
| `stag_flat` | 하늘소 같은 긴 톱니 더듬이 | `a male flat stag beetle (Dorcus titanus castanicolor): black, very flat and wide body, slightly matte finely textured elytra, long nearly straight mandibles that curve inward only at the tips, a row of many small teeth along the inner edge and one larger tooth near the base, short elbowed antennae with a small comb-like club (NOT long antennae).` | `lunging seize, long flat mandibles thrown wide open and reaching out to clamp, front of the body reared up` |
| `stag_twospot` | 적갈색 + 딱지날개 위 주황 점 | `a male two-spotted stag beetle (Prosopocoilus astacoides blanchardi): body yellowish amber-brown (NOT red), ONE round black spot on each side of the pronotum (the thorax plate behind the head) and NO spots on the wing covers, long slender gently curved mandibles with a row of fine teeth, short elbowed antennae.` | `heaving throw, mandibles scooping upward, front of the body lifted high, rear legs braced and coiled` |
| `rhino_lesser` | 갈색 + 장수풍뎅이식 가슴 | `a male Eophileurus chinensis rhinoceros beetle: small, glossy jet-black (NOT brown), slightly flattened elongate body, one short slender upright horn on the head, pronotum with a broad lengthwise central groove and NO thoracic horn, short lamellate antennae.` | `charging strike, body pitched low and thrust forward, single short horn driving straight ahead, rear legs kicking off the ground` |
| `longhorn_relict` | 주황 몸에 점, 가는 긴 더듬이, 큰턱 없음 | `a male Korean relict longhorn beetle (Callipogon relictus, the largest beetle in Korea): huge, dark chestnut-brown body with patches of velvety golden-yellow hair on the pronotum and elytra, LARGE strong mandibles curving forward and down, pronotum sides with several sharp spines, thick antennae about as long as the body, long strong front legs.` | `lunging seize, big mandibles thrown wide open and reaching out to clamp, front of the body reared up` |
| `longhorn_saw` | 머리에 뿔 | `a male Prionus insularis longhorn beetle: dark brown to black-brown, matte, broad body, NO horn on the head, strong short mandibles, three sharp spines on each side of the pronotum, saw-toothed (serrate) antennae shorter than the body.` | `lunging seize, mandibles thrown wide open and reaching out to clamp, front of the body reared up` |
| `mantis_jumping` | 머리 위 원뿔 뿔, 더듬이 없음 | `a small slender Statilia maculata mantis: mottled grey-brown, smooth triangular head with NO horn or cone on top, thin thread-like antennae, slim body, brownish wings reaching the abdomen tip, a distinct black-and-white patch on the inner side of the raised front legs.` | `charging strike, body pitched low and thrust forward, raptorial forelegs driving straight ahead, rear legs kicking off the ground` |
| `grasshopper_longheaded` | 정수리 뿔, 긴 톱니 더듬이, 통통한 몸 | `an oriental longheaded grasshopper (Acrida cinerea): very long and slender green body, the whole head is a long cone pointing forward and upward (NO horn on top), short flat sword-shaped antennae, very long thin hind legs, long narrow pointed wings.` | `heaving throw, powerful hind legs scooping upward, front of the body lifted high, rear legs braced and coiled` |
| `chafer_flower` | 금속빛 초록 꽃무지 = 다른 종 | `a male stag-horned flower chafer (Dicronocephalus adamsi): front of the head extended into two forward antler-like horns, very long front legs, compact flower-chafer body, brownish body with a pale powdery coating and two dark lengthwise stripes on the pronotum (follow the attached photo for the exact colours).` | `charging strike, body pitched low and thrust forward, antler-like head horns driving straight ahead, rear legs kicking off the ground` |

> ⚠️ 장수꽃무지 색·무늬(흰 가루·앞가슴 줄)는 검색으로 확인하지 못했다(뿔·긴 앞다리는 확인). **사진 첨부 필수**.

---

## C. B 를 바꾼 종의 유료 스킨 (산 사람에게 보이는 그림)

성충 생김새가 바뀌면 스킨만 옛 생김새로 남는다. `art_prompts.md §2c` 프롬프트를 쓰되, `--cref` 대신 **B 에서 새로 만든 그림**을 첨부 ① 로 쓰고
첫 줄 주제만 B 의 `<ANATOMY>` 로 바꾼다. 처리: `python tool/place_bug_frames.py --from C:\Users\Lenovo\Downloads --skin albino` (·`--skin gold`).

| 파일명 | 스킨 | 바꿀 점 |
|---|---|---|
| `stag_giant` | 알비노(크리스탈) | 굵은 둥근 큰턱 + 안쪽 큰 이빨 하나 |
| `stag_flat` | 알비노 | 짧은 꺾인 더듬이 |
| `stag_twospot` | 알비노 | "등의 루비 두 개" → **앞가슴 양옆** 루비 두 개 |
| `rhino_lesser` | 황금 | 가슴 뿔 없이 가운데 홈 |

---

## 그대로 둬도 되는 것 (점검 결과)

- 성충: 애사슴벌레 · 톱사슴벌레 · 사슴벌레 · 왕사마귀 · 여치 — 대체로 맞음.
- 조금 틀림(여유 있을 때): 장수풍뎅이 배·머리 초록빛(실제 적갈색~흑색) · 알락하늘소 더듬이(흰·검 고리 무늬여야) · 참나무하늘소 무늬 없음 ·
  넓적배사마귀 앞날개 흰 점 없음 · 물장군 몸이 두껍고 주둥이·숨관 없음 · 장수말벌 가슴 초록빛.
- 단계: 사슴벌레·장수풍뎅이 알 · 하늘소 애벌레·번데기 · 사마귀 알집·약충 · 말벌 애벌레는 맞음.

---

## 배치 기록 (2026-10-21)

- 단계 15장: `python tool/place_stage_art.py --from C:\Users\Lenovo\Downloads\곤충고증` · 방아깨비 두 장만 `--only … --holes 400`
  (뒷다리 사이에 갇힌 배경. `--holes` 를 다 켜면 장수풍뎅이·꽃무지 애벌레의 회청색 배가 뚫린다).
- 성충 9종: Gemini 가 **가로 바닥선**을 그려 넣어서(7장) 선을 먼저 배경색으로 지운 png 로 돌렸다.
  `place_bug_frames.py --cut flood` — 기본 rembg 는 좀사마귀 2·3번 칸의 머리·앞다리를 지우고 다리 사이 배경을 남겼다.
  장수꽃무지·왕사슴벌레는 `--tol 16`(크림색 등·광택이 배경으로 뚫림).
- 시트가 1024×434 라 칸당 약 400px(예전 640). 아레나는 288px 로 그려서 쓸 만하다.
- 2차(2026-10-21): 장수풍뎅이 번데기·방아깨비 어린 약충·왕사슴벌레·장수꽃무지(`--tol 10`)·좀사마귀 + 황금 외뿔장수풍뎅이 배치.
  알비노 3장은 실패 — 대기 자세 한 장만 주고 세 자세를 새로 그리게 했더니 자세 이름 글자를 써 넣고, 왼쪽을 보거나
  뒤집히고("belly showing" 문구 탓), 큰턱이 다시 갈라졌다. 3차는 **새 성충 시트 전체를 붙이고 "재질만 바꿔 그대로"**
  (`art_prompts_bug_accuracy_round3_spec.py`).
- 3차(2026-10-21): 알비노 3장(왕사슴벌레·넓적·두점박이) 성공 — 시트 전체를 붙이고 "재질만"이면 자세·방향·생김새가 그대로 나온다.
  넓적 알비노는 1번 칸 큰턱 끝과 2번 칸 뒷다리가 가로로 겹쳐 세로 한 줄로 못 잘랐다 → 덩어리별로 떼어 간격을 벌린 시트로 배치
  (scratchpad `spread_sheet.py` — 같은 일이 잦으면 `place_bug_frames.py` 에 넣는다).
- 4차(2026-10-21): 장수말벌 번데기 `stage_hornet_pupa.webp`(옛 덩어리 png 삭제) — 사진은 미국 농무부 ARS 장수말벌 번데기(퍼블릭 도메인).
