"""Rolls the oldest docs/DECISIONS.md entries to docs/archive/ until the log fits its cap.

The cap is the doc's own "Cap: N lines" header (what CI's doc-caps job reads). Each entry
moves unchanged to docs/archive/decisions_<YYYY-MM>.md for its own date, newest first under
that file's header. Run: python tools/roll_decisions.py (no change when it already fits).
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOG = ROOT / "docs" / "DECISIONS.md"
ARCHIVE = ROOT / "docs" / "archive"
HEADER = "# Decisions archive, {month}\n\nRolled from docs/DECISIONS.md (cap {cap}), newest first, unchanged.\n"


def main() -> int:
    lines = LOG.read_text(encoding="utf-8").splitlines(keepends=True)
    cap = int(re.search(r"^Cap: (\d+) lines", "".join(lines[:6]), re.M).group(1))
    rolled = 0
    while len(lines) > cap:
        start = max(i for i, line in enumerate(lines) if line.startswith("## "))
        entry = lines[start:]
        month = re.match(r"## (\d{4}-\d{2})", entry[0]).group(1)
        lines = lines[:start]
        while lines and not lines[-1].strip():
            lines.pop()
        _archive(month, cap, entry)
        rolled += 1
    if rolled:
        LOG.write_text("".join(lines), encoding="utf-8", newline="\n")
    print(f"rolled {rolled} entr{'y' if rolled == 1 else 'ies'}; DECISIONS.md is {len(lines)} lines")
    return 0


def _archive(month: str, cap: int, entry: list[str]) -> None:
    path = ARCHIVE / f"decisions_{month}.md"
    text = path.read_text(encoding="utf-8") if path.exists() else HEADER.format(month=month, cap=cap)
    head, sep, rest = text.partition("\n## ")
    body = "".join(entry).rstrip("\n") + "\n"
    text = head.rstrip("\n") + "\n\n" + body + ("\n## " + rest if sep else "")
    path.write_text(text, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    sys.exit(main())
