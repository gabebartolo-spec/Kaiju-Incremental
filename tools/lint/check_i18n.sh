#!/usr/bin/env bash
# Every text the player reads has its English (D-406; D-392 keeps all seven columns) in data/i18n/strings.csv (D-392).
set -euo pipefail
cd "$(dirname "$0")/../.."
python tools/i18n/strings.py
