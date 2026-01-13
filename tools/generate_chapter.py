#!/usr/bin/env python3
"""
Generate ONE chapter file in the strict format and immediately verify it.

Policy (recommended):
- Output: EN (KJV) only for now. KO left empty.
- One chapter at a time.
- Always run verifier right after generation.
- Source: local plain text at tools/source/kjv/{bookcode}.txt
  Format per line:  <chapter>:<verse>\t<EN text>
  Example:          4:27<TAB>Turn not to the right hand...
"""
import sys
from pathlib import Path
import subprocess
import re

BOOK_NAME_MAP = {
  "pro": "Proverbs",
}

LINE_RE = re.compile(r"^([0-9]+):([0-9]+)\t(.*)$")

def usage_exit(code: int = 0) -> None:
  print("Usage: python3 tools/generate_chapter.py <bookcode> <chapter_int>")
  print("Example: python3 tools/generate_chapter.py pro 5")
  print("Source : tools/source/kjv/<bookcode>.txt  (e.g. tools/source/kjv/pro.txt)")
  sys.exit(code)

def load_chapter_verses(bookcode: str, chapter: int) -> list[tuple[int, str]]:
  src_path = Path(f"tools/source/kjv/{bookcode}.txt")
  if not src_path.exists():
    print(f"FAIL: missing source file: {src_path}")
    sys.exit(1)

  verses: list[tuple[int, str]] = []
  for ln in src_path.read_text(encoding="utf-8").splitlines():
    m = LINE_RE.match(ln)
    if not m:
      continue
    chap = int(m.group(1))
    vno  = int(m.group(2))
    en   = m.group(3)
    if chap == chapter:
      verses.append((vno, en))

  verses.sort(key=lambda x: x[0])
  return verses

def ensure_contiguous(verses: list[tuple[int, str]]) -> None:
  if not verses:
    print("FAIL: no verses found for requested chapter in source.")
    sys.exit(1)
  nums = [v for v, _ in verses]
  if nums[0] != 1:
    print(f"FAIL: first verse is {nums[0]} (expected 1)")
    sys.exit(1)
  for i in range(1, len(nums)):
    if nums[i] != nums[i-1] + 1:
      print(f"FAIL: verse gap or disorder at {nums[i-1]} -> {nums[i]}")
      sys.exit(1)

def main() -> None:
  args = sys.argv[1:]
  if len(args) != 2 or args[0] in ("-h", "--help"):
    usage_exit(0)

  bookcode = args[0].strip()
  try:
    chapter = int(args[1])
  except ValueError:
    print("FAIL: chapter must be an integer")
    sys.exit(1)

  book_name = BOOK_NAME_MAP.get(bookcode)
  if not book_name:
    print(f"FAIL: unknown bookcode: {bookcode}")
    sys.exit(1)

  verses = load_chapter_verses(bookcode, chapter)
  ensure_contiguous(verses)

  out_path = Path(f"tools/inbox/{book_name.lower()}_{chapter:03d}.txt")

  lines: list[str] = []
  lines.append(f"#BOOK={book_name}|BOOKCODE={bookcode}|CHAPTER={chapter}|VERSION=KJV|LANGPAIR=EN-KO|ARCHAIC=INLINE_PARENS")
  lines.append(f"T|EN={book_name} {chapter}|KO=")

  for vno, en in verses:
    lines.append(f"V|N={vno}|EN={en}|KO=")

  out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
  print(f"OK: wrote {out_path} verses={len(verses)}")

  # verify immediately
  cmd = ["python3", "tools/verify_chapter.py", str(out_path)]
  r = subprocess.run(cmd, text=True)
  sys.exit(r.returncode)

if __name__ == "__main__":
  main()
