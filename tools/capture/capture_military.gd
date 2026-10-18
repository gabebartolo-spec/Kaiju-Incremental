extends SceneTree
## The army at work (D-066) at the game camera: a Behemoth croc stands in the city while tank
## columns drive in by road and deploy to firing posts round it, and a helicopter pair makes an
## attack run; at TURN_AT the kaiju turns to face the pair and they break off. Clip-only
## overrides, so it all happens inside 18 s (trimmed to a 10 s clip) and inside the frame:
## columns call in from CLIP_SPAWN (not army.spawn_radius) every 1.6 s, the pair is up from
## the start (after_chunks 0, call-in 0.8 s) and runs every 2.5 s; the kaiju cannot fall.
## Everything else is the game's own data and code. Stills along the way; pair with
## --write-movie (ci_capture.sh --movie) for the clip. The log names each time a lead turns
## back (faced: breaking off; else: at the camera's arc) and the pair's closest spacing.
## Needs a window and the no-focus override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_military.gd -- --out=<dir> [--seconds=18]

const SHOTS: Array[int] = [300, 480, 600, 720, 840, 960, 1060]
## Where columns call in from, metres from the kaiju (the game's is army.spawn_radius).
const CLIP_SPAWN := 44.0
## Where the kaiju stands: a crossing at the north end with no roof over 13 m within 40 m, so
## the pair patrols low and in the frame (the start, by the 27 m wheel, sends it up over the
## wheel and out of the game camera: the roof-clearance rule, LEAD 2026-10-18).
const CLIP_AT := Vector2(5, -70)
## When the kaiju turns to face the helicopters.
const TURN_AT := 13.0

var _out := "user://military"
var _seconds := 18.0
var _frame := 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {"claws": 1, "evolve1": 1}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 100000.0  # the clip watches the army: the kaiju must not fall mid-take
	var tier := Num.i(stats["size"])
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0)), 1
	)
	rampage.sim.kaiju_pos = CLIP_AT  # before the view is built, so it starts there
	rampage.scripted = _input
	root.add_child(rampage)
	await physics_frame
	var sim := rampage.sim
	sim.army["spawn_radius"] = CLIP_SPAWN
	sim.army["start_interval"] = 1.6
	sim.army_units._spawn_timer = 0.3
	sim.air.cfg["after_chunks"] = 0
	sim.air.cfg["max_per_chunks"] = 1
	sim.air.cfg["interval"] = 0.8
	sim.air._form["run_every"] = 2.5
	sim.chunks_destroyed = 2  # two helicopters may be up (AirWing.cap)
	var turns := {}  # lead id -> its turn last frame
	var closest := INF
	for i: int in roundi(_seconds * 60.0):
		await physics_frame
		_frame = i
		for heli: AirWing.Heli in sim.air.helis:
			if heli.wing_of >= 0:
				for lead: AirWing.Heli in sim.air.helis:
					if lead.id == heli.wing_of:
						closest = minf(closest, heli.pos.distance_to(lead.pos))
				continue
			if turns.has(heli.id) and Num.f(turns[heli.id]) != heli.turn:
				var why := "faced, breaking off" if heli.state == AirWing.BREAK else "camera arc"
				print("%.2f s: lead %d turns back (%s)" % [i / 60.0, heli.id, why])
			turns[heli.id] = heli.turn
		if SHOTS.has(i):
			var path := _out.path_join("military_%04d.png" % i)
			root.get_viewport().get_texture().get_image().save_png(path)
	print("pair closest spacing %.2f m" % closest)
	quit()


## The kaiju stands side-on to the camera, then turns to face the helicopters at TURN_AT.
func _input(sim: RampageSim) -> Dictionary:
	if _frame >= roundi(TURN_AT * 60.0) and not sim.air.helis.is_empty():
		var to := sim.air.helis[0].pos - sim.kaiju_pos
		sim.facing = to.normalized()
	else:
		sim.facing = Vector2(1, 0)
	return {"move": Vector2.ZERO}
