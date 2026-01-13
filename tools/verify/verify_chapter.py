#!/usr/bin/env python3
import re
import sys
from pathlib import Path

HEADER_RE = re.compile(r'^#BOOK=([^|]+)\|BOOKCODE=([^|]+)\|CHAPTER=(\d+)\|VERSION=KJV\|LANGPAIR=EN-KO\|ARCHAIC=INLINE_PARENS$')
TITLE_RE  = re.compile(r'^T\|EN=(.+)\|KO=(.+)$')
VERSE_RE  = re.compile(r'^V\|N=(\d+)\|EN=(.+)\|KO=(.+)$')

# archaic/gloss 규칙(필요하면 확장)
REQUIRE_GLOSS = {
    "unto": "to",
}

# gloss 패턴: word(gloss)
GLOSS_RE = re.compile(r'([A-Za-z]+)\(([^()]+)\)')

# "진짜 연속 반복" 판정용: 두 gloss 사이가 공백/구두점만이면 연속 반복으로 간주
BETWEEN_ALLOWED_RE = re.compile(r'^[\s\W_]*$')

def fail(msg: str, line_no: int | None = None, line: str | None = None):
    if line_no is not None:
        sys.stderr.write(f"[FAIL] line {line_no}: {msg}\n")
    else:
        sys.stderr.write(f"[FAIL] {msg}\n")
    if line is not None:
        sys.stderr.write(f"       {line}\n")
    sys.exit(1)

def check_consecutive_duplicate_gloss(en: str) -> bool:
    """
    True면 '연속 반복 gloss' 발견.
    예) unto(to) unto(to)  / ye(you), ye(you)
    False면 정상.
    예) ye(you) nations ... ye(you) people (중간에 글자 있음)
    """
    matches = list(GLOSS_RE.finditer(en))
    for i in range(1, len(matches)):
        a1, g1 = (matches[i-1].group(1).lower(), matches[i-1].group(2).lower())
        a2, g2 = (matches[i].group(1).lower(), matches[i].group(2).lower())
        if (a1, g1) != (a2, g2):
            continue

        between = en[matches[i-1].end():matches[i].start()]
        # between에 글자가 끼면(알파벳/숫자) 연속 반복이 아님
        if BETWEEN_ALLOWED_RE.match(between):
            return True
    return False

def verify(text: str):
    # 빈 줄 제거
    lines = [ln.rstrip('\n') for ln in text.splitlines() if ln.strip() != ""]
    if len(lines) < 3:
        fail("too few lines (need header + title + verses)")

    # 1) header
    if not HEADER_RE.match(lines[0]):
        fail("invalid header format", 1, lines[0])

    # 2) title
    if not TITLE_RE.match(lines[1]):
        fail("invalid title format", 2, lines[1])

    # 3) verses
    expected_n = 1
    for idx, ln in enumerate(lines[2:], start=3):
        m = VERSE_RE.match(ln)
        if not m:
            fail("invalid verse format (must be V|N=..|EN=..|KO=..)", idx, ln)

        n = int(m.group(1))
        en = m.group(2)

        # 절 연속성
        if n != expected_n:
            fail(f"verse continuity error: expected {expected_n} but got {n}", idx, ln)
        expected_n += 1

        # archaic: unto -> unto(to) 필수
        if "unto" in en:
            if "unto(" not in en:
                fail("archaic rule: 'unto' must be glossed as unto(to)", idx, ln)
            if "unto(to)" not in en:
                fail("archaic rule: 'unto' gloss must be (to)", idx, ln)

        # 중복 gloss 규칙(최종):
        # - 같은 gloss가 문장에 여러 번 등장하는 것은 허용
        # - 다만 "연속으로 반복"되는 것만 금지
        if check_consecutive_duplicate_gloss(en):
            fail("duplicate gloss repeated consecutively in EN field", idx, ln)

    return expected_n - 1

def main():
    if len(sys.argv) != 2:
        print("Usage: verify_chapter.py <input.txt>", file=sys.stderr)
        sys.exit(2)

    p = Path(sys.argv[1])
    if not p.exists():
        fail(f"file not found: {p}")

    text = p.read_text(encoding="utf-8")
    count = verify(text)
    print(f"[OK] verses={count}")

if __name__ == "__main__":
    main()
