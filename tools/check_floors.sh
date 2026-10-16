#!/usr/bin/env bash
# Guardrail B6 as a machine rule (the kickoff gate): a floor in
# tests/expected_checks.txt only goes up. Compares the file in the working tree with the
# same file at a base ref and fails, naming the suite, when a floor is lower than at the
# base or a suite's line is gone. A new suite or a raised floor passes.
#
#   tools/check_floors.sh origin/main      # what tests.yml runs on a pull request
#   tools/check_floors.sh main             # locally, against your local main
#
# Pure bash and awk. Exits 1 on any violation.
set -u
cd "$(dirname "$0")/.." || exit 1
base="${1:-origin/main}"
file="tests/expected_checks.txt"
prefix="ERROR:"
[ -n "${GITHUB_ACTIONS:-}" ] && prefix="::error file=$file::"

base_text=$(git show "$base:$file" 2> /dev/null)
if [ -z "$base_text" ]; then
	echo "$prefix cannot read $file at $base (is $base fetched?)"
	exit 1
fi
if [ ! -f "$file" ]; then
	echo "$prefix $file is missing from this branch; every suite needs a floor"
	exit 1
fi

# Input 1 is the base file, input 2 the branch file: "<suite> <floor>" lines, comments
# and blank lines skipped. f counts the files seen, so an all-comment base still works.
awk -v prefix="$prefix" -v base="$base" -v file="$file" '
	FNR == 1 { f++ }
	{ sub(/\r$/, "") }
	/^[[:space:]]*(#|$)/ { next }
	NF < 2 { next }
	f == 1 { old[$1] = $2 + 0; next }
	{ new[$1] = $2 + 0 }
	END {
		bad = 0
		for (s in old) {
			if (!(s in new)) {
				printf "%s floor removed: suite \"%s\" has floor %d on %s and no line in %s here; floors only go up (game-architecture §6)\n", prefix, s, old[s], base, file
				bad = 1
			} else if (new[s] < old[s]) {
				printf "%s floor lowered: suite \"%s\" is %d on %s, %d here; floors only go up (game-architecture §6)\n", prefix, s, old[s], base, new[s]
				bad = 1
			} else if (new[s] > old[s]) {
				printf "ok: %s raised %d -> %d\n", s, old[s], new[s]
			} else {
				printf "ok: %s %d unchanged\n", s, old[s]
			}
		}
		for (s in new) if (!(s in old)) printf "ok: %s is a new suite, floor %d\n", s, new[s]
		exit bad
	}
' <(printf '%s\n' "$base_text") "$file"
