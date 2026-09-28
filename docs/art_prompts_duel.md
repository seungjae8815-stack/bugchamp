# 곤충 배틀 스타디움 그림 35장

2026-09-28 결투 개편. 설계 문서: `C:\Users\Lenovo\Desktop\coding\BugChamp\docs\design_duel.md`

- Gemini 에 코드블록을 그대로 붙여넣는다. 받은 그림은 `C:\Users\Lenovo\Downloads` 에 **파일명 그대로** 저장해 두면 배경 제거·칸 자르기·크기 맞춤은 내가 한다.
- 그림이 없어도 게임은 돈다(옆모습 회전·원형 그라데이션·코드 효과로 폴백). 들어오는 대로 끼운다.

## 연출 = 던질 때는 위에서, 싸울 때는 옆에서 (2026-09-28 사장님 결정)

- 캐릭터가 던지는 순간은 **위에서 내려다본** 경기장 위로 곤충이 떨어진다 → 곤충 **위에서 본 모습 한 장**이 필요하다.
- 곤충이 바닥에 닿으면 카메라가 내려와 **옆에서 본(낮은 각도) 경기장**에서 싸운다 → 곤충 모션은 **기존 옆모습 3자세(대기·공격·피격)를 그대로** 쓴다.
  뒤집힘은 옆모습을 180° 돌려 다리가 하늘로, 장외는 경기장 밖으로 튕겨 나가게 코드로 그린다.

| 묶음 | 장수 | 쓰이는 곳 |
|---|---|---|
| A. 곤충 위에서 본 모습 | 20 | 던져서 떨어지는 순간 |
| B. 경기장 위에서 본 모습 | 5 | 던지는 장면 |
| C. 경기장 옆에서 본 모습 | 5 | 싸움 장면 |
| D. 던지기 동작 | 1 | 발사 연출 |
| E. 효과 | 4 | 충돌·먼지·장외·기절 |

**곤충 합격 기준** — ① 원근 없이 정확히 위에서(좌우 대칭) ② 뿔·큰턱 길이가 옆모습과 같은 비율 ③ 색이 옆모습과 같다 ④ 글자 없음. 아니면 다시 뽑는다.
(앞서 시험한 걷기·공격·뒤집힘 시트는 이제 필요 없다 — 이미 뽑은 애사슴벌레 시트는 가운데가 아닌 **왼쪽 칸**을 잘라 위에서 본 모습으로 쓸 수 있다.)

옆모습 참고 이미지 폴더:

```
C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\bugs
```

---

# A. 곤충 위에서 본 모습 ×20

던져져 공중에서 떨어지는 순간에 쓴다 — 다리를 몸 쪽으로 살짝 오므린 자세. 싸울 때는 기존 옆모습을 쓰므로 공격·뒤집힘 자세는 필요 없다.

### 1. 애사슴벌레 (일반)

참고 이미지: 옆모습 `stag_dorcus_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. small glossy black stag beetle, short modest mandibles, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_stag_dorcus
```

### 2. 톱사슴벌레 (일반)

참고 이미지: 옆모습 `stag_saw_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. stag beetle with long curved saw-toothed mandibles, amber-brown, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_stag_saw
```

### 3. 외뿔장수풍뎅이 (일반)

참고 이미지: 옆모습 `rhino_lesser_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. small rhinoceros beetle with a single short horn, dark brown, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_rhino_lesser
```

### 4. 좀사마귀 (일반)

참고 이미지: 옆모습 `mantis_jumping_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. small slender brown praying mantis, alert pose, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_mantis_jumping
```

### 5. 톱하늘소 (일반)

참고 이미지: 옆모습 `longhorn_saw_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. brown longhorn beetle, serrated antennae, matte shell, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_longhorn_saw
```

### 6. 방아깨비 (일반)

참고 이미지: 옆모습 `grasshopper_longheaded_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. long-headed green grasshopper, pointed face, long hind legs, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_grasshopper_longheaded
```

### 7. 넓적사슴벌레 (고급)

참고 이미지: 옆모습 `stag_flat_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. broad flat wide-jawed stag beetle, glossy jet black, powerful, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_stag_flat
```

### 8. 장수풍뎅이 (고급)

참고 이미지: 옆모습 `rhino_japanese_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. classic rhinoceros beetle, Y-shaped horn, sturdy brown shell, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_rhino_japanese
```

### 9. 넓적배사마귀 (고급)

참고 이미지: 옆모습 `mantis_widebelly_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. wide-bellied bright green praying mantis, raptorial arms, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_mantis_widebelly
```

### 10. 알락하늘소 (고급)

참고 이미지: 옆모습 `longhorn_whitespot_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. black longhorn beetle with white speckles, very long antennae, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_longhorn_whitespot
```

### 11. 여치 (고급)

참고 이미지: 옆모습 `katydid_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. plump green katydid bush-cricket, long antennae, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_katydid
```

### 12. 사슴벌레(미야마) (희귀)

참고 이미지: 옆모습 `stag_miyama_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. miyama stag beetle, fuzzy golden head flanges, large arched mandibles, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_stag_miyama
```

