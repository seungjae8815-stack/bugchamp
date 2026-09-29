결투(곤충 배틀 스타디움) 그림 — 프롬프트: docs/art_prompts_duel.md

duel_{종id}.webp        곤충 위에서 본 모습(던져서 떨어지는 순간)
arena_{오행}.webp       경기장 위에서 본 모습(던지는 장면)   오행 = wood fire earth metal water
arena_{오행}_side.webp  경기장 옆에서 본 모습(싸움 장면)
fx_{clash,dust,ringout,dizzy}.webp  효과

싸울 때 곤충 모션은 assets/images/bugs/{종id}_adult_{1,2,3}.webp(대기·공격·피격)를 그대로 쓴다.
파일이 없으면 화면은 옆모습·원형 그라데이션·코드 효과로 대신 그린다.

넣는 법: python tool/import_duel_art.py --from "<그림 폴더>"  (누끼·워터마크·크기 자동, 같은 그림 두 이름은 건너뜀)
