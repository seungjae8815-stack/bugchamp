# 곤충 생애주기 이미지 프롬프트 (총 38장)

> 초기 단계는 곤충 그룹마다 생김새가 달라 **그룹별 공통 세트**로, 성충은 종별로.
> - **알·유충·번데기 = 6그룹 × 3단계 = 18장** (같은 그룹 종끼리 재사용)
> - **성충 = 종별 20장**
> 저장: `assets/images/bugs/` 에 아래 파일명 그대로. `.webp`·`.png` 모두 인식.
> (특정 종만 따로 그리고 싶으면 `{id}_egg.webp` 처럼 두면 그 종만 override 됨.)

## 규칙
- **유충·약충·성충 = 측면(옆) 프로필, 오른쪽(→) 향, 다리로 선 2D 사이드스크롤 스프라이트.** top-down/등면/정면/표본 금지.
- **알·번데기 = 방향 없는 단독 오브젝트**, 번데기는 닫힌 불투명(내부 안 보임).
- **불완전변태(mantis·ortho·waterbug)는 번데기 없음 → "번데기" = 후기 약충(날개싹)**, 측면.
- **몬스터 그림풍**(반실사 페인팅, 진한 음영·부드러운 외곽선), **투명 배경 · 흙/바닥/그림자/글자 없음**.

---

# A. 그룹별 초기 단계 세트 (18장)

## scarab (사슴벌레·장수풍뎅이·꽃무지 9종 공통)
**stage_scarab_egg** — A single smooth glossy cream-white oval beetle egg — detailed painterly monster art, soft dark outline, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1
**stage_scarab_larva** — A single plump C-shaped white scarab beetle grub (chunky segmented body, amber-brown head capsule, tiny legs) — strict lateral side-profile facing RIGHT, pure side view (NOT top-down, NOT dorsal). Detailed painterly monster art, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1
**stage_scarab_pupa** — A single pale creamy closed opaque beetle pupa, smooth casing, interior not visible — detailed painterly monster art, soft dark outline, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1

## borer (하늘소 4종 공통)
**stage_borer_egg** — A single tiny pale elongated longhorn beetle egg — detailed painterly monster art, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1
**stage_borer_larva** — A single long segmented cream-white roundheaded wood-borer larva (elongate legless body, small brown head) — strict lateral side-profile facing RIGHT, pure side view (NOT top-down, NOT dorsal). Detailed painterly monster art, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1
**stage_borer_pupa** — A single pale closed opaque longhorn beetle pupa, smooth casing, long antennae folded along it, interior not visible — detailed painterly monster art, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1

## mantis (사마귀 3종 공통 — 번데기 없음)
**stage_mantis_egg** — A single tan foamy praying-mantis ootheca (egg case) — detailed painterly monster art, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1
**stage_mantis_larva** — A single tiny slender pale-green praying mantis nymph (looks like a mini adult, raptorial arms) — strict lateral side-profile facing RIGHT, pure side view (NOT top-down, NOT front). Detailed painterly monster art, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1
**stage_mantis_pupa** — A single larger green praying mantis LATE-INSTAR NYMPH with small wing buds (this insect has no true pupa) — strict lateral side-profile facing RIGHT, pure side view (NOT top-down, NOT front). Detailed painterly monster art, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

## ortho (방아깨비·여치 2종 공통 — 번데기 없음)
**stage_ortho_egg** — A single small tan grasshopper egg pod — detailed painterly monster art, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1
**stage_ortho_larva** — A single small wingless green orthopteran nymph (grasshopper/katydid-like, big hind legs, long antennae) — strict lateral side-profile facing RIGHT, pure side view (NOT top-down, NOT dorsal). Detailed painterly monster art, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1
**stage_ortho_pupa** — A single larger green orthopteran LATE-INSTAR NYMPH with developing wing buds (no true pupa) — strict lateral side-profile facing RIGHT, pure side view (NOT top-down). Detailed painterly monster art, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

## waterbug (물장군 — 번데기 없음)
**stage_waterbug_egg** — A single tight cluster of brown barrel-shaped giant water-bug eggs — detailed painterly monster art, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1
**stage_waterbug_larva** — A single small flat brown giant water-bug nymph (looks like a tiny adult, raptorial forelegs) — strict lateral side-profile facing RIGHT, pure side view (NOT top-down, NOT dorsal). Detailed painterly monster art, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1
**stage_waterbug_pupa** — A single larger brown giant water-bug LATE-INSTAR NYMPH with wing buds (no true pupa) — strict lateral side-profile facing RIGHT, pure side view (NOT top-down). Detailed painterly monster art, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