### 13. 왕사마귀 (희귀)

참고 이미지: 옆모습 `mantis_giant_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. large imposing green praying mantis, majestic stance, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_mantis_giant
```

### 14. 참나무하늘소 (희귀)

참고 이미지: 옆모습 `longhorn_oak_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. large brown oak longhorn beetle, extra-long banded antennae, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_longhorn_oak
```

### 15. 장수꽃무지 (희귀)

참고 이미지: 옆모습 `chafer_flower_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. iridescent flower chafer beetle, metallic green-bronze shell, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_chafer_flower
```

### 16. 왕사슴벌레 (영웅)

참고 이미지: 옆모습 `stag_giant_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. giant black stag beetle, thick powerful curved mandibles, regal, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_stag_giant
```

### 17. 물장군 (영웅)

참고 이미지: 옆모습 `water_bug_giant_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. giant water bug, flat brown body, strong raptorial forelegs, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_water_bug_giant
```

### 18. 두점박이사슴벌레 (영웅)

참고 이미지: 옆모습 `stag_twospot_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. reddish-brown stag beetle with two bright spots on shell, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_stag_twospot
```

### 19. 장수하늘소 (전설)

참고 이미지: 옆모습 `longhorn_relict_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. colossal majestic relict longhorn beetle, long elegant body, heroic aura, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_longhorn_relict
```

### 20. 장수말벌 (전설)

참고 이미지: 옆모습 `hornet_giant_adult.webp`

```
Use the attached side-view image as the EXACT reference for this insect's colors, markings and horn/jaw shape. Do NOT redesign. stylized asian giant hornet, orange-yellow head, bold but not scary, dynamic, dorsal view, flat orthographic bird's-eye view with the camera pointing straight down from directly above, like a pinned entomology specimen photographed from above, no perspective, no foreshortening, no horizon, no ground plane, the body perfectly bilaterally symmetric, head at the top edge and abdomen at the bottom edge. The horn or mandibles keep the same length and proportion to the body as in the reference side view, do NOT shorten or lengthen them because of the top-down angle. Mid-air falling pose: the six legs pulled slightly in toward the body, antennae swept back, the jaws relaxed, a single insect centered, no shadow, plain flat pastel background for easy cutout, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
duel_hornet_giant
```

---

# B. 오행 경기장 — 위에서 본 모습 ×5

던지는 장면에서 쓴다(정수리 시점). 가운데가 살짝 오목하고 테두리가 분명해야 한다. 곤충은 그리지 않는다.

### 21. 나무 그루터기 (목)

```
a round shallow fighting bowl carved into the top of a huge cut tree stump, visible growth rings spiraling to the center, smooth worn wood, mossy bark rim, tiny mushrooms and clover on the rim edge, seen from directly above, strict top-down view, perfectly circular arena filling the frame, clear raised rim edge, center slightly lighter to read as a shallow dip, empty with no creatures, game battle arena background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
arena_wood
```

### 22. 화산석 절구 (화)

```
a round shallow fighting bowl carved into dark volcanic stone, glowing orange cracks and warm embers in the seams, soot-darkened rim, a few small flickering flames around the edge, seen from directly above, strict top-down view, perfectly circular arena filling the frame, clear raised rim edge, center slightly lighter to read as a shallow dip, empty with no creatures, game battle arena background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
arena_fire
```

### 23. 흙 씨름판 (토)

```
a round shallow sumo-style fighting ring of packed ochre clay, a woven straw rope circle marking the edge, fine sand swept in circles, scattered pebbles, seen from directly above, strict top-down view, perfectly circular arena filling the frame, clear raised rim edge, center slightly lighter to read as a shallow dip, empty with no creatures, game battle arena background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
arena_earth
```

### 24. 놋그릇 (금)

```
a round shallow fighting bowl made of a giant polished brass bowl, warm golden metal with soft reflections and hammered dimples, engraved ring pattern on the rim, seen from directly above, strict top-down view, perfectly circular arena filling the frame, clear raised rim edge, center slightly lighter to read as a shallow dip, empty with no creatures, game battle arena background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
arena_metal
```

### 25. 연잎 (수)

```
a round shallow fighting bowl formed by a huge floating lotus leaf, visible leaf veins radiating from the center, water droplets beading on the surface, pond water and small lotus flowers around the edge, seen from directly above, strict top-down view, perfectly circular arena filling the frame, clear raised rim edge, center slightly lighter to read as a shallow dip, empty with no creatures, game battle arena background, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
arena_water
```

---

# C. 오행 경기장 — 옆에서 본 모습 ×5

싸움 장면에서 쓴다. 곤충 옆모습이 그 위를 좌우로 오가므로 **낮은 각도에서 비스듬히** 본 납작한 타원 무대여야 한다(앞뒤 깊이가 살짝 보이게). 무대 윗면이 화면 가로의 대부분을 차지하고, 가장자리 밖은 떨어지는 곳이라 분명히 보여야 한다. 곤충은 그리지 않는다.

### 26. 나무 그루터기 (목) — 옆에서

