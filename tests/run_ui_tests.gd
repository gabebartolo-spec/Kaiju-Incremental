extends "res://tests/lib/runner.gd"
## UI suite: the pause menu's bug / feedback button (D-145). A real click opens the panel, real
## keys fill it, SEND writes user://reports/<timestamp>/report.txt (version line first) and
## screenshot.png, and the game stays paused with nothing leaking into the rampage. The reader
## that judges a report is shown failing first on planted bad folders.
## Seeded by design: the sim is seeded (army 0, city 0) and plays fixed steps; the report's
## timestamp is the one clock and no check reads its value.
##   godot --headless --path . --script tests/run_ui_tests.gd

const UiFeedback := preload("res://tests/lib/ui_feedback.gd")
const UiFeedbackPad := preload("res://tests/lib/ui_feedback_pad.gd")
const PLANT_ROOT := "user://ui_planted_reports"


func suite_name() -> String:
	return "Ui"


func run_checks() -> void:
	await _t("_check_reader_flags_bad_reports")
	await _t("_check_report_text_and_folders")
	await _h("UiFeedback", func() -> void: await UiFeedback.run(self, check))
	await _h("UiFeedbackPad", func() -> void: await UiFeedbackPad.run(self, check))


## The reader of a report folder passes a good report and fails planted bad ones, by name.
func _check_reader_flags_bad_reports() -> void:
	var typed := "hello"
	var version := FeedbackReport.version()
	var head := "Version: %s\n" % version
	var facts := "\n".join(UiFeedback.FACTS.map(func(l: String) -> String: return l + " x"))
	var good := head + facts + "\n" + typed + "\n"
	var found := UiFeedback.problems(_plant("good", good, "ok"), typed)
	check(found.is_empty(), "the known-good planted report has no problems: %s" % [found])
	var cases := {
		"no_report": [_plant("no_report", "", "ok", false), "report.txt is missing"],
		"no_version": [_plant("no_version", good.replace(head, ""), "ok"), "Version line"],
		"wrong_version": [_plant("wrong_version", good.replace(version, "9.9"), "ok"), "Version"],
		"no_picture": [_plant("no_picture", good, "", true), "screenshot.png is missing"],
		"junk_picture": [_plant("junk_picture", good, "junk"), "not a picture"],
		"no_typed_text": [_plant("no_typed_text", good.replace(typed, ""), "ok"), "typed text"],
		"no_facts": [_plant("no_facts", head + typed, "ok"), "no GPU: line"],
	}
	for key: String in cases:
		var row: Array = cases[key]
		var text := "\n".join(UiFeedback.problems(_path(key), typed))
		check(text.contains(str(row[1])), "planted '%s' is flagged (%s): %s" % [key, row[1], text])
	_wipe(PLANT_ROOT)


func _check_report_text_and_folders() -> void:
	var details := {"City": "stage 1 of 3, map seed 0"}
	var text := FeedbackReport.compose("it crashed", details, "2026-10-23T10:00:00")
	check(text.split("\n")[0] == "Version: " + FeedbackReport.version(), "the version is line one")
	check(text.contains("City: stage 1 of 3") and text.contains("it crashed"), "facts and text")
	check(FeedbackReport.compose("  ", details, "t").contains("(nothing)"), "an empty box says so")
	var first := FeedbackReport.write("a", details, null, "2026-10-23T10:00:01")
	var second := FeedbackReport.write("b", details, null, "2026-10-23T10:00:01")
	var both_ok: bool = first["ok"] and second["ok"]
	var apart: bool = first["path"] != second["path"]
	check(both_ok, "two reports in one second both save")
	check(apart, "...into two different folders")
	var note := FileAccess.get_file_as_string(str(first["path"]).path_join("report.txt"))
	check(
		note.contains("black placeholder"),
		"no renderer: the text says the picture is a placeholder"
	)
	check(not FeedbackReport.stamp_now().is_empty(), "the stamp is a date and time")
	_wipe("user://" + str(Content.section("feedback")["folder"]))


## A planted report folder: report.txt with `text` and screenshot.png a real picture ("ok"),
## junk bytes ("junk") or absent (""). Returns its absolute path.
func _plant(key: String, text: String, shot: String, with_text := true) -> String:
	var dir := PLANT_ROOT.path_join(key)
	DirAccess.make_dir_recursive_absolute(dir)
	if with_text:
		_store(dir.path_join("report.txt"), text)
	if shot == "ok":
		Image.create(4, 4, false, Image.FORMAT_RGB8).save_png(dir.path_join("screenshot.png"))
	elif shot == "junk":
		_store(dir.path_join("screenshot.png"), "not a png")
	return _path(key)


func _path(key: String) -> String:
	return ProjectSettings.globalize_path(PLANT_ROOT.path_join(key))


func _store(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Removes a folder and everything under it (the suite's own scratch user data).
func _wipe(dir: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
