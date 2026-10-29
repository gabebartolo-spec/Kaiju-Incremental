class_name SaveFile
extends RefCounted
## Versioned saves in three slots (director 2026-10-26: "Three slots (Recommended)"). Each slot is
## one file: species, rubble bank, upgrade levels, run history, the best rampage so far (what the
## results screen compares against) and the specimen number (K-01, +1 each time the kaiju dies).
## A save from a newer version is refused, never half-loaded; an older one is migrated.
## The one save before slots (user://save.json) moves into the first empty slot, kept as a backup.
## Static so screens and tests can use it without the SaveSystem autoload (which forwards here).

## The single save from before slots (v4 and older); adopted into a slot on first use.
const LEGACY_PATH := "user://save.json"
## Where the legacy file is kept once a slot holds it: renamed, never deleted.
const LEGACY_BACKUP := "user://save.json.pre_slots"
const SLOT_PATH := "user://save_slot_%d.json"
const VERSION := 5
## The results screen's records (personal bests, D-259): each is the best single rampage, per
## stat, kept in the slot's save. A key an older save lacks starts at nothing (no migration);
## "best_combo" is recorded once the combo system reports it.
const BEST_KEYS: Array[String] = [
	"rubble",
	"best_combo",
	"destruction",
	"toppled",
	"tallest_topple",
	"landmarks",
	"civilians",
	"tanks",
	"helis",
	"agents",
]

## The rampage ends that count as the kaiju's death: killed, time's up (D-263) and End rampage
## (director 2026-10-26, "Yes, he dies"). Felling the whole city ("city_fallen") is not one.
const DEATHS: Array[String] = ["defeated", "time", "ended"]

## The slot the game is playing (1-based); main.gd sets it when a slot is picked.
static var slot := 1
## When >= 0, every fresh_seed() is this (tests/lib/runner.gd pins 0, so a new kaiju made through
## the lab plays the same cities in every test run). -1 in the game: each new save draws its own.
static var pinned_seed := -1


## How many save slots there are (data/tuning.json "save" "slots").
static func slot_count() -> int:
	return Num.i(Content.section("save")["slots"])


static func path(n: int = slot) -> String:
	return SLOT_PATH % n


static func has_save(n: int = slot) -> bool:
	adopt_legacy()
	return FileAccess.file_exists(path(n))


static func save_game(data: Dictionary, n: int = slot) -> void:
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = VERSION
	var file := FileAccess.open(path(n), FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot write %s" % path(n))
		return
	file.store_string(JSON.stringify(payload, "\t"))


static func load_game(n: int = slot) -> Dictionary:
	if not has_save(n):
		return {}
	return migrate(Content.load_json(path(n)))


static func delete_save(n: int = slot) -> void:
	if FileAccess.file_exists(path(n)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(n)))


## Every slot emptied, the legacy file and its backup too (tests start from nothing).
static func wipe() -> void:
	for n: int in range(1, slot_count() + 1):
		delete_save(n)
	for p: String in [LEGACY_PATH, LEGACY_BACKUP]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Moves the pre-slots save into the first empty slot, migrated to VERSION. The old file is
## renamed to LEGACY_BACKUP first (a stale backup is removed), and only once that worked is the slot
## written, so it is adopted exactly once; a failed write renames it back. Leaves it untouched when
## it cannot be read or no slot is empty, so nothing is ever lost.
static func adopt_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	var target := 0
	for n: int in range(1, slot_count() + 1):
		if not FileAccess.file_exists(path(n)):
			target = n
			break
	if target == 0:
		return
	var data := migrate(Content.load_json(LEGACY_PATH))
	if data.is_empty():
		return
	var from := ProjectSettings.globalize_path(LEGACY_PATH)
	var backup := ProjectSettings.globalize_path(LEGACY_BACKUP)
	if FileAccess.file_exists(LEGACY_BACKUP) and DirAccess.remove_absolute(backup) != OK:
		return
	if DirAccess.rename_absolute(from, backup) != OK:
		return
	save_game(data, target)
	if not FileAccess.file_exists(path(target)):
		DirAccess.rename_absolute(backup, from)


## The slot written most recently among those holding a save that `keep` accepts, or 0.
static func latest_slot(keep: Callable) -> int:
	var best := 0
	var best_time := -1
	for n: int in range(1, slot_count() + 1):
		if not has_save(n) or not keep.call(load_game(n)):
			continue
		var time := FileAccess.get_modified_time(path(n))
		if time > best_time:
			best = n
			best_time = time
	return best


