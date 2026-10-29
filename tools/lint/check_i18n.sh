#!/usr/bin/env bash
# Every text the player reads has all seven languages in data/i18n/strings.csv (D-392).
set -euo pipefail
cd "$(dirname "$0")/../.."
python tools/i18n/strings.py
python tools/fonts/subset_cjk.py --check
