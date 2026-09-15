"""Stop 훅 — 마지막 답변이 영어 위주면 끝내지 못하게 막고 한국어로 다시 쓰게 한다.

판단: 코드블록(```), 인라인 코드(`...`), URL, 경로처럼 원문이어도 되는 부분을 뺀 나머지에서
한글 글자와 영어 글자 수를 센다. 영어 글자가 충분히 많은데(40자 이상) 한글 비율이 30% 미만이면 막는다.
막은 뒤 다시 멈출 때(stop_hook_active)는 통과시킨다 — 무한 반복 방지.
"""
import json
import re
import sys

MIN_LATIN = 40
MIN_HANGUL_RATIO = 0.30


def last_assistant_text(transcript_path: str) -> str:
    texts = []
    try:
        with open(transcript_path, encoding="utf-8") as f:
            lines = f.readlines()
    except Exception:
        return ""
    # 뒤에서부터: 마지막 assistant 텍스트 블록을 찾는다.
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except Exception:
            continue
        if entry.get("type") != "assistant":
            continue
        content = (entry.get("message") or {}).get("content") or []
        if isinstance(content, str):
            content = [{"type": "text", "text": content}]
        block_texts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
        if any(t.strip() for t in block_texts):
            texts = block_texts
            break
    return "\n".join(texts)


def strip_allowed(text: str) -> str:
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    text = re.sub(r"`[^`\n]*`", " ", text)
    text = re.sub(r"https?://\S+", " ", text)
    text = re.sub(r"[A-Za-z]:\\\S+", " ", text)  # 윈도우 경로
    text = re.sub(r"(?:\.{0,2}/)?[\w.-]+(?:/[\w.-]+)+", " ", text)  # 슬래시 경로
    return text


def main() -> None:
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except Exception:
        return
    if data.get("stop_hook_active"):
        return
    path = data.get("transcript_path") or ""
    text = strip_allowed(last_assistant_text(path))
    hangul = len(re.findall(r"[가-힣]", text))
    latin = len(re.findall(r"[A-Za-z]", text))
    if latin < MIN_LATIN:
        return
    ratio = hangul / (hangul + latin)
    if ratio >= MIN_HANGUL_RATIO:
        return
    print(json.dumps({
        "decision": "block",
        "reason": (
            f"방금 답변이 영어 위주입니다(한글 비율 {ratio:.0%}). 사장님 규칙: 사용자에게 보이는 모든 글은 한국어. "
            "같은 내용을 한국어로 다시 써서 답하세요. 코드·명령어·경로만 원문으로 두세요."
        ),
    }))


main()
