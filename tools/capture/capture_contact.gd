extends SceneTree
## Playtest note 2: the young reptilian walks into the nearest building, turns inside it and
## walks back out, at the game camera, with its body volume on (BodyContact) or off (the old
## stomp-only contact). Same city and seed both ways, so a pair is a before/after. Saves a still
## every --every frames into --out for 2x crops; --dash=N dashes on walk step N (note 4).
## Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <out>.avi \
##     --script tools/capture/capture_contact.gd -- --body=off --out=<dir>

## The walk, in physics steps at 60 Hz: forward into the building, a hard turn, back out.
const FORWARD := 480
const TURN := 60
const BACK := 180
const LEAD_IN := 20

var _body := true
var _out := ""
var _every := 30
## --dash=N: press the dash on walk step N (playtest note 4); -1: never.
var _dash_at := -1


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--body="):
			_body = arg.substr(7) != "off"
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--every="):
			_every = arg.substr(8).to_int()
		elif arg.begins_with("--dash="):
			_dash_at = arg.substr(7).to_int()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	if not _body:
		rampage.sim.body.use_species("")  # no volume: the stomp-only contact the demo shipped
	var target := rampage.sim.nearest_standing(rampage.sim.kaiju_pos)
	var dir := (target - rampage.sim.kaiju_pos).normalized()
	var steps := [0]
	rampage.scripted = func(_sim: RampageSim) -> Dictionary:
		var n: int = steps[0]
		steps[0] = n + 1
		var move := Vector2.ZERO
		if n >= LEAD_IN + FORWARD + TURN:
			move = -dir
		elif n >= LEAD_IN + FORWARD:
			move = dir.orthogonal()
		elif n >= LEAD_IN:
			move = dir
		return {"move": move, "dash": n == _dash_at}
	root.add_child(rampage)
	var layer := CanvasLayer.new()
	layer.layer = 10
	var text := UiKit.label(
		(
			("DASH (Shift)" if _dash_at >= 0 else "BODY VOLUME ON (sweep)")
			if _body
			else "BODY VOLUME OFF (demo exe)"
		),
		UiKit.SIZE_HEAD
	)
	text.position = Vector2(40, 160)
	layer.add_child(text)
	root.add_child(layer)
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	var frames := 0
	while frames < LEAD_IN + FORWARD + TURN + BACK and not rampage.sim.over:
		await physics_frame
		frames += 1
		if _out != "" and frames % _every == 0:
			await process_frame
			var still := root.get_texture().get_image()
			still.save_png("%s/%s_%04d.png" % [_out, "on" if _body else "off", frames])
	var sim := rampage.sim
	print("body broke %d chunks, %d broken in all" % [sim.body.broken, sim.chunks_destroyed])
	quit()
