extends SceneTree
## Playtest note 2: the young reptilian walks into the nearest building, turns inside it and
## walks back out, at the game camera, with its body volume on (BodyContact) or off (the old
## stomp-only contact). Same city and seed both ways, so a pair is a before/after. Saves a still
## every --every frames into --out for 2x crops. Needs a window and the no-focus override.cfg.
## --dash=N dashes on walk step N (note 4).
## --both: the walk-through (claw swipes) and then the tower topple in one clip, for one CI run.
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
## --tower: start at the south face of the nearest tall tier-2 tower and chew north into its
## base until it falls (D-091), instead of the walk-through.
var _tower := false
var _both := false
## --dash=N: press the dash on walk step N (playtest note 4); -1: never.
var _dash_at := -1


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--body="):
			_body = arg.substr(7) != "off"
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--every="):
			_every = arg.substr(8).to_int()
		elif arg == "--tower":
			_tower = true
		elif arg == "--both":
			_both = true
		elif arg.begins_with("--dash="):
			_dash_at = arg.substr(7).to_int()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if _both:
		print("clip part 1: walk-through (swipes) from frame 0")
		await _play(false)
		print("clip part 2: tower topple from physics frame %d" % Engine.get_physics_frames())
		await _play(true)
	else:
		await _play(_tower)
	quit()


## One take: the walk-through (tower false) or the tower chew, its rampage freed afterwards.
func _play(tower: bool) -> void:
	_tower = tower
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
	if _tower:
		dir = _at_tower(rampage.sim)
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
		if _tower:
			move = dir if n >= LEAD_IN else Vector2.ZERO
		return {"move": move, "dash": n == _dash_at}
	root.add_child(rampage)
	for child: Node in rampage.get_children():
		if child is BreathAim:  # the ready-breath wedge sits over the head and hides the bite
			child.queue_free()
	var events := [0, 0]  # swipes, topples, logged with their physics frame for the review
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	var frames := 0
	while frames < LEAD_IN + FORWARD + TURN + BACK and not rampage.sim.over:
		await physics_frame
		frames += 1
		if _out != "" and frames % _every == 0:
			await process_frame
			var still := root.get_texture().get_image()
			var tag := ("tower" if _tower else "walk") if _both else ("on" if _body else "off")
			still.save_png("%s/%s_%04d.png" % [_out, tag, frames])
		var swipes := rampage.sim.powers.swipe.swipes
		if swipes != events[0]:
			events[0] = swipes
			print("swipe %d at take frame %d" % [swipes, frames])
		if rampage.sim.collapse.toppled != events[1]:
			events[1] = rampage.sim.collapse.toppled
			print("topple starts at take frame %d" % frames)
	var sim := rampage.sim
	print("body broke %d chunks, %d broken in all" % [sim.body.broken, sim.chunks_destroyed])
	rampage.queue_free()
	await process_frame


## Puts the kaiju just south of the nearest tall tier-2 tower, facing it; returns the way in.
func _at_tower(sim: RampageSim) -> Vector2:
	var best := -1
	var best_d := INF
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.tier == 2 and b.landmark == "" and b.height >= 10 and mini(b.w, b.d) >= 4:
			var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
			if d < best_d:
				best = i
				best_d = d
	var t := sim.buildings[best]
	sim.kaiju_pos = Vector2(t.x, t.z + t.d * 0.5 + sim.body.length() * 0.6)
	sim.facing = Vector2(0, -1)
	sim.body.heading = sim.facing
	return sim.facing