## A fresh save for a new kaiju of `species_id`: specimen K-01. `city_seed` is the slot's own city
## seed (CitySeed, D-263 "Different per save"): main.gd draws it with fresh_seed(); 0 elsewhere.
static func new_save(species_id: String, city_seed: int = 0) -> Dictionary:
	return {
		"version": VERSION,
		"species": species_id,
		"seed": city_seed,
		"rubble": 0,
		"levels": {},
		"runs": 0,
		"best": {},
		"city_seconds": 0.0,
		"demo": false,
		"demo_done": false,
		"totals": {},
		"specimen": 1,
		"lab_card": false,
	}


## A new save's city seed: random per save, or pinned_seed when a test pins it. A save without
## one (made before saves had seeds) gets one the first time it is played (main.gd).
static func fresh_seed() -> int:
	if pinned_seed >= 0:
		return pinned_seed
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()


## The specimen's name, e.g. "SPECIMEN K-01" (the number goes up when the kaiju dies).
static func specimen_name(save: Dictionary) -> String:
	return TranslationServer.translate("SPECIMEN K-%02d") % Num.i(save.get("specimen", 1))


## After a rampage `result`: every death (DEATHS, Endless too) makes the next rise a new
## specimen, one number up, and owes the lab card (SpecimenCard) before it rises. True when the
## number moved.
static func note_end(save: Dictionary, result: Dictionary) -> bool:
	if not DEATHS.has(str(result.get("reason", ""))):
		return false
	save["specimen"] = Num.i(save.get("specimen", 1)) + 1
	save["lab_card"] = true
	return true


## True (once) when the next rise owes the lab card: the flag is cleared here. A save from before
## the flag existed owes none.
static func take_lab_card(save: Dictionary) -> bool:
	if save.get("lab_card", false) != true:
		return false
	save["lab_card"] = false
	return true


## Brings an older save up to VERSION. v1 kept only "best_destruction"; v2 keeps a "best"
## record per stat; v3 drops the nodes tuning "save" "refunds" names (D-135 cut EVOLVE: Apex
## Titan) and gives their rubble back, so no one loses a purchase; v4 adds the demo keys; v5 (save
## slots) adds the specimen number, K-01 for a kaiju that has not died yet on record.
## Unknown or newer versions are refused (empty), never guessed at.
static func migrate(data: Dictionary) -> Dictionary:
	var version: int = Num.i(data.get("version", 0))
	if version > VERSION or version < 1:
		push_warning("SaveSystem: save version %d not supported" % version)
		return {}
	var out: Dictionary = data.duplicate(true)
	if version == 1:
		out["best"] = {"destruction": Num.f(out.get("best_destruction", 0.0))}
		out.erase("best_destruction")
	if version < 3:
		_refund_cut_nodes(out)
	if not out.has("city_seconds"):
		out["city_seconds"] = 0.0  # rampage time in the adolescent city (D-160)
	if version < 4:  # v4: demo marker, thanks seen, demo rampage totals (Demo.add)
		out["demo"] = out.get("demo", false)
		out["demo_done"] = out.get("demo_done", false)
		out["totals"] = out.get("totals", {})
	if version < 5:  # v5: the specimen number lives in the slot
		out["specimen"] = Num.i(out.get("specimen", 1))
	out["version"] = VERSION
	return out


## Removes every owned node tuning "save" "refunds" lists and banks its refund per level.
static func _refund_cut_nodes(save: Dictionary) -> void:
	var refunds: Dictionary = Content.section("save")["refunds"]
	var levels: Dictionary = save.get("levels", {})
	for id: String in refunds:
		if levels.has(id):
			save["rubble"] = Num.i(save.get("rubble", 0)) + Num.i(refunds[id]) * Num.i(levels[id])
			levels.erase(id)


## The best record after a rampage `result`, keeping the higher of each stat.
static func merge_best(best: Dictionary, result: Dictionary) -> Dictionary:
	var out: Dictionary = best.duplicate()
	for key: String in BEST_KEYS:
		if result.has(key):
			out[key] = maxf(Num.f(out.get(key, 0.0)), Num.f(result[key]))
	return out
