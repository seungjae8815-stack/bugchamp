요정 그림 슬롯 (투명 배경 WebP, 오른쪽을 향해 나는 옆모습)
없으면 등급 빛 속 🧚 로 폴백한다.

파일(요정 종류 id = fairies.json → kinds[].id):
  fairy_<id>_1.webp    날갯짓(날개 위)
  fairy_<id>_2.webp    날갯짓(날개 아래) — 1 과 번갈아 파닥임
  fairy_<id>_cast.webp 스킬 시전 순간

받은 그림은 동작 시트(fairy_<id>_sheet) 한 장을 세 칸으로 잘라 만든다 — tool/import_fairy_art.py
(몸통 중심을 맞춰 같은 크기로 자른다 · 워터마크·배경 제거). 알·둥지·가속기·속성석·가루·배경·탭 아이콘도 같은 스크립트.
프롬프트: docs/art_prompts_fairy.md
