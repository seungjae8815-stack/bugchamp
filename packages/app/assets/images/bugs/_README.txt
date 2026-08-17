곤충 이미지 (docs/pet_stage_prompts.md 로 생성).

공통 3단계(전 종 재사용):
  stage_egg.webp
  stage_larva.webp
  stage_pupa.webp

성충(종별, 측면·오른쪽 향):
  {species_id}_adult.webp   예) stag_dorcus_adult.webp, hornet_giant_adult.webp

.webp 또는 .png 넣고 앱 재실행(또는 hot restart)하면 표시됨. 없으면 등급색 원+🪲 폴백.
성충 파일이 있으면 채집함/장착/동행/관리시트에서 자동으로 쓰임.

전투 자세 프레임(종별, 선택 — 없으면 위 한 장짜리로 폴백):
  {species_id}_adult_1.webp   대기
  {species_id}_adult_2.webp   공격
  {species_id}_adult_3.webp   피격

가로 3칸 시트 한 장으로 뽑아 잘라 넣는다(프롬프트: docs/art_prompts.md §2b):
  python tool/place_bug_frames.py --from <시트가 든 폴더>
파일명은 종 id 그대로(stag_giant.png). 손으로 자르거나 split_sprite_sheet.py 를
쓰면 안 된다 — 정확히 1/3 에서 자르면 큰턱이 잘리고, 칸마다 따로 맞추면 자세가
바뀔 때 곤충이 커졌다 작아졌다 하며 위아래로 튄다.

{species_id}_adult.webp 도 같은 도구가 만든다(대기 프레임을 딱 맞게 자른 것).
