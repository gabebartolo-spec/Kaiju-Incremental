#!/usr/bin/env bash
# check_thread_resources.sh: no code a worker thread runs makes a render resource (debt row 3, D-295;
# the freeze of PR #254). The rules and what it reads are in tools/lint/thread_resources.py.
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
py=python
command -v python > /dev/null 2>&1 || py=python3
exec "$py" tools/lint/thread_resources.py
