extends SceneTree
## Demo build dry-run: drives the exported game's own screens (title -> NEW KAIJU -> species
## select -> rampage -> the demo end card -> title) and prints one PASS/FAIL line per check.
## See tools/release/README.md for how to run it against a built exe.

const MAIN_SCENE := "res://scenes/main.tscn"

var _main: Node
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(12)
	var title := _screen()
	var texts := _texts(title)
	_check(
		"title shows text", texts.has("KAIJU INCREMENTAL") and texts.has("NEW KAIJU"), str(texts)
	)
	_check("title font is ours (Kaiju Claw/Block)", _font_ok(title), _font_names(title))
	_press(title, "NEW KAIJU")
	await _frames(12)
	if _screen() == title:  # an existing save asks first
		_press(_screen(), "NEW KAIJU")
		await _frames(12)
	var select := _screen()
	var chooses: int = 0
	for b: Node in select.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and (b as Button).text == "CHOOSE":
			chooses += 1
	_check(
		"species select reached, croc only",
		select is SpeciesSelect and chooses == 1,
		"%s, %d CHOOSE" % [str(select), chooses]
	)
	_press(select, "CHOOSE")
	await _frames(12)
	if _screen() is UpgradeScreen:
		(_screen() as UpgradeScreen).start_pressed.emit()
		await _frames(4)
	var rampage := _screen()
	_check("rampage loads", rampage is Rampage, str(rampage))
	if rampage is Rampage:
		await (rampage as Rampage).wait_loaded()
		(rampage as Rampage).set_autoplay(true)
		await _frames(240)
		var models := rampage.find_children("*", "KaijuModel", true, false)
		_check("croc model in the rampage", not models.is_empty(), "%d KaijuModel" % models.size())
		var meshes := rampage.find_children("*", "MeshInstance3D", true, false)
		_check("city geometry present", meshes.size() > 50, "%d meshes" % meshes.size())
	await _walk_end()
	print("DEMO_SMOKE %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)


## The demo's end: a played save one evolution short (written through SaveFile, as
## tools/capture/capture_demo.gd does; no cheat hook), Continue, buy evolve1 on the tree,
## the reveal, the demo-complete card, MAIN MENU back to the title.
func _walk_end() -> void:
	_main.queue_free()
	await _frames(2)
	var save := SaveFile.new_save("reptilian")
	save["runs"] = 3
	save["rubble"] = UpgradeTree.new(Content.upgrades(), {}, "reptilian").cost("evolve1") + 20
	save["levels"] = {"claws": 2, "hide": 1, "rage": 1}
	SaveFile.save_game(save)
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(12)
	_press(_screen(), "CONTINUE")
	await _frames(12)
	var tree := _screen()
	_check("Continue lands on the tree", tree is UpgradeScreen, str(tree))
	if not tree is UpgradeScreen:
		return
	(tree as UpgradeScreen).node_button("evolve1").pressed.emit()
	var waited := 0
	while _screen() == tree and waited < 1200:
		await process_frame
		waited += 1
	await _frames(30)
	var card := _texts(_screen())
	_check(
		"demo-complete card renders",
		card.has("DEMO COMPLETE") and card.has("MAIN MENU"),
		"%s after %d frames" % [str(card), waited]
	)
	_check("card font is ours", _font_ok(_screen()), _font_names(_screen()))
	_press(_screen(), "MAIN MENU")
	await _frames(12)
	_check(
		"MAIN MENU returns to the title",
		_texts(_screen()).has("KAIJU INCREMENTAL"),
		str(_texts(_screen())).left(120)
	)
	SaveFile.delete_save()


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  [%s]" % ["PASS" if ok else "FAIL", name, detail.left(300)])


func _screen() -> Node:
	return _main.call("screen")


func _texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for n: Node in node.find_children("*", "Control", true, false):
		if n is Label and (n as Label).is_visible_in_tree():
			out.append((n as Label).text)
		elif n is Button and (n as Button).is_visible_in_tree():
			out.append((n as Button).text)
	return out


func _font_names(node: Node) -> String:
	var names := {}
	for n: Node in node.find_children("*", "Control", true, false):
		if n is Label or n is Button:
			var f := (n as Control).get_theme_font("font")
			if f != null:
				names[f.resource_path.get_file() if f.resource_path != "" else f.get_font_name()] = true
	return str(names.keys())


func _font_ok(node: Node) -> bool:
	var s := _font_names(node).to_lower()
	return s.contains("kaiju") and not s.contains("open sans")


func _press(node: Node, prefix: String) -> void:
	for found: Node in node.find_children("*", "Button", true, false):
		var b: Button = found
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			b.pressed.emit()
			return
	print("FAIL  no button %s" % prefix)
	_fails += 1


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame
