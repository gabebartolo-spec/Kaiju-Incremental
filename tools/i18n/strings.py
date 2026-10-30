#!/usr/bin/env python3
"""The game's translation table, data/i18n/strings.csv (D-392): one row per English text the player
sees, one column per language (PlayerSettings.LANGUAGES). Godot imports the CSV as translations;
the English text is the key, so a Label or Button showing a key shows it in the player's language.

A text enters the table when the code asks for it by name: tr("...") or
TranslationServer.translate("...") with a string literal, in scenes/ and autoload/ (a format
string is the key, tr("%d STOREYS") % n, never the formatted result), or when it is one of the
DATA_FIELDS of a data file.

    python tools/i18n/strings.py           # check: every text has a row, every row its English
    python tools/i18n/strings.py --update  # add new texts (languages empty), drop rows no longer used

Exit 0 when the table is complete, 1 otherwise.
"""
import csv
import glob
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TABLE = os.path.join(ROOT, "data", "i18n", "strings.csv")
LANGUAGES = ["en", "es", "fr", "it", "de", "ru", "zh_CN"]
## The languages the check requires: the demo ships in English only (D-406); the rest stay as columns.
CHECKED = ["en"]
## data file -> the keys whose string values the player reads (at any depth).
DATA_FIELDS: dict[str, list[str]] = {
    "species.json": ["name", "blurb"],
    "upgrades.json": ["name", "desc", "reptilian", "insectoid", "cephalopod"],
    "looks.json": [
        "clear", "dusk", "fog", "morning", "night", "noon", "overcast", "rain", "thunderstorm",
        "random_label",
    ],
    "tuning.json": [
        "at_large", "beam", "cancel", "close", "done", "end_keep", "end_line", "end_title",
        "end_yes", "escaped", "failed", "headline", "killed", "label", "landmark", "liftoff",
        "line", "megatower", "open_folder", "prompt", "saved", "spire", "stadium", "towers",
        "unit", "vip_escaped", "vip_killed", "vip_spawned",
    ],
}
PLACEHOLDER = re.compile(r"%[-0-9.]*[dsf%]")
CALL = re.compile(r'(?:\btr|TranslationServer\.translate)\(\s*"((?:[^"\\]|\\.)*)"')


def code_texts() -> set[str]:
    out = set()
    for path in glob.glob(os.path.join(ROOT, "scenes", "**", "*.gd"), recursive=True) + glob.glob(
        os.path.join(ROOT, "autoload", "**", "*.gd"), recursive=True
    ):
        with open(path, encoding="utf-8") as f:
            for m in CALL.finditer(f.read()):
                out.add(m.group(1).replace('\\"', '"').replace("\\n", "\n"))
    return out


def _walk(value, fields: list[str], out: set[str]) -> None:
    if isinstance(value, dict):
        for key, inner in value.items():
            if key in fields and isinstance(inner, str) and inner:
                out.add(inner)
            else:
                _walk(inner, fields, out)
    elif isinstance(value, list):
        for inner in value:
            _walk(inner, fields, out)


def data_texts() -> set[str]:
    out: set[str] = set()
    for name, fields in DATA_FIELDS.items():
        with open(os.path.join(ROOT, "data", name), encoding="utf-8") as f:
            _walk(json.load(f), fields, out)
    return out


def read_table() -> dict[str, dict[str, str]]:
    if not os.path.exists(TABLE):
        return {}
    with open(TABLE, encoding="utf-8", newline="") as f:
        return {row["keys"]: row for row in csv.DictReader(f)}


def write_table(rows: dict[str, dict[str, str]]) -> None:
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(["keys"] + LANGUAGES)
    for key in sorted(rows):
        w.writerow([key] + [rows[key].get(lang, "") for lang in LANGUAGES])
    with open(TABLE, "w", encoding="utf-8", newline="") as f:
        f.write(buf.getvalue())


def main() -> int:
    wanted = code_texts() | data_texts()
    rows = read_table()
    if "--update" in sys.argv:
        kept = {k: rows.get(k, {"en": k}) for k in wanted}
        for key, row in kept.items():
            row["en"] = key
        write_table(kept)
        print(f"strings.csv: {len(kept)} texts ({len(wanted - rows.keys())} new, {len(rows.keys() - wanted)} dropped)")
        return 0
    bad = [f"missing row: {k!r}" for k in sorted(wanted - rows.keys())]
    bad += [f"unused row: {k!r}" for k in sorted(rows.keys() - wanted)]
    for key in sorted(rows.keys() & wanted):
        for lang in CHECKED:
            if not rows[key].get(lang, "").strip():
                bad.append(f"no {lang} for {key!r}")
            elif sorted(PLACEHOLDER.findall(rows[key][lang])) != sorted(PLACEHOLDER.findall(key)):
                bad.append(f"{lang} changes the placeholders of {key!r}")
    for line in bad:
        print(f"::error::strings.csv {line}")
    if bad:
        print("Fix: python tools/i18n/strings.py --update, then fill the empty languages.")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
