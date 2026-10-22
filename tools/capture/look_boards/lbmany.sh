#!/bin/bash
# usage: lbmany.sh <jobs-file> [parallel=2] : each line = args for lbq.sh (may start with VAR=val env)
P=${2:-2}
grep -v '^#' "$1" | grep -v '^$' | xargs -P "$P" -I{} bash -c 'env {} 2>&1 | grep -E "exit|shot|Error|ERROR: Parse" ' 
