extends SceneTree
## Comment #34 and D-118: the young reptilian stands against a tower and dashes through it from
## point-blank, then walks into a second tall building. One ~6 s clip at the game camera.
## Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <out>.avi \
##     --script tools/capture/capture_dash_burst.gd -- --out=<dir>

const LEAD_IN := 90
const DASH_AT := 60
## Physics steps (60 Hz) after the dash before the walk starts, and the walk's length.
const GAP := 150
const WALK := 150

var _out := ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
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
	var sim := rampage.sim
	var dir := Vector2(0, 1)  # south, into the tower's north face: the camera looks that way
	var steps := [0]
	rampage.scripted = func(_s: RampageSim) -> Dictionary:
		var n: int = steps[0]
		steps[0] = n + 1
		var walking: bool = n >= LEAD_IN + DASH_AT + GAP
		return {"move": dir if walking else Vector2.ZERO, "dash": n == LEAD_IN + DASH_AT}
	root.add_child(rampage)
	for child: Node in rampage.get_children():
		if child is BreathAim:
			child.queue_free()
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	var skipped := 0
	while sim.emerge.active:  # the river rise first (D-083); trim these frames off the clip
		await physics_frame
		skipped += 1
	print("clip starts at physics frame %d" % skipped)
	var first := _tower(sim, Vector2(-1000, -1000))
	var b := sim.buildings[first]
	sim.kaiju_pos = Vector2(b.x, b.z - b.d * 0.5 - 0.4)
	sim.facing = dir
	sim.body.heading = dir
	rampage._follow.focus = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)  # the camera cuts too
	steps[0] = 0
	var total := LEAD_IN + DASH_AT + GAP + WALK
	for frames: int in total:
		await physics_frame
		if frames == LEAD_IN + DASH_AT + GAP:
			# The walk (a cut): the north face of the next tower, a body length back.
			var second := _tower(sim, sim.kaiju_pos, first)
			var t := sim.buildings[second]
			sim.kaiju_pos = Vector2(t.x, t.z - t.d * 0.5 - sim.body.length() * 0.6)
			sim.facing = dir
			sim.body.heading = dir
			rampage._follow.focus = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
			print("walk target %d at step %d" % [second, frames])
		if _out != "" and frames % 30 == 0:
			await process_frame
			root.get_texture().get_image().save_png("%s/burst_%04d.png" % [_out, frames])
	print("body broke %d chunks, longest hold %.2f s" % [sim.body.broken, sim.body.longest_hold])
	rampage.queue_free()
	await process_frame
	quit()


## The nearest standing tier-2+ tower (10+ floors, 4+ wide) to `near`, other than `skip`.
func _tower(sim: RampageSim, near: Vector2, skip: int = -1) -> int:
	var best := -1
	var best_d := INF
	var origin := sim.kaiju_pos if near.x < -900 else near
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if i == skip or b.tier < 2 or b.landmark != "" or b.height < 10 or mini(b.w, b.d) < 4:
			continue
		if not b.in_arena or b.frame.alive_count == 0:
			continue
		var d := Vector2(b.x, b.z).distance_to(origin)
		if d < best_d:
			best = i
			best_d = d
	return best
