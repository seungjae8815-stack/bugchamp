"""UserPromptSubmit 훅 — 매 턴 '사용자에게 보이는 글은 한국어' 규칙을 모델 문맥에 넣는다.

왜: CLAUDE.md·메모리는 대화를 시작할 때 한 번만 읽혀서, 도구를 많이 쓰는 긴 작업 뒤에는
영어로 새는 일이 반복됐다(2026-09-15 사장님 여러 번 지적). 매 턴 새로 넣으면 멀어지지 않는다.
"""
import json
import sys

try:
    sys.stdin.read()  # 입력은 쓰지 않지만 파이프를 비워 둔다
except Exception:
    pass

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": (
            "[필수 규칙] 사용자에게 보이는 모든 글(최종 답변, 도구 호출 사이의 짧은 진행 안내 한 줄까지)은 "
            "반드시 한국어로 쓴다. 코드 식별자·명령어·파일 경로만 원문 그대로 둔다. "
            "영어로 쓰면 Stop 훅이 답변을 되돌린다."
        ),
    }
}))
