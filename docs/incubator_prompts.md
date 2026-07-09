# 부화기 캡슐 이미지 프롬프트 (2장)

> 채집함 하단 **🥚 부화기** → 캡슐 슬롯의 프레임 그림.
> 저장: `packages/app/assets/images/ui/` 에 아래 파일명 그대로.
> 없어도 코드가 기본 유리 캡슐(그라데이션)으로 폴백하므로, 넣으면 자동으로 고급 프레임으로 교체됨.

## 중요 규칙
- **세로 캡슐(포드) 모양**: 둥근 돔 지붕 + 아래 금속 받침 링.
- **가운데는 완전히 비어 투명**해야 함(알과 차오르는 액체를 코드가 그 안에 그림). 캡슐 안에 알/생물 그리지 말 것.
- **투명 배경**, 정면 뷰, 글자·바닥·그림자 없음.
- 두 장(열림/잠김)의 **크기·형태·구도 동일**하게(같은 자리에서 상태만 다르게).
- 게임 아트 톤: 따뜻한 자연주의 + 반실사 페인팅, 부드러운 발광.
- 비율 **--ar 2:3** (세로로 긴 캡슐).

---

## 1. incubator_capsule.png  (열린 캡슐)
A single empty vertical incubator capsule pod for a cozy insect-collecting game — a hollow see-through glass tube with a rounded dome top and a warm bronze-gold metal base ring with tiny rivets, soft teal-cyan inner glow along the glass rim, gentle glass reflections and a subtle vertical highlight, the CENTER is completely empty and fully transparent (no egg, no creature, nothing inside). Detailed painterly game-UI art, warm naturalist style, front view, isolated on a fully transparent background, no text, no ground, no shadow. --ar 2:3

## 2. incubator_capsule_locked.png  (잠긴 캡슐)
The same vertical incubator capsule pod, but SEALED and dormant — frosted dimmed glass, cool grey-blue tones, no glow, a small bronze padlock emblem centered on the glass, the same rounded dome top and metal base ring, identical size and framing to the unlocked capsule. Detailed painterly game-UI art, front view, isolated on a fully transparent background, no text, no ground, no shadow. --ar 2:3

---

## (선택) 배경까지 고급스럽게
캡슐 뒤에 깔 기계 패널이 필요하면 별도로:
**incubator_bg.png** — A cozy workshop incubator machine backdrop panel with warm wood and bronze, soft ambient lab glow, empty space for three capsule tubes, painterly game-UI art, no capsules drawn, no text, horizontal panel. --ar 16:9
(이건 지금 코드엔 미연결 — 원하면 붙여드림.)
