#!/usr/bin/env python3
"""Kaiju CJK: the Simplified Chinese fallback face (D-392), Noto Sans SC (SIL OFL 1.1) cut to Black
weight and to only the characters data/i18n/strings.csv's zh_CN column and the Language button use.
Rerun after the Chinese texts change; the strings lint does not catch a character the subset lacks,
this script's --check does.

Source: https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf (not kept in
the repo; 17.8 MB). Licence: assets/fonts/OFL_noto_sans_sc.txt.

    python tools/fonts/subset_cjk.py <NotoSansSC[wght].ttf>   # writes assets/fonts/kaiju_cjk.ttf
    python tools/fonts/subset_cjk.py --check                   # every zh_CN character is in it
"""
import csv
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TABLE = os.path.join(ROOT, "data", "i18n", "strings.csv")
OUT = os.path.join(ROOT, "assets", "fonts", "kaiju_cjk.ttf")
WEIGHT = 900
## The Language button's own name for Chinese (PlayerSettings.LANGUAGES), not in the table.
EXTRA = "简体中文"


def wanted() -> set[str]:
    with open(TABLE, encoding="utf-8", newline="") as f:
        chars = {ch for row in csv.DictReader(f) for ch in row["zh_CN"]}
    return {ch for ch in chars | set(EXTRA) if ord(ch) > 0x2E7F}


def main() -> int:
    if sys.argv[1:] == ["--check"]:
        have = set(map(chr, TTFont(OUT).getBestCmap()))
        lost = sorted(wanted() - have)
        if lost:
            print(f"::error::kaiju_cjk.ttf lacks {''.join(lost)}: rerun tools/fonts/subset_cjk.py")
        return 1 if lost else 0
    font = instancer.instantiateVariableFont(TTFont(sys.argv[1]), {"wght": WEIGHT})
    opts = subset.Options()
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(ch) for ch in wanted()] + [0x3000, 0xFF0C, 0x3002, 0xFF01, 0xFF1F, 0xFF1A])
    sub.subset(font)
    font.save(OUT)
    print(f"kaiju_cjk.ttf: {len(wanted())} characters, {os.path.getsize(OUT) // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