```
a round shallow fighting bowl carved into the top of a huge cut tree stump, visible growth rings spiraling to the center, smooth worn wood, mossy bark rim, tiny mushrooms and clover on the rim edge, seen from a low side angle about 20 degrees above the surface, the round arena appearing as a wide flat ellipse filling most of the width of the frame, its top surface clearly visible as a stage, the side of the arena and its rim edge visible, soft blurred natural background behind it, empty with no creatures, game side-view battle stage background, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 16:9
```

파일명

```
arena_wood_side
```

### 27. 화산석 절구 (화) — 옆에서

```
a round shallow fighting bowl carved into dark volcanic stone, glowing orange cracks and warm embers in the seams, soot-darkened rim, a few small flickering flames around the edge, seen from a low side angle about 20 degrees above the surface, the round arena appearing as a wide flat ellipse filling most of the width of the frame, its top surface clearly visible as a stage, the side of the arena and its rim edge visible, soft blurred natural background behind it, empty with no creatures, game side-view battle stage background, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 16:9
```

파일명

```
arena_fire_side
```

### 28. 흙 씨름판 (토) — 옆에서

```
a round shallow sumo-style fighting ring of packed ochre clay, a woven straw rope circle marking the edge, fine sand swept in circles, scattered pebbles, seen from a low side angle about 20 degrees above the surface, the round arena appearing as a wide flat ellipse filling most of the width of the frame, its top surface clearly visible as a stage, the side of the arena and its rim edge visible, soft blurred natural background behind it, empty with no creatures, game side-view battle stage background, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 16:9
```

파일명

```
arena_earth_side
```

### 29. 놋그릇 (금) — 옆에서

```
a round shallow fighting bowl made of a giant polished brass bowl, warm golden metal with soft reflections and hammered dimples, engraved ring pattern on the rim, seen from a low side angle about 20 degrees above the surface, the round arena appearing as a wide flat ellipse filling most of the width of the frame, its top surface clearly visible as a stage, the side of the arena and its rim edge visible, soft blurred natural background behind it, empty with no creatures, game side-view battle stage background, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 16:9
```

파일명

```
arena_metal_side
```

### 30. 연잎 (수) — 옆에서

```
a round shallow fighting bowl formed by a huge floating lotus leaf, visible leaf veins radiating from the center, water droplets beading on the surface, pond water and small lotus flowers around the edge, seen from a low side angle about 20 degrees above the surface, the round arena appearing as a wide flat ellipse filling most of the width of the frame, its top surface clearly visible as a stage, the side of the arena and its rim edge visible, soft blurred natural background behind it, empty with no creatures, game side-view battle stage background, no text, no letters, no labels, no captions, no numbers, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 16:9
```

파일명

```
arena_water_side
```

---

# D. 캐릭터 던지기 동작 ×1 (3칸 시트)

판 시작 때 화면 아래에서 곤충을 던진다. 기존 캐릭터 그림을 참고 이미지로 붙인다:

```
C:\Users\Lenovo\Desktop\coding\BugChamp\packages\app\assets\images\character\idle.webp
```

### 31. 던지기 시트

```
Use the attached image as the EXACT reference for this character. Do NOT redesign. A cute bug-collector adventurer, back view seen from slightly behind and above, drawn as a 3-frame horizontal sprite sheet with clear even spacing, the character at the same size and position in each cell. Left: winding up, holding a small beetle in the right hand pulled back behind the head. Middle: throwing forward and upward, arm extended, the beetle just leaving the hand. Right: follow-through, arm down, leaning forward, cheering. Consistent character in all three, plain flat pastel background for easy cutout, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 3:1
```

파일명

```
duel_throw
```

---

# E. 효과 ×4

효과는 코드로도 그리지만 그림이 있으면 훨씬 보기 좋다.

### 32. 충돌 불꽃

```
a burst of bright yellow-white impact sparks and small star shapes radiating from the center, comic impact effect, single centered effect, game vfx sprite, bold shapes, strong readable silhouette, plain flat dark background for easy cutout, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
fx_clash
```

### 33. 착지 먼지

```
a soft round puff of tan dust and tiny pebbles spreading outward in a ring, landing impact cloud, single centered effect, game vfx sprite, bold shapes, strong readable silhouette, plain flat dark background for easy cutout, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
fx_dust
```

### 34. 장외

```
a dramatic swoosh trail with a big bright star twinkle at the end, knocked-out-of-the-ring effect, single centered effect, game vfx sprite, bold shapes, strong readable silhouette, plain flat dark background for easy cutout, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
fx_ringout
```

### 35. 기절

```
a small ring of three spinning yellow stars and swirl lines, dizzy knocked-out effect, single centered effect, game vfx sprite, bold shapes, strong readable silhouette, plain flat dark background for easy cutout, cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, rounded friendly forms, muted earthy forest palette (moss green, honey amber, warm bark brown, soft cream), subtle ambient occlusion, clean readable silhouette, mobile game art, crisp high detail, no text, no watermark, no signature --ar 1:1
```

파일명

```
fx_dizzy
```

