# Bug Champ — 아이콘 시트 프롬프트 (Gemini · 한 장에 8개)

> **쓰는 법**
> 1. 화풍을 맞추려면 기존 아이콘 한 장을 **함께 첨부**하세요:
>    `C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\upgrades\attack.webp`
> 2. 시트마다 프롬프트 칸을 **통째로 복사 → Gemini 에 붙여넣기**.
> 3. 저장할 때 아래 **파일명** 칸을 복사해 붙여넣고 **다운로드 폴더**에 저장하세요(확장자는 그대로).
> 4. 다 만드시면 "아이콘 시트 만들었어"라고 알려 주세요. 제가 칸을 잘라 배경 제거·
>    워터마크 제거·크기 맞춤까지 하고 앱에 연결합니다.
> 5. **시트 1 한 장만 먼저 뽑아 보여 주셔도 됩니다** — 격자가 제대로 나오는지 확인하고
>    나머지를 돌리는 게 안전합니다(세 장을 다 뽑은 뒤 격자가 어긋나 있으면 전부 다시입니다).

**총 3장 · 아이콘 24개.** 자르는 도구는 이미 만들어 두었고 가짜 시트로 검증까지 마쳤습니다
(`tool/import_icon_sheet.py`).

---

## ⚠️ 시트 규칙 (이걸 어기면 제가 못 자릅니다)

- **3×3 격자 = 9칸.** 위 6칸 + 아래 왼쪽 2칸 = **8개만 그리고, 오른쪽 아래 한 칸은 비웁니다.**
  - 비우는 이유: 제미나이 워터마크(✦)가 **항상 오른쪽 아래**에 찍힙니다(1024 기준 x880~927).
    3×3 격자에서 그 자리는 **정확히 오른쪽 아래 칸**입니다. 비워 두면 워터마크가 배경 위에만
    놓여 **자동으로 지워집니다.** 그림 위에 겹치면 손으로 메워야 하고 자국이 남습니다.
- **칸마다 물건 하나**, 같은 크기로 가운데에. 칸 사이 여백을 넉넉히.
- **배경은 전체가 하나의 평평한 연한 세이지 그린**(칸마다 다른 색을 쓰지 마세요).
  격자선·테두리·번호를 그리지 마세요 — 제가 그림 위치를 찾아 자릅니다.
- **그림자(drop shadow)를 넣지 마세요.** 배경 위 그림자는 누끼 후 연초록 얼룩으로 남습니다
  (2026-09-16 에 실제로 겪었습니다).
- **글자·숫자·로고 금지.**
- 순서는 **왼쪽 → 오른쪽, 위 → 아래**입니다. 아래 목록의 번호와 같아야 합니다.

칸 하나가 약 341px 로 나옵니다. 화면에서 아이콘은 28~64논리px(고해상도 기기에서 최대 192px)로
보이므로 **해상도는 넉넉합니다.**

---

## 시트 1 — 미션 · 부위 강화

1 뿔·큰턱(공격) · 2 표피(방어) · 3 날개(속도) · 4 체격(체력)
5 몬스터 처치 · 6 보스 처치 · 7 강화 구매 · 8 제련 · **9번 칸은 비움**

```
Use the attached image only as the art style reference. Do NOT copy its subject. Create ONE image containing a 3x3 grid of 9 equal cells on a single continuous flat pale sage-green background. Draw exactly 8 separate game icons, one centered in each cell, all the same size, with generous empty space between them. LEAVE THE BOTTOM-RIGHT CELL COMPLETELY EMPTY - just plain background there. Do not draw any grid lines, borders, frames or numbers. Reading left to right, top to bottom, the 8 icons are: (1) a mighty rhinoceros beetle horn crossed with a stag beetle mandible, symbol of attack power; (2) a segmented armored beetle shell plate with a hard glossy surface, symbol of defense; (3) a pair of translucent iridescent insect wings mid-beat with small speed streaks, symbol of agility; (4) a sturdy round beetle body with a glowing warm core, symbol of vitality; (5) three tiny cartoon bugs tumbling with little impact sparks, symbol of hunting monsters; (6) a large flaming boss beetle skull with a fiery aura, symbol of defeating a boss; (7) a golden upward arrow rising out of an open palm with sparkles, symbol of buying upgrades; (8) a blacksmith hammer striking an amber anvil with sparks flying, symbol of forging. Style for every icon: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail, readable at small size. Front view, flat-on, no perspective tilt, and NO drop shadow under the objects. no text, no letters, no numbers, no watermark, no logo.
```

파일명

```
sheet_mission_part
```

---

## 시트 2 — 트로피 · 보상

1 트로피(우승) · 2 계급장(리그 승급) · 3 왕관(시즌 최고 등급) · 4 사냥터 도달(미션)
5 보상 획득 · 6 선물상자 · 7 우편 · 8 선물코드 · **9번 칸은 비움**

```
Use the attached image only as the art style reference. Do NOT copy its subject. Create ONE image containing a 3x3 grid of 9 equal cells on a single continuous flat pale sage-green background. Draw exactly 8 separate game icons, one centered in each cell, all the same size, with generous empty space between them. LEAVE THE BOTTOM-RIGHT CELL COMPLETELY EMPTY - just plain background there. Do not draw any grid lines, borders, frames or numbers. Reading left to right, top to bottom, the 8 icons are: (1) a golden victory trophy cup with a small beetle emblem on its front; (2) a rank medal with a cloth ribbon and a rising chevron, symbol of promotion; (3) an ornate golden crown resting on a leaf cushion, symbol of the top seasonal rank; (4) a checkered flag planted on a mossy hill, symbol of reaching a new hunting ground; (5) a burst of golden coins and sparkles spilling from a small treasure pile, symbol of receiving a reward; (6) a wrapped gift box with a green ribbon and a tiny leaf tag, lid slightly lifted with light glowing out; (7) a rustic wooden mailbox with a folded letter sticking out of it; (8) a paper coupon ticket with a punched hole and a small key emblem, symbol of a gift code. Style for every icon: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail, readable at small size. Front view, flat-on, no perspective tilt, and NO drop shadow under the objects. no text, no letters, no numbers, no watermark, no logo.
```

파일명

```
sheet_trophy_reward
```

---

## 시트 3 — 진행 · 안내

1 알(뽑기 결과) · 2 채집함 필터 · 3 결투 티켓 · 4 오프라인 보상(해·달)
5 사냥터 클리어 · 6 난이도 클리어(관문) · 7 오행 상성표 · 8 공지 · **9번 칸은 비움**

```
Use the attached image only as the art style reference. Do NOT copy its subject. Create ONE image containing a 3x3 grid of 9 equal cells on a single continuous flat pale sage-green background. Draw exactly 8 separate game icons, one centered in each cell, all the same size, with generous empty space between them. LEAVE THE BOTTOM-RIGHT CELL COMPLETELY EMPTY - just plain background there. Do not draw any grid lines, borders, frames or numbers. Reading left to right, top to bottom, the 8 icons are: (1) a speckled insect egg glowing with warm light, resting on a small patch of moss; (2) a funnel filter with tiny beetles falling through it and a leaf forming a check mark, symbol of filtering a collection; (3) a torn paper admission ticket with a punched hole and two crossed beetle mandibles printed on it, symbol of a duel ticket; (4) a crescent moon and a small sun together above a sleeping beetle, symbol of offline earnings; (5) a wooden signpost with a small victory banner on a mossy trail, symbol of clearing a hunting ground; (6) a tall stone gate arch standing open with light pouring through it, symbol of clearing a difficulty; (7) a circular ring holding five elemental symbols spaced evenly around it - a leaf, a flame, a stone, a metal ingot and a water drop; (8) a wooden megaphone wrapped in vines with sound waves coming out of it, symbol of an announcement. Style for every icon: glossy stylized mobile game UI icon, cozy naturalist storybook palette (moss green, honey amber, warm bark brown, soft cream), semi-realistic painterly shading, soft rim light, bold readable silhouette, thick warm brown outline, high detail, readable at small size. Front view, flat-on, no perspective tilt, and NO drop shadow under the objects. no text, no letters, no numbers, no watermark, no logo.
```

파일명

```
sheet_progress_info
```

---

## 어디에 쓰이나 (제가 연결할 자리)

| 시트 | 아이콘 | 지금 코드 아이콘 | 쓰이는 곳 |
|---|---|---|---|
| 1 | 뿔·큰턱 / 표피 / 날개 / 체격 | `bolt` `shield` `air` `favorite` | 보관함 → 곤충 상세 **부위 강화**(§2.2) |
| 1 | 몬스터·보스·강화·제련 | `pest_control` `local_fire_department` `upgrade` `hardware_rounded` | 홈 **미션 줄**(상시 노출) |
| 2 | 트로피 / 계급장 / 왕관 | `emoji_events`×11 · `military_tech`×6 · `workspace_premium`×12 | 결투·리그·대회·명예의 전당 |
| 2 | 사냥터 도달 | `flag_rounded` | 미션 |
| 2 | 보상·선물·우편·선물코드 | `card_giftcard` `campaign` `mail` `confirmation_number` | 팝업 제목 |
| 3 | 알·필터·티켓·오프라인·사냥터·난이도·오행·공지 | `egg_rounded` `filter_alt` `confirmation_number` `wb_sunny` `emoji_events` `military_tech` `hub` `campaign` | 팝업 제목 |

---

## 그림 없이 해결되는 것 — **이미 있는 아트를 붙인다**

아래 팝업들은 제목만 Material 아이콘이고, **같은 뜻의 아트가 이미 앱에 있습니다.**
새로 그릴 필요 없이 제가 코드만 연결하면 됩니다.

| 팝업 | 지금 | 붙일 기존 아트 |
|---|---|---|
| 자동 합성 | `auto_awesome_motion_outlined` | `ui/auto_synth.webp` |
| 자동 방생 | `recycling_rounded` | `ui/auto_release.webp` |
| 교환소 | `inventory_2_rounded` | `ui/exchange.webp` |
| 부화기 선택 | `egg_alt` | `ui/incubator_capsule.png` |
| 공방 급행 | `fast_forward_rounded` | `ui/anvil.webp` |
| 알 뽑기(카드 선택) | `style_rounded` | `ui/gacha_card_back.webp` |

---

## 일부러 뺀 것

- **크롬 아이콘 34개**(닫기·화살표·설정·복사) — 그림으로 바꾸면 오히려 알아보기 어려워집니다.
- **이미 아트가 있는 것** — 재료 5 · 오행 5 · 강화 15 · 버프 6 · 리그 5 · 특성 4 · 스탠스 3 ·
  기질 5 · 성별 2 · 장비 전 등급 · 곤충 · 보스 44 · 서식지 · 도감.
- **드물게 뜨는 팝업** — 계정 삭제·차단·신고·업데이트 안내·닉네임 변경·문의·경고.
  자주 안 보이는 자리에 아트를 넣는 건 품이 아깝습니다.
