#!/usr/bin/env bash
# Compiles unity/Assets/Scripts against the Unity editor's assemblies without opening the editor.
# Prints "typecheck: ok" or the compile errors; exit 1 on any error. Local only (needs the Unity install).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
out="$(dotnet build "$here/typecheck/Typecheck.csproj" -nologo -v q -clp:NoSummary 2>&1)"
code=$?
errors="$(printf '%s\n' "$out" | grep -E "error (CS|MSB)" | sed -E 's/ \[[^]]*\]$//' | sort -u)"
if [ $code -ne 0 ] || [ -n "$errors" ]; then
    printf '%s\n' "${errors:-$out}"
    echo "typecheck: FAILED"
    exit 1
fi
echo "typecheck: ok"
