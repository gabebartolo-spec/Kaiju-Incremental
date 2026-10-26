extends SceneTree
## No vehicle goes see-through (D-290, director 2026-10-27: "why would any vehicle ever go see
## through?"): the governor's helicopter flies its own dash straight across the line from the game
## camera to the standing kaiju, where the old fade turned a helicopter to a screen door. The run is
## the game's own: the real camera, the real HUD, the leader's lift-off from a roof (VipHeli), then
## its dash (the sim's own _dash) started on a line that crosses the camera-to-kaiju line at the
## helicopter's cruise height, at the speed of its lap. The kaiju stands (it holds its stomps) and
## its health is topped up: the one thing set by hand besides that start. Prints
## "CLIP from frame F for N frames" (cut the movie there) and the helicopter's screen point
## and share of the kaiju's body it covers, at 4K. Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 --write-movie <dir>/vip.avi \
##     --script tools/capture/capture_vehicle_solid.gd -- --run=1 --tier=2

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 120
## Seconds before the helicopter enters the frame that the clip starts, and after it leaves that
## it ends (the pass itself is about 4 s at the lap speed).
const LEAD_S := 0.6
const TAIL_S := 0.6
## Extra metres past the frame's edge the helicopter starts and ends (it enters and leaves in view).
const MARGIN := 8.0
const LEVELS := [
	{"claws": 2, "hide": 2},
	{"claws": 5, "hide": 5, "rage": 3, "evolve1": 1},
	{"claws": 5, "hide": 5, "rage": 5, "evolve1": 1, "tail": 3, "sig_power": 3, "evolve2": 1}
]

var _out := "user://vehicle_solid"


func _initialize() -> void:
	var a := Kit.args({"out": _out, "run": 1, "tier": 2})
	_out = str(a["out"])
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
	var rampage := Kit.rampage("reptilian", stats, run, layout)
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var sim := rampage.sim
	while sim.emerge.active:
		await physics_frame
	await Kit.frames(self, SETTLE)
	for node: Node in rampage.get_children():
		if node is BreathAim:  # the ready breath's aim wedge is a play aid, not part of the shot
			node.set_physics_process(false)
			(node as Node3D).visible = false
	sim.time_left = 3600.0
	sim.vip._spawn_at = 0.0  # the leader lifts off now, from the sim's own roof pick
	var waited := 0
	while not sim.vip.flying() and waited < 600:
		await physics_frame
		waited += 1
	if not sim.vip.flying():
		printerr("no lift-off: state %s" % sim.vip.state)
		quit(1)
		return
	await Kit.frames(self, 30)
	var cam := rampage._camera
	var eye := cam.global_position
	var body: Vector3 = rampage._kaiju_at + Vector3(0.0, 3.5 * sim.body_scale(), 0.0)
	var vip := sim.vip
	var height := Num.f(vip.cfg["altitude"])
	var t := (height - eye.y) / (body.y - eye.y)
	var cross := eye.lerp(body, t)  # where the helicopter crosses the camera-to-kaiju line
	var right := Vector3(cam.global_transform.basis.x.x, 0.0, cam.global_transform.basis.x.z)
	right = right.normalized()
	var speed := (
		TAU * Num.f(vip.cfg["circle_radius"]) * sim.body_scale() / Num.f(vip.cfg["circle_seconds"])
	)
	var reach := cross.distance_to(eye) * tan(deg_to_rad(cam.fov * 0.5)) * 16.0 / 9.0
	var half := reach + MARGIN
	var start := Vector2(cross.x, cross.z) - Vector2(right.x, right.z) * half
	var finish := Vector2(cross.x, cross.z) + Vector2(right.x, right.z) * (half + speed * 3.0)
	var limit := sim.arena_half + Num.f(vip.cfg["exit_margin"])
	print(
		(
			"arena limit %.0f, start %s, finish %s, kaiju %s, speed %.1f m/s, half-width %.1f m, t %.2f"
			% [limit, start, finish, sim.kaiju_pos, speed, reach, t]
		)
	)
	vip.pos = start
	vip.heading = (finish - start).angle()
	vip.flight_t = Num.f(vip.cfg["climb_seconds"])  # at its cruise height
	vip._turned = TAU  # the lap is done: the sim flies the dash
	vip._exit = finish
	vip._dash_speed = speed
	vip.speed = speed
	var frames := roundi((2.0 * half / speed + LEAD_S + TAIL_S) * 60.0)
	print("CLIP from frame %d for %d frames" % [Engine.get_frames_drawn(), frames])
	for i: int in frames:
		await physics_frame
		sim.hp = sim.max_hp
		sim.stomp._timer = 9.0  # the kaiju stands: the shot is about the helicopter
		if i % 12 == 0:
			_log(rampage, i, sim)
	print("state %s after the pass" % vip.state)
	quit()


## Prints the helicopter's screen point (4K) and the kaiju's, every fifth of a second.
func _log(rampage: Rampage, i: int, sim: RampageSim) -> void:
	var size := Vector2(root.get_viewport().get_visible_rect().size)
	var cam := root.get_viewport().get_camera_3d()
	var at := Vector3(sim.vip.pos.x, sim.vip.altitude(), sim.vip.pos.y)
	var px := Kit.image_point(self, cam, at, size)
	var ka := Kit.image_point(
		self, cam, rampage._kaiju_at + Vector3(0.0, 3.0 * sim.body_scale(), 0.0), size
	)
	print(
		(
			"f%d vip at screen (%d,%d) kaiju (%d,%d) state %s"
			% [i, px.x, px.y, ka.x, ka.y, sim.vip.state]
		)
	)
