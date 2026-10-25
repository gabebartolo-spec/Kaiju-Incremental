extends SceneTree
## The leader's escape helicopter at the game camera (VipView, D-149): lift-off off a roof, the
## banked lap with the headline on the news strip, then the kaiju's breath brings it down. The
## breath fires on its own the moment the leader is in the cone (as a player would), so the shot
## is what the sim does. Clip: --write-movie for the ~6 s of the flight and the kill. Stills
## (--stills) at fixed seconds after lift-off instead. Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/vip.avi \
##     --script tools/capture/capture_vip_heli.gd -- --out=<dir> --tier=2 --run=1 [--stills]
##   --escape: nobody fires; it runs for the edge (the escape headline).

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 120
## Seconds of flight the shot lasts, and the stills' moments (seconds after lift-off).
const CLIP_SECONDS := 6.5
const STILLS := [0.4, 1.5, 3.0, 4.5]
const LEVELS := [
	{"claws": 2, "hide": 2},
	{"claws": 5, "hide": 5, "rage": 3, "evolve1": 1},
	{"claws": 5, "hide": 5, "rage": 5, "evolve1": 1, "tail": 3, "sig_power": 3, "evolve2": 1}
]

var _out := "user://vip_heli"
var _stills := false
var _escape := false
var _rampage: Rampage
var _fire := false


func _initialize() -> void:
	var a := Kit.args({"out": _out, "run": 1, "tier": 2, "stills": false, "escape": false})
	_out = str(a["out"])
	_stills = a["stills"] == true
	_escape = a["escape"] == true
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(Num.i(a["run"]), Num.i(a["tier"]))


func _run(run: int, tier: int) -> void:
	await process_frame
	PlayerSettings.controls_seen = true  # no first-run controls card over the shot
	var levels: Dictionary = LEVELS[tier - 1]
	var stats := Kit.stats("reptilian", levels)
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	_rampage = Kit.rampage("reptilian", stats, run, layout)
	_rampage.scripted = _input
	root.add_child(_rampage)
	await _rampage.wait_loaded()
	while _rampage.sim.emerge.active:
		await physics_frame
	await Kit.frames(self, SETTLE)
	var sim := _rampage.sim
	sim.time_left = 600.0
	sim.vip._spawn_at = 0.0
	while not sim.vip.flying():
		await physics_frame
	var pad := sim.vip.pos
	print(
		(
			"lift-off at %s, kaiju at %s, rank %s, payout %.1f"
			% [pad, sim.kaiju_pos, sim.vip.rank, sim.vip.payout]
		)
	)
	_fire = not _escape
	if _stills:
		await _shots()
	else:
		await Kit.ticks(self, roundi(CLIP_SECONDS * 60.0))
	print("state %s after %.1f s, rubble %.1f" % [sim.vip.state, sim.vip.flight_t, sim.rubble])
	quit()


## The kaiju turns toward the leader and breathes when it is in the cone.
func _input(sim: RampageSim) -> Dictionary:
	if not _fire or not sim.vip.flying():
		return {}
	var to := sim.vip.pos - sim.kaiju_pos
	var aim := BreathCone.of(sim)
	var in_cone := (
		absf(sim.facing.angle_to(to)) < Num.f(aim["half_angle"])
		and to.length() < sim.ability_reach()
	)
	return {"move": to.normalized() * 0.3, "signature": in_cone and sim.ability_ready_in <= 0.0}


func _shots() -> void:
	var sim := _rampage.sim
	var last := 0.0
	for at: float in STILLS:
		await Kit.ticks(self, roundi((at - last) * 60.0))
		last = at
		var path := Kit.still(self, _out, "vip_%03d" % roundi(at * 10.0))
		print("%s state %s alt %.1f" % [path, sim.vip.state, sim.vip.altitude()])
