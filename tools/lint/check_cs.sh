#!/usr/bin/env bash
# check_cs.sh: the Unity port's C# lints (U6 C1-C3, C7), run by run_all.sh and push_gate.sh. Pure Python over the
# files and the git index: no Unity, no dotnet. C5 (Tr.T rows) runs in check_i18n.sh, C6 (tuning keys) in
# tuning_keys.py.
#   cs_determinism.py         no unseeded randomness anywhere, no clock in GameLogic/Sim (rule 2)
#   cs_complexity_ratchet.py  no new file over 400 lines, method over 40 lines or cc 12 (baseline only shrinks)
#   cs_magic_numbers.py      no new bare numbers: per-file count may only go down (rule 4, D-480)
#   cs_meta.py                every tracked asset and folder under unity/Assets has one tracked .meta
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
bad=0
for lint in cs_determinism cs_complexity_ratchet cs_magic_numbers cs_meta; do
	python "tools/lint/$lint.py" || bad=1
done
exit "$bad"
