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
  python tool/split_sprite_sheet.py --from <시트> --name {species_id}_adult --sub bugs --frames 3
칸마다 손으로 자르면 자세가 바뀔 때 곤충이 튄다 — 반드시 이 도구를 쓸 것.
