extends "res://tests/lib/slots_base.gd"
## Save slots suite (director 2026-10-26, "Three slots (Recommended)"): the v4 save migrates with
## its specimen number; a v5 save gains the empty campaign (v6, D-418 to D-422) and a hand-written
## campaign save round-trips unchanged; the one save from before slots moves into slot 1 with
## nothing lost (and never when it cannot be read); the specimen goes up only when the kaiju
## dies; and the title's slot list makes, loads and deletes slots by real clicks through Main.
## Seeded by design: no rampage is played to an outcome; the lab walk uses pinned city streams.
##   godot --headless --path . --script tests/run_slots_tests.gd


func suite_name() -> String:
	return "Slots"


func run_checks() -> void:
	SaveFile.wipe()
	await _t("_check_v4_migrates")
	await _t("_check_v5_gains_campaign")
	await _t("_check_campaign_round_trip")
	await _t("_check_legacy_into_slot_1")
	await _t("_check_legacy_never_lost")
	await _t("_check_specimen")
	await _t("_check_continue_picks_slot")
	await _t("_check_new_in_empty_slot")
	await _t("_check_start_over_asks")
	await _t("_check_delete_asks")
	await _t("_check_legacy_full_slots")
	await _t("_check_legacy_once")
	await _t("_check_unreadable_slots")
	SaveFile.wipe()
	SaveFile.slot = 1


## A v4 save comes up as the current version with specimen K-01 and every other key as it was.
func _check_v4_migrates() -> void:
	var up := SaveFile.migrate(V4.duplicate(true))
	var same := true
	for key: String in V4:
		if key != "version" and up.get(key) != V4[key]:
			same = false
	check(
		Num.i(up.get("version", 0)) == SaveFile.VERSION,
		"a v4 save migrates to v%d: %s" % [SaveFile.VERSION, up.get("version")]
	)
	check(Num.i(up.get("specimen", 0)) == 1, "a migrated save is specimen K-01: %s" % [up])
	check(same, "migration keeps every v4 key unchanged: %s" % [up])
	check(SaveFile.migrate(up) == up, "migrating a current save changes nothing")


## A v5 save (before the campaign) comes up as v6 with nothing conquered, no bonuses, Threat 0
## and an empty noise log, every v5 key as it was; a new save starts the same way.
func _check_v5_gains_campaign() -> void:
	var up := SaveFile.migrate(V5.duplicate(true))
	var kept := true
	for key: String in V5:
		if key != "version" and not _same(up.get(key), V5[key]):
			kept = false
	check(
		Num.i(up.get("version", 0)) == 6 and SaveFile.VERSION == 6,
		"a v5 save migrates to v6: %s" % up.get("version")
	)
	check(
		(
			_same(up.get("conquered"), [])
			and _same(up.get("bonuses"), {})
			and _same(up.get("threat"), 0.0)
			and _same(up.get("noise_log"), [])
		),
		"a migrated v5 save has conquered nothing, Threat 0: %s" % [up]
	)
	check(kept, "migration keeps every v5 key unchanged: %s" % [up])
	check(SaveFile.migrate(up) == up, "migrating a v6 save changes nothing")
	var fresh := SaveFile.new_save("reptilian")
	var empty := true
	for key: String in SaveFile.campaign():
		if not _same(fresh.get(key), SaveFile.campaign()[key]):
			empty = false
	check(empty, "a new save starts with the empty campaign: %s" % [fresh])


## A campaign save written by hand (two conquests, a bonus each, Threat and two noise entries)
## loads from its slot as written, and saving it back and loading again changes nothing.
func _check_campaign_round_trip() -> void:
	SaveFile.wipe()
	var file := FileAccess.open(SaveFile.path(2), FileAccess.WRITE)
	file.store_string(CAMPAIGN_FILE)
	file.close()
	var want: Dictionary = JSON.parse_string(CAMPAIGN_FILE)
	var loaded := SaveFile.load_game(2)
	check(_same(loaded, want), "the hand-written campaign save loads as written: %s" % [loaded])
	var conquered: Array = loaded.get("conquered", [])
	var bonuses: Dictionary = loaded.get("bonuses", {})
	var noise: Array = loaded.get("noise_log", [])
	check(
		(
			conquered == ["ostia_minor", "carthago"]
			and str(bonuses.get("carthago", "")) == "bonus_carthago_3"
			and Num.f(loaded.get("threat", -1)) == 37.5
			and noise.size() == 2
		),
		"its conquests, bonuses, Threat and noise log read back: %s" % [loaded]
	)
	SaveFile.save_game(loaded, 2)
	var again := SaveFile.load_game(2)
	check(_same(again, want), "saved and loaded again it is unchanged: %s" % [again])
	var newer := CAMPAIGN_FILE.replace('"version": 6', '"version": 7')
	file = FileAccess.open(SaveFile.path(3), FileAccess.WRITE)
	file.store_string(newer)
	file.close()
	check(SaveFile.load_game(3).is_empty(), "the same save marked v7 is refused, never half-read")
	SaveFile.wipe()


