"""Roadmap-after-merge hook (director, 2026-10-30): a session that merges a PR must update the roadmap doc
before it ends its turn.

  merged  PostToolUse on Bash: a `gh pr merge` marks the roadmap due for this session.
  updated PostToolUse on a Claude Docs update/batch: clears the mark.
  stop    Stop: while the mark stands, exit 2 blocks the stop and says what to do."""

import json
import re
import sys
import tempfile
from pathlib import Path

ROADMAP_URL = "https://claude.ai/artifact/CvbnH4ZPRZDLha74homA8Q"
MERGE = re.compile(r"(^|[;&|(]\s*|\s)gh\s+pr\s+merge\b")


def mark(event: dict) -> Path:
    session = re.sub(r"[^\w-]", "", str(event.get("session_id", "unknown"))) or "unknown"
    return Path(tempfile.gettempdir()) / "kaiju_roadmap_due" / session


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return 0
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    flag = mark(event)
    if mode == "merged":
        command = str(event.get("tool_input", {}).get("command", ""))
        if MERGE.search(command):
            flag.parent.mkdir(parents=True, exist_ok=True)
            with flag.open("a", encoding="utf-8") as out:
                out.write(command.strip() + "\n")
    elif mode == "updated":
        flag.unlink(missing_ok=True)
    elif mode == "stop" and flag.exists():
        merges = flag.read_text(encoding="utf-8").strip()
        sys.stderr.write(
            "Roadmap due: this session merged a PR and has not updated the roadmap doc since.\n"
            f"Merges: {merges}\nUpdate {ROADMAP_URL} (where things stand, the milestone rows the PR moved) "
            "with the Claude Docs update/batch tool, then end the turn.\n"
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
