"""PreToolUse hook: runs tools/lint/push_gate.sh before any Bash `git push`; exit 2 blocks the push and
hands the gate's output to the session. Anything that is not a push passes untouched."""

import json
import re
import subprocess
import sys
from pathlib import Path

PUSH = re.compile(r"(^|[;&|(]\s*|\s)git\s+(-C\s+\S+\s+)?push\b")


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return 0
    command = str(event.get("tool_input", {}).get("command", ""))
    if not PUSH.search(command):
        return 0
    root = Path(__file__).resolve().parents[2]
    gate = subprocess.run(
        ["bash", "tools/lint/push_gate.sh"], cwd=root, capture_output=True, text=True, check=False
    )
    if gate.returncode == 0:
        return 0
    sys.stderr.write(
        "Push blocked: these checks fail in CI. Fix them, commit, push again.\n" + gate.stdout + gate.stderr
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
