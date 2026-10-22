extends RefCounted
## The pause menu's report folder checks (D-145; tests/run_ui_tests.gd calls run()): the reader of a
## report folder passes a good report and fails planted bad ones, by name, and the report's text
## and folders. Seeded by design: the report's timestamp is the one clock and no check reads it.

const UiFeedback := preload("res://tests/lib/ui_feedback.gd")
const PLANT_ROOT := "user://ui_planted_reports"

var check: Callable


func _init(p_check: Callable) -> void:
	check = p_check


func run() -> void:
	_reader_flags_bad_reports()
	_report_text_and_folders()


## The reader of a report folder passes a good report and fails planted bad ones, by name.
func _reader_flags_bad_reports() -> void:
	var typed := "hello"
	var version := FeedbackReport.version()
	var head := "Version: %s\n" % version
	var facts := "\n".join(UiFeedback.FACTS.map(func(l: String) -> String: return l + " x"))
	var good := head + facts + "\n" + typed + "\n"
	var found := UiFeedback.problems(_plant("good", good, "ok"), typed)
	check.call(found.is_empty(), "the known-good planted report has no problems: %s" % [found])
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
		check.call(text.contains(str(row[1])), "planted '%s' is flagged (%s): %s" % [key, row[1], text])
	_wipe(PLANT_ROOT)


func _report_text_and_folders() -> void:
	var details := {"City": "stage 1 of 3, map seed 0"}
	var text := FeedbackReport.compose("it crashed", details, "2026-10-23T10:00:00")
	check.call(text.split("\n")[0] == "Version: " + FeedbackReport.version(), "the version is line one")
	check.call(text.contains("City: stage 1 of 3") and text.contains("it crashed"), "facts and text")
	check.call(FeedbackReport.compose("  ", details, "t").contains("(nothing)"), "an empty box says so")
	var first := FeedbackReport.write("a", details, null, "2026-10-23T10:00:01")
	var second := FeedbackReport.write("b", details, null, "2026-10-23T10:00:01")
	var both_ok: bool = first["ok"] and second["ok"]
	var apart: bool = first["path"] != second["path"]
	check.call(both_ok, "two reports in one second both save")
	check.call(apart, "...into two different folders")
	var note := FileAccess.get_file_as_string(str(first["path"]).path_join("report.txt"))
	check.call(
		note.contains("black placeholder"),
		"no renderer: the text says the picture is a placeholder"
	)
	check.call(not FeedbackReport.stamp_now().is_empty(), "the stamp is a date and time")
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
