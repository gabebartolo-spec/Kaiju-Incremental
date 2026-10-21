extends SceneTree
## A tower toppled onto the kaiju, then the kaiju walking and stomping through what it left
## (D-110, comments #24 #25), at game speed for the before/after motion review: the real city
## (stage 1, seed 0), the young reptilian standing across the strip west of the tallest tower with
## room to fall; its west base is cut so it topples west onto him (D-099). After it is down he
## walks west along the strip through the slabs, then turns north. A fixed camera at the game
## camera's angle frames the whole strip. Prints the falls and slab breaks as they happen.
## --ground: a 6 s clip at the game camera: the same tower topples west onto the open street
## (cleared its whole length) while the kaiju stands still south of its strip, side on, the game
## camera (from the south) looking past him at the whole fall (comments
## #26 #30: it breaks band by band against the ground, base first, into slabs on top of it).
## Needs a window and the no-focus override.cfg. With --write-movie the run is the clip.
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 \
##     --write-movie <dir>/clip.avi --script tools/capture/capture_rubble.gd -- [--out=<dir>] \
##     [--ground]

const HUGE := 1.0e9
## Frames: the cut, the walk west, the turn north, the end.
const CUT_AT := 60
const WALK_AT := 330
const TURN_AT := 570
const FRAMES := 780
## The kaiju's centre this far west of the tower's west face; the strip it must leave clear.
const STAND_OFF := 7.5
const CLEAR := 18.0
## --ground: the kaiju stands this far south of the tower's south face and GROUND_ALONG west of
## its west face; the strip west is cleared GROUND_CLEAR; the clip's length.
const GROUND_OFF := 9.0
const GROUND_ALONG := 10.0
const GROUND_CLEAR := 32.0
const GROUND_FRAMES := 360
## The camera: from the south and above, looking at the strip's middle.
const EYE := Vector3(-2.0, 15.0, 27.0)

var _out := "user://rubble"
var _sim: RampageSim
var _rampage: Rampage
var _index := -1
var _move := Vector2.ZERO
var _ground := false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--ground":
			_ground = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := _clear(CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0)))
	var rampage := Rampage.new()
	_rampage = rampage
	rampage.setup(species, stats, layout, 0)
	_sim = rampage.sim
	_sim.emerge.active = false
	_sim.stand_y = 0.0
	var b := _sim.buildings[_index]
	var west := b.x - b.w * 0.5
	_sim.kaiju_pos = Vector2(west - STAND_OFF, b.z)
	_sim.facing = Vector2(0, -1)
	if _ground:  # south of the strip, side on, clear of the fall
		_sim.kaiju_pos = Vector2(west - GROUND_ALONG, b.z + b.d * 0.5 + GROUND_OFF)
		_sim.facing = Vector2(-1, 0)
	_sim.body.heading = _sim.facing
	print("tower %d at (%.1f, %.1f) %dx%d, %d floors" % [_index, b.x, b.z, b.w, b.d, b.height])
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": _move}
	root.add_child(rampage)
	while not rampage.is_loaded:
		await process_frame
	if not _ground:
		var camera := Camera3D.new()
		camera.fov = 50.0
		rampage.add_child(camera)
		var middle := Vector3(west - STAND_OFF, 0.0, b.z)
		camera.position = middle + EYE
		camera.look_at(middle + Vector3(0, 2.0, 0))
		camera.make_current()
	for i: int in GROUND_FRAMES if _ground else FRAMES:
		await physics_frame
		if i == CUT_AT:
			_cut()
		elif i == WALK_AT and not _ground:
			_move = Vector2(-1, 0)
		elif i == TURN_AT and not _ground:
			_move = Vector2(0, -1)
		for event: Dictionary in _sim.events:
			_log(i, event)
		if i % 60 == 0:
			_shot("f%04d" % i)
	print("loop end tick %d" % Time.get_ticks_msec())
	if DisplayServer.get_name() == "headless":  # frames run faster than workers: wait real time
		for _k: int in 300:
			await process_frame
			OS.delay_msec(10)
	print("slab build delays ms: %s" % [rampage._city._topple._rubble.delays_ms])
	quit()


## The layout with its tallest ordinary tower first (index 0) and nothing standing in the strip
## west of it where it falls and the kaiju stands (the street is cleared for the shot).
func _clear(layout: Array[Dictionary]) -> Array[Dictionary]:
	var best := -1
	for i: int in layout.size():
		var e := layout[i]
		if str(e.get("landmark", "")) != "" or Num.i(e["w"]) < 3:
			continue
		if absf(Num.f(e["x"])) > 30.0 or absf(Num.f(e["z"])) > 30.0:
			continue  # well inside the arena
		if best < 0 or Num.i(e["h"]) > Num.i(layout[best]["h"]):
			best = i
	var t := layout[best]
	var west := Num.f(t["x"]) - Num.i(t["w"]) * 0.5
	var clear := GROUND_CLEAR if _ground else CLEAR
	var strip := Rect2(
		west - clear, Num.f(t["z"]) - Num.i(t["d"]) * 0.5 - 6.0, clear, Num.i(t["d"]) + 12.0
	)
	# and nothing between the kaiju and the camera (south of him), so the fall reads side on
	var stand := west - STAND_OFF
	var view := Rect2(stand - 14.0, Num.f(t["z"]), 28.0, 34.0)
	if _ground:  # where he stands and the game camera's line to the strip, south of it
		view = Rect2(west - GROUND_ALONG - 18.0, Num.f(t["z"]), 36.0, 44.0)
	var out: Array[Dictionary] = [t]
	for i: int in layout.size():
		var e := layout[i]
		var w := Num.i(e["w"])
		var d := Num.i(e["d"])
		var foot := Rect2(Num.f(e["x"]) - w * 0.5, Num.f(e["z"]) - d * 0.5, w, d)
		if i != best and not strip.intersects(foot) and not view.intersects(foot):
			out.append(e)
	_index = 0
	return out


## Cuts the tower's base but its east column, so it topples west. The cut is made between sim
## steps, so its events go to the view here (the next step starts a fresh event list).
func _cut() -> void:
	var b := _sim.buildings[_index]
	var base: Array[Vector3i] = []
	for x: int in b.w - 1:
		for z: int in b.d:
			base.append(Vector3i(x, 0, z))
	var first := _sim.events.size()
	_sim.damage_chunks(_index, base, HUGE)
	for k: int in range(first, _sim.events.size()):
		_rampage._on_event(_sim.events[k])


func _log(frame: int, event: Dictionary) -> void:
	match str(event["type"]):
		"fall_start":
			print("%d fall_start %s %s" % [frame, event["kind"], event["building"]])
		"fall_land":
			var hit: Dictionary = event.get("hit", {})
			var slabs: Array = event.get("slabs", [])
			print(
				(
					"%d (tick %d) fall_land %s %s scrap %s hit %s slabs %d"
					% [
						frame,
						Time.get_ticks_msec(),
						event["kind"],
						event["building"],
						event.get("scrap", false),
						hit.keys(),
						slabs.size()
					]
				)
			)
		"slab_break":
			var pieces: Array = event["pieces"]
			print(
				(
					"%d slab_break %s by %s pieces %d"
					% [frame, event["id"], event["by"], pieces.size()]
				)
			)


func _shot(shot_name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(shot_name + ".png"))
