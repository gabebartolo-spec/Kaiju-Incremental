extends SceneTree
## Stand-off gunships at the game camera (AirFlight, D-183): three helicopters hold their
## firing positions round a Behemoth that walks the city smashing buildings, then glide
## to new ones as he advances. The clip is the last --seconds of a --lead second run (the
## frame it starts at is printed, to cut from). Prints the closest any came outside a pass and
## the fastest nose turn, from the sim. Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_heli_standoff.gd -- --lead=14 --seconds=6

const Kit := preload("res://tools/capture/capture_kit.gd")
const HELIS := 3

var _lead := 14.0
var _seconds := 6.0
var _aim := Vector2(INF, INF)
var _tick := 0
var _closest := INF


func _initialize() -> void:
	var a := Kit.args({"lead": _lead, "seconds": _seconds})
	_lead = float(a["lead"])
	_seconds = float(a["seconds"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	PlayerSettings.controls_seen = true
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", Kit.STAGE_LEVELS[1]), 1)
	rampage.scripted = _input
	root.add_child(rampage)
	await rampage.wait_loaded()
	while rampage.sim.emerge.active:
		await physics_frame
	var sim := rampage.sim
	sim.time_left = 1.0e9
	sim.air.cfg["fire_interval"] = 999.0  # the shot is about the flight, not the strafing fire
	for _n: int in HELIS:
		sim.air.spawn()
	for event: Dictionary in sim.events:
		rampage._on_event(event)
	var frames := 0
	var total := int((_lead + _seconds) * 60.0)
	while frames < total:
		await physics_frame
		frames += 1
		sim.hp = sim.max_hp
		if frames == int(_lead * 60.0):
			print("clip starts at frame %d" % Engine.get_frames_drawn())
		for heli: AirWing.Heli in sim.air.helis:
			if not heli.passing:
				_closest = minf(_closest, heli.pos.distance_to(sim.kaiju_pos))
	print("closest outside a pass %.1f, passes %d" % [_closest, sim.air.flight.passes])
	quit()


## The kaiju walks to the nearest standing building, a new one every half second's aim check.
func _input(sim: RampageSim) -> Dictionary:
	if sim.emerge.active:
		return {"move": Vector2.ZERO}
	_tick += 1
	if _tick % 30 == 1 or _aim.x == INF:
		_aim = sim.nearest_standing(sim.kaiju_pos)
	var near := _aim.x < INF and sim.kaiju_pos.distance_to(_aim) > sim.stomp_radius() * 0.5
	return {"move": (_aim - sim.kaiju_pos).normalized() if near else Vector2.ZERO}
