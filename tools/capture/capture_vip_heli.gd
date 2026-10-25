extends SceneTree
## The leader's escape helicopter (VipView, D-149), the whole story: lift-off off a roof, the
## banked lap, the dash, and the kaiju's Thunder Beam bringing it down once the dash is under
## way (or, with --escape, nobody fires and it reaches the edge). The camera is the game's (its
## field of view and tilt, from above and behind) but follows the leader, raised clear of towers;
## the kaiju stays where the rampage started (its stomps held off) and only turns to face it.
## Needs a window and the no-focus override.cfg. The sim runs as in the game; the capture only
## holds the stomps off and steers the kaiju.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/vip.avi \
##     --script tools/capture/capture_vip_heli.gd -- --out=<dir> --tier=2 --run=1 [--escape]
##   --stills: PNGs at fixed seconds after lift-off instead of a clip.

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 120
## A roof near the kaiju (m): the camera follows the leader, the kaiju stays at the rampage's start.
const PAD_RANGE := [10.0, 20.0]
## The camera's place over and behind the leader (the game's tilt, a little raised).
const CAMERA_FROM_VIP := Vector3(0.0, 24.0, 30.0)
## The beam is held from this flight second (the lap closes and the dash begins about 9 s in).
const APPROACH_FROM := 5.0
const FIRE_FROM := 9.0
## A light stick push toward the leader: the kaiju turns to it and edges after it.
const TURN_ONLY := 0.4
## Seconds filmed after the leader is down (the wreck falls and crashes), and the longest clip.
const AFTER := 3.5
const LONGEST := 18.0
const STILLS := [0.4, 3.0, 6.0, 9.0]
const LEVELS := [
	{"claws": 2, "hide": 2},
	{"claws": 5, "hide": 5, "rage": 3, "evolve1": 1, "r_beam": 1},
	{"claws": 5, "hide": 5, "rage": 5, "evolve1": 1, "tail": 3, "sig_power": 3, "evolve2": 1}
]

var _out := "user://vip_heli"
var _stills := false
var _escape := false
var _rampage: Rampage
var _camera: Camera3D
var _followed := Vector3.ZERO


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
	stats["run_seconds"] = 600.0  # the clock never runs out (and never jumps) in the shot
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	_rampage = Kit.rampage("reptilian", stats, run, layout)
	_rampage.scripted = _input
	root.add_child(_rampage)
	await _rampage.wait_loaded()
	while _rampage.sim.emerge.active:
		await physics_frame
	await Kit.frames(self, SETTLE)
	var sim := _rampage.sim
	sim.vip.cfg["pad_range"] = PAD_RANGE
	sim.vip._spawn_at = 0.0
	while not sim.vip.flying():
		await physics_frame
	_camera = Camera3D.new()
	_camera.fov = _rampage.camera_fov
	root.add_child(_camera)
	_camera.current = true
	_follow()
	print("lift-off at %s, rank %s, payout %.1f" % [sim.vip.pos, sim.vip.rank, sim.vip.payout])
	if _stills:
		await _shots()
	else:
		await _clip()
	print("state %s after %.1f s, rubble %.1f" % [sim.vip.state, sim.vip.flight_t, sim.rubble])
	quit()


## The clip: until the leader is gone (down or away) plus AFTER seconds, or LONGEST.
func _clip() -> void:
	var sim := _rampage.sim
	var left := LONGEST
	while sim.vip.flying() and left > 0.0:
		await physics_frame
		left -= 1.0 / 60.0
		for event: Dictionary in sim.events:
			if str(event["type"]) == "vip_killed":
				print("killed by %s at %.1f s" % [event["by"], sim.vip.flight_t])
	await Kit.ticks(self, roundi(AFTER * 60.0))


## The kaiju turns toward the leader and, from FIRE_FROM, holds the Thunder Beam on it.
func _input(sim: RampageSim) -> Dictionary:
	_follow()
	sim._stomp_timer = 9.0  # the kaiju's own stomps never reach the low leader in the shot
	if _escape or not sim.vip.flying() or sim.vip.flight_t < APPROACH_FROM:
		return {}
	var to := sim.vip.pos - sim.kaiju_pos
	return {"move": to.normalized() * TURN_ONLY, "ultimate": sim.vip.flight_t >= FIRE_FROM}


## The camera over and behind the leader (the game's tilt), eased so it glides.
func _follow() -> void:
	if _camera == null:
		return
	var sim := _rampage.sim
	var at := Vector3(sim.vip.pos.x, sim.vip.altitude(), sim.vip.pos.y)
	if sim.vip.flying():
		_followed = _followed.lerp(at, 0.12) if _followed != Vector3.ZERO else at
	_camera.position = _followed + CAMERA_FROM_VIP
	_camera.look_at(_followed)


func _shots() -> void:
	var sim := _rampage.sim
	var last := 0.0
	for at: float in STILLS:
		await Kit.ticks(self, roundi((at - last) * 60.0))
		last = at
		var path := Kit.still(self, _out, "vip_%03d" % roundi(at * 10.0))
		print("%s state %s alt %.1f" % [path, sim.vip.state, sim.vip.altitude()])
