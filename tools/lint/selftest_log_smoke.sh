#!/usr/bin/env bash
# selftest_log_smoke.sh: the engine-log checker catches an error, a warning and each leak report in a
# planted log, and passes a clean one (run_all.sh runs every selftest_*.sh; no engine needed).
exec bash "$(dirname "${BASH_SOURCE[0]}")/log_smoke.sh" --selftest