## The pre-slots save.json moves into slot 1 (migrated), slots 2 and 3 stay empty, and the old
## file is kept as a backup with its bytes unchanged.
func _check_legacy_into_slot_1() -> void:
	SaveFile.wipe()
	_write_legacy(V4)
	var before := FileAccess.get_file_as_string(SaveFile.LEGACY_PATH)
	var loaded := SaveFile.load_game(1)
	check(
		_same(loaded, SaveFile.migrate(V4.duplicate(true))),
		"today's single save loads from slot 1, migrated, nothing lost: %s" % [loaded]
	)
	check(not SaveFile.has_save(2) and not SaveFile.has_save(3), "slots 2 and 3 stay empty")
	check(
		(
			not FileAccess.file_exists(SaveFile.LEGACY_PATH)
			and FileAccess.get_file_as_string(SaveFile.LEGACY_BACKUP) == before
		),
		"the old file is renamed to a backup, byte for byte, so it is adopted once"
	)
	var main := await _main()
	var title := _screen(main)
	var cont := GuiInput.button(title, "CONTINUE")
	check(
		cont != null and cont.text.contains("7 RAMPAGES"),
		"after the move the title continues it: %s" % (cont.text if cont else "no Continue")
	)
	await _close(main)


## A legacy save never overwrites a slot and is left alone when it cannot be read.
func _check_legacy_never_lost() -> void:
	SaveFile.wipe()
	SaveFile.save_game(SaveFile.new_save("reptilian"), 1)
	_write_legacy(V4)
	check(
		(
			Num.i(SaveFile.load_game(2).get("runs", 0)) == 7
			and Num.i(SaveFile.load_game(1).get("runs", -1)) == 0
		),
		"with slot 1 taken the old save goes to slot 2, slot 1 untouched"
	)
	SaveFile.wipe()
	_write_legacy({"version": SaveFile.VERSION + 1, "runs": 3})
	check(
		not SaveFile.has_save(1) and FileAccess.file_exists(SaveFile.LEGACY_PATH),
		"a save from a newer version stays where it is, never adopted or deleted"
	)
	SaveFile.wipe()
	var file := FileAccess.open(SaveFile.LEGACY_PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	check(
		not SaveFile.has_save(1) and FileAccess.file_exists(SaveFile.LEGACY_PATH),
		"a corrupt old save stays where it is and every slot reads empty"
	)
	SaveFile.wipe()


## K-01 on a new save; every death moves it on: killed ("defeated"), time's up (D-263) and End
## rampage (director 2026-10-26, "Yes, he dies"); felling the city does not. Survives a reload.
func _check_specimen() -> void:
	var save := SaveFile.new_save("reptilian")
	check(SaveFile.specimen_name(save) == "SPECIMEN K-01", "a new kaiju is SPECIMEN K-01")
	var moved := []
	for reason: String in ["time", "ended", "city_fallen", "defeated"]:
		moved.append(SaveFile.note_end(save, {"reason": reason}))
	check(
		moved == [true, true, false, true] and SaveFile.specimen_name(save) == "SPECIMEN K-04",
		(
			"time's up, End rampage and a kill each make the next specimen; a fallen city does not: %s, %s"
			% [moved, save["specimen"]]
		)
	)
	SaveFile.save_game(save, 3)
	check(
		SaveFile.specimen_name(SaveFile.load_game(3)) == "SPECIMEN K-04",
		"the specimen number lives in the slot (save, reload)"
	)
	SaveFile.wipe()


## Continue opens the slots: empty ones greyed and saying EMPTY, the filled one naming its
## specimen; clicking it loads that slot's tree.
func _check_continue_picks_slot() -> void:
	SaveFile.wipe()
	var save := SaveFile.new_save("reptilian")
	save["runs"] = 2
	save["rubble"] = 321
	save["specimen"] = 4
	save["demo"] = Demo.enabled()
	save.erase("seed")  # a save from before saves had a city seed
	SaveFile.save_game(save, 2)
	var main := await _main()
	var title := _screen(main) as TitleScreen
	await GuiInput.click(self, GuiInput.button(title, "CONTINUE"))
	await _frames(2)
	var one := GuiInput.button(title, "SLOT 1")
	var two := GuiInput.button(title, "SLOT 2")
	var three := GuiInput.button(title, "SLOT 3")
	check(title.slot_list() != null, "clicking CONTINUE opens the slot list")
	check(
		(
			one != null
			and one.disabled
			and one.text.ends_with("EMPTY")
			and three != null
			and three.disabled
			and three.text.ends_with("EMPTY")
		),
		"empty slots read EMPTY and cannot be continued"
	)
	check(
		two != null and not two.disabled and two.text.contains("SPECIMEN K-04"),
		"the filled slot names its specimen: %s" % (two.text if two else "missing")
	)
	await GuiInput.click(self, two)
	await _frames(3)
	var tree := _screen(main) as UpgradeScreen
	check(
		tree != null and tree.rubble == 321 and SaveFile.slot == 2,
		"clicking slot 2 continues slot 2's kaiju (rubble %s)" % (tree.rubble if tree else -1)
	)
	check(SaveFile.load_game(2).has("seed"), "a save without a city seed gets one when continued")
	await _close(main)


## With slot 2 filled, New Kaiju opens the slots; clicking empty slot 1 opens the lab and the
## new kaiju is written to slot 1, slot 2 untouched.
func _check_new_in_empty_slot() -> void:
	var main := await _main()
	var title := _screen(main) as TitleScreen
	await GuiInput.click(self, GuiInput.button(title, "NEW KAIJU"))
	await _frames(2)
	check(title.slot_list() != null, "with a slot filled, NEW KAIJU opens the slot list")
	await GuiInput.click(self, GuiInput.button(title, "SLOT 1"))
	await _frames(2)
	check(_screen(main) is KaijuCreation, "an empty slot goes straight to Kaiju Creation")
	await CreationWalk.walk(self, main)
	check(
		(
			SaveFile.has_save(1)
			and Num.i(SaveFile.load_game(1).get("specimen", 0)) == 1
			and Num.i(SaveFile.load_game(1).get("seed", -1)) == SaveFile.pinned_seed
			and Num.i(SaveFile.load_game(2).get("rubble", 0)) == 321
		),
		"the new kaiju is saved in slot 1 as K-01 with its city seed; slot 2 keeps its kaiju"
	)
	await _close(main)


## New Kaiju on a filled slot asks first; KEEP MY KAIJU keeps it; Esc goes back to the title.
func _check_start_over_asks() -> void:
	var main := await _main()
	var title := _screen(main) as TitleScreen
	await GuiInput.click(self, GuiInput.button(title, "NEW KAIJU"))
	await _frames(2)
	await GuiInput.click(self, GuiInput.button(title, "SLOT 2"))
	await _frames(2)
	check(
		GuiInput.button(title, "YES, START OVER") != null and _screen(main) == title,
		"a filled slot asks before it is replaced"
	)
	await GuiInput.click(self, GuiInput.button(title, "KEEP MY KAIJU"))
	await _frames(2)
	check(
		GuiInput.button(title, "SLOT 2") != null and SaveFile.has_save(2),
		"KEEP MY KAIJU goes back to the slots, the save kept"
	)
	await GuiInput.key(self, KEY_ESCAPE)
	await _frames(2)
	check(
		title.slot_list() == null and GuiInput.button(title, "CONTINUE") != null,
		"Esc on the slots goes back to the title's buttons"
	)
	await _close(main)


## DELETE asks first; KEEP keeps the slot; YES, DELETE empties it on disk and on screen.
func _check_delete_asks() -> void:
	var main := await _main()
	var title := _screen(main) as TitleScreen
	await GuiInput.click(self, GuiInput.button(title, "CONTINUE"))
	await _frames(2)
	await GuiInput.click(self, title.slot_list().find_child("Delete2", true, false) as Button)
	await _frames(2)
	check(
		GuiInput.button(title, "YES, DELETE") != null and SaveFile.has_save(2),
		"DELETE asks first; nothing is deleted yet"
	)
	await GuiInput.click(self, GuiInput.button(title, "KEEP MY KAIJU"))
	await _frames(2)
	check(SaveFile.has_save(2), "KEEP MY KAIJU keeps the slot")
	await GuiInput.click(self, title.slot_list().find_child("Delete2", true, false) as Button)
	await _frames(2)
	await GuiInput.click(self, GuiInput.button(title, "YES, DELETE"))
	await _frames(2)
	var two := GuiInput.button(title, "SLOT 2")
	check(
		not SaveFile.has_save(2) and two != null and two.text.ends_with("EMPTY"),
		"YES, DELETE empties slot 2 on disk and the list shows it EMPTY"
	)
	check(SaveFile.has_save(1), "deleting slot 2 leaves slot 1's kaiju")
	await _close(main)


## Three full slots and a pre-slots save: the old save stays where it is and every slot keeps its
## kaiju.
func _check_legacy_full_slots() -> void:
	SaveFile.wipe()
	for n: int in [1, 2, 3]:
		var save := SaveFile.new_save("reptilian")
		save["runs"] = n
		SaveFile.save_game(save, n)
	_write_legacy(V4)
	var runs: Array[int] = []
	for n: int in [1, 2, 3]:
		runs.append(Num.i(SaveFile.load_game(n).get("runs", -1)))
	check(
		runs == [1, 2, 3] and FileAccess.file_exists(SaveFile.LEGACY_PATH),
		"with every slot full the old save waits on disk, no slot overwritten: %s" % [runs]
	)
	SaveFile.wipe()


## A backup left from before (save.json.pre_slots exists): the old save is still adopted exactly
## once, never again into a second slot on the next look.
func _check_legacy_once() -> void:
	SaveFile.wipe()
	var stale := FileAccess.open(SaveFile.LEGACY_BACKUP, FileAccess.WRITE)
	stale.store_string("{}")
	stale.close()
	_write_legacy(V4)
	var first := SaveFile.has_save(1)
	var again := SaveFile.has_save(2)
	check(
		first and not again and not FileAccess.file_exists(SaveFile.LEGACY_PATH),
		(
			"the old save is adopted once (slot 1 %s, slot 2 %s, save.json left %s)"
			% [first, again, FileAccess.file_exists(SaveFile.LEGACY_PATH)]
		)
	)
	SaveFile.wipe()


## A slot file that cannot be read (corrupt, or from a newer version) never reads EMPTY: it says
## UNREADABLE, cannot be continued, New Kaiju asks before replacing it, and the file is kept.
func _check_unreadable_slots() -> void:
	SaveFile.wipe()
	var bad := FileAccess.open(SaveFile.path(1), FileAccess.WRITE)
	bad.store_string("{ not json")
	bad.close()
	var newer := FileAccess.open(SaveFile.path(3), FileAccess.WRITE)
	newer.store_string(JSON.stringify({"version": SaveFile.VERSION + 1, "runs": 4}))
	newer.close()
	var main := await _main()
	var title := _screen(main) as TitleScreen
	await GuiInput.click(self, GuiInput.button(title, "NEW KAIJU"))
	await _frames(2)
	check(
		title.slot_list() != null and _screen(main) == title,
		"with only unreadable slots NEW KAIJU still opens the slots, not the lab"
	)
	var one := GuiInput.button(title, "SLOT 1")
	var three := GuiInput.button(title, "SLOT 3")
	check(
		(
			one != null
			and one.text.ends_with("UNREADABLE")
			and three != null
			and three.text.ends_with("UNREADABLE")
		),
		"corrupt and newer slot files read UNREADABLE, never EMPTY"
	)
	if one != null:
		await GuiInput.click(self, one)
		await _frames(2)
	check(
		GuiInput.button(title, "YES, START OVER") != null and _screen(main) == title,
		"replacing an unreadable slot asks first"
	)
	check(
		FileAccess.get_file_as_string(SaveFile.path(1)) == "{ not json",
		"the unreadable file is kept untouched"
	)
	await _close(main)
	SaveFile.wipe()
