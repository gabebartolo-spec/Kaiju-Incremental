extends SceneTree
## Helicopter method B, a look test for the director (D-066, LEAD 2026-10-19): the camera pulls
## back to PULL x its distance while a helicopter pair is up and eases back when none is. The
## pair flies this branch's roof-cleared flight (rotor 4 m over the roofs), and its frame model
## (air.view zoom) pulls with the camera. The pull lives in this capture only, not in the game.
## The scene is capture_military's: a Behemoth croc at CLIP_AT, columns calling in close, the
## pair up from the start. --pull=1.0 gives today's camera at the same moments (stills only).
##
##   ci_capture.sh --movie --fps=60 --resolution=1920x1080 capture_heli_b.gd -- --pull=1.4
##     --seconds=15 --out=<dir>

const SHOTS: Array[int] = [120, 240, 360, 480, 600, 720, 840]
const CLIP_SPAWN := 44.0
const CLIP_AT := Vector2(5, -70)
## How fast the pull eases in and out (share of the way a second).
const EASE := 1.2

var _out := "user://heli_b"
var _seconds := 15.0
var _pull := 1.4


## Runs after Rampage places its camera each frame: moves the camera out along its own line of
## sight by the eased pull, round the point it looks at.
class CameraPull:
	extends Node
	var rampage: Rampage
	var target := 1.4
	var k := 1.0

	func _process(delta: float) -> void:
		var sim := rampage.sim
		var want := target if not sim.air.helis.is_empty() else 1.0
		k = lerpf(k, want, minf(1.0, delta * EASE))
		var cam := rampage._camera
		var look := rampage._focus + Vector3(0, 3.5 * sim.body_scale(), 0)
		cam.position = look + (cam.position - look) * k
		cam.look_at(look)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		if arg.begins_with("--pull="):
			_pull = arg.substr(7).to_float()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {"claws": 1, "evolve1": 1}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 100000.0
	var tier := Num.i(stats["size"])
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0)), 1
	)
	rampage.sim.kaiju_pos = CLIP_AT
	rampage.scripted = _input
	root.add_child(rampage)
	var pull := CameraPull.new()
	pull.rampage = rampage
	pull.target = _pull
	pull.process_priority = 1000  # after Rampage's own camera placement
	root.add_child(pull)
	await physics_frame
	var sim := rampage.sim
	sim.army["spawn_radius"] = CLIP_SPAWN
	sim.army["start_interval"] = 1.6
	sim.army_units._spawn_timer = 0.3
	sim.air.cfg["after_chunks"] = 0
	sim.air.cfg["max_per_chunks"] = 1
	sim.air.cfg["interval"] = 0.8
	sim.chunks_destroyed = 2  # two helicopters may be up (AirWing.cap)
	var seen := 0
	var up := 0
	var both := 0
	for i: int in roundi(_seconds * 60.0):
		await physics_frame
		if not sim.air.helis.is_empty():
			up += 1
			var n_in := 0
			for heli: AirWing.Heli in sim.air.helis:
				var p := Vector3(heli.pos.x, sim.air.altitude(), heli.pos.y)
				if rampage._camera.is_position_in_frustum(p):
					seen += 1
					n_in += 1
			if n_in >= 2:
				both += 1
		if SHOTS.has(i):
			var path := _out.path_join("heli_b_x%.1f_%04d.png" % [_pull, i])
			root.get_viewport().get_texture().get_image().save_png(path)
			print("%d: pull %.2f, helicopters up %d" % [i, pull.k, sim.air.helis.size()])
	print(
		(
			"pull x%.1f: heli-in-frustum samples %d, frames with 2 in frustum %d of %d up"
			% [_pull, seen, both, up]
		)
	)
	quit()


func _input(sim: RampageSim) -> Dictionary:
	sim.facing = Vector2(1, 0)
	return {"move": Vector2.ZERO}
