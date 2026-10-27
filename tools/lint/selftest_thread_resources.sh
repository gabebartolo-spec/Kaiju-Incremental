#!/usr/bin/env bash
# selftest_thread_resources.sh: the worker-thread lint catches every planted defect in
# tests/fixtures/lint/thread_resources (a lambda, a bound method two calls down, a Callable parameter, a
# Thread calling the RenderingServer, a main-thread-only function), passes the clean fixture, and finds the
# real tree clean.
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
py=python
command -v python > /dev/null 2>&1 || py=python3
exec "$py" tools/lint/thread_resources.py --selftest
