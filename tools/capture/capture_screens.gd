extends SceneTree
## Captures the game's screens to PNG for the look review: species select, a rampage early and
## mid-fight (autoplayed, real sim), and the evolution tree. Needs a window (no --headless);
## run with an untracked override.cfg that sets no_focus and an off-screen position.
##
##   APPDATA=<scratch> godot --path . --resolution 3840x2160 --windowed \
##     --script tools/capture/capture_screens.gd -- --out=<dir> --species=reptilian
## --looks=concrete,night: only the rampage start and mid shots, once per look (lighting A/B).

const SETTLE := 20

var _out := "user://screens"
var _species := "reptilian"
var _looks: PackedStringArray = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--looks="):
			_looks = arg.substr(8).split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not _looks.is_empty():
		for look: String in _looks:
			Content.set_look(look)
			await _look_rampage(look)
		quit()
		return
	var select := SpeciesSelect.new()
	root.add_child(select)
	await _frames(SETTLE)
	_shot("1_species_select")
	select.queue_free()

	var species := Content.species_def(_species)
	var levels := {"claws": 2, "hide": 2}
	var tree := UpgradeTree.new(Content.upgrades(), levels)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	await _frames(SETTLE)
	_shot("2_rampage_start_%s" % _species)
	await _frames(60 * 9)
	_shot("3_rampage_mid_%s" % _species)
	await _frames(60 * 12)
	_shot("4_rampage_late_%s" % _species)
	rampage.queue_free()

	var screen := UpgradeScreen.new()
	screen.setup(tree, 140, species, Content.section("kaiju"))
	root.add_child(screen)
	await _frames(SETTLE)
	_shot("5_evolution_tree")
	quit()


## The same seeded rampage under one look, at the game camera: start and mid-fight.
func _look_rampage(look: String) -> void:
	var species := Content.species_def(_species)
	var tree := UpgradeTree.new(Content.upgrades(), {"claws": 2, "hide": 2})
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	await _frames(SETTLE)
	_shot("%s_start" % look)
	await _frames(60 * 9)
	_shot("%s_mid" % look)
	rampage.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("saved ", path, " ", image.get_size())