## hornet (장수말벌)
**stage_hornet_egg** — A single glossy white hornet egg — detailed painterly monster art, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1
**stage_hornet_larva** — A single plump legless white hornet grub, gently curled — detailed painterly monster art, soft dark outline, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1
**stage_hornet_pupa** — A single pale cream closed opaque hornet pupa, smooth casing, interior not visible — detailed painterly monster art, transparent background, single isolated object, no ground, no shadow, no text. --ar 1:1

---

# B. 성충 20종 (측면·오른쪽 향)

**1 stag_dorcus_adult** — A single small glossy black stag beetle with short modest mandibles — strict lateral side-profile facing RIGHT, standing on all six legs, mandibles pointing right, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**2 stag_saw_adult** — A single amber-brown stag beetle with long curved saw-toothed mandibles — strict lateral side-profile facing RIGHT, standing on legs, mandibles pointing right, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**3 rhino_lesser_adult** — A single small dark-brown rhinoceros beetle with one single short horn — strict lateral side-profile facing RIGHT, standing on legs, horn pointing up-right, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**4 mantis_jumping_adult** — A single small slender brown praying mantis with raptorial arms forward — strict lateral side-profile facing RIGHT, standing pose, pure side view (NOT top-down, NOT front, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**5 longhorn_saw_adult** — A single matte brown longhorn beetle with serrated antennae — strict lateral side-profile facing RIGHT, standing on legs, antennae forward, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**6 grasshopper_longheaded_adult** — A single long-headed green grasshopper with a pointed face and long hind legs — strict lateral side-profile facing RIGHT, standing pose, face pointing right, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**7 stag_flat_adult** — A single broad flat wide-jawed glossy jet-black stag beetle, powerful — strict lateral side-profile facing RIGHT, standing on legs, wide mandibles pointing right, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**8 rhino_japanese_adult** — A single classic sturdy brown rhinoceros beetle with a Y-shaped horn — strict lateral side-profile facing RIGHT, standing on legs, Y-horn pointing up-right, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**9 mantis_widebelly_adult** — A single wide-bellied bright green praying mantis with raptorial arms forward — strict lateral side-profile facing RIGHT, standing pose, pure side view (NOT top-down, NOT front, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**10 longhorn_whitespot_adult** — A single black longhorn beetle with white speckles and very long antennae — strict lateral side-profile facing RIGHT, standing on legs, antennae forward, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**11 katydid_adult** — A single plump green katydid bush-cricket with long antennae — strict lateral side-profile facing RIGHT, standing pose, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**12 stag_miyama_adult** — A single miyama stag beetle with fuzzy golden head flanges and large arched mandibles — strict lateral side-profile facing RIGHT, standing on legs, mandibles pointing right, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**13 mantis_giant_adult** — A single large imposing green praying mantis, majestic, raptorial arms forward — strict lateral side-profile facing RIGHT, standing pose, pure side view (NOT top-down, NOT front, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**14 longhorn_oak_adult** — A single large brown oak longhorn beetle with extra-long banded antennae — strict lateral side-profile facing RIGHT, standing on legs, antennae forward, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**15 chafer_flower_adult** — A single iridescent metallic green-bronze flower chafer beetle — strict lateral side-profile facing RIGHT, standing on legs, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**16 stag_giant_adult** — A single giant glossy black stag beetle with thick powerful curved mandibles, regal — strict lateral side-profile facing RIGHT, standing on legs, mandibles pointing right, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**17 water_bug_giant_adult** — A single giant water bug with a flat brown body and strong raptorial forelegs forward — strict lateral side-profile facing RIGHT, standing pose, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**18 stag_twospot_adult** — A single reddish-brown stag beetle with two bright spots on its shell — strict lateral side-profile facing RIGHT, standing on legs, mandibles pointing right, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**19 longhorn_relict_adult** — A single colossal majestic relict longhorn beetle with a long elegant body and a subtle heroic golden rim glow — strict lateral side-profile facing RIGHT, standing on legs, antennae forward, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1

**20 hornet_giant_adult** — A single stylized asian giant hornet with an orange-yellow head, bold but not scary — strict lateral side-profile facing RIGHT, head pointing right, wings back, pure side view (NOT top-down, NOT dorsal, NOT a specimen). Detailed painterly monster art, rich shading, soft dark outline, transparent background, isolated, no ground, no shadow, no text. --ar 1:1
