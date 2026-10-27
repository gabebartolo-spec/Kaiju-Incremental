extends SceneTree
## The titan's run (Momentum, D-337) at the game camera, for its proof clips: in a real rampage
## (the flow test's city, seed 0) the young croc, once out of the river, is set at the foot of a
## clear street and charges straight down it: --case=crash, a street whose buildings in his way
## all stand under his shoulder (he crashes through them); --case=slam, a street ending at a
## building over his shoulder (he slams into it). Prints the frame the charge starts (cut the ~6 s
## clip from there), each slam with its frame, and the momentum each half second.
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <out>.avi \
##     --script tools/capture/capture_momentum.gd -- --case=crash
## Needs a window and the no-focus override.cfg.

const Kit := preload("res://tools/capture/capture_kit.gd")
## Seconds he stands where he is set (the camera settles), then charges for CHARGE_S.
const SETTLE_S := 1.5
const CHARGE_S := 5.0
## Open street before the first building (full momentum by then), the path beyond it, and the
## half-width of the corridor his body sweeps.
const RUN_UP := 12.0
const PATH := 24.0
const HALF := 2.5
const DIRS: Array[Vector2] = [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)]

var _case := "crash"
var _dir := Vector2.ZERO
var _start := Vector2.ZERO
var _frame := 0
var _placed := -1


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_case = str(Kit.args({"case": _case})["case"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	PlayerSettings.controls_seen = true
	var stats := Kit.stats("reptilian", {}, "reptilian")
	var rampage := Kit.rampage("reptilian", stats, 1)
	if not _pick(rampage.sim):
		printerr("capture_momentum: no street fits --case=%s" % _case)
		quit(1)
		return
	rampage.scripted = _input
	root.add_child(rampage)
	await rampage.wait_loaded()
	for node: Node in rampage.get_children():
		if node is BreathAim:  # the ready breath's aim wedge is a play aid, not part of the shot
			node.set_physics_process(false)
			(node as Node3D).visible = false
	var sim := rampage.sim
	var seen := 0
	var settle := roundi(SETTLE_S * Engine.physics_ticks_per_second)
	var charge := roundi(CHARGE_S * Engine.physics_ticks_per_second)
	while not sim.over and (_placed < 0 or _frame < _placed + settle + charge):
		await physics_frame
		if _placed >= 0 and _frame == _placed + settle:
			var aim := rampage._follow.focus
			var off := Vector2(aim.x, aim.z).distance_to(sim.kaiju_pos)
			print(
				(
					"CHARGE frame %d (drawn %d) camera aim off %.2f"
					% [_frame, Engine.get_frames_drawn(), off]
				)
			)
		if _placed >= 0 and (_frame - _placed) % 30 == 0:
			print(
				"t %.1f momentum %.2f at %s" % [_frame / 60.0, sim.powers.momentum, sim.kaiju_pos]
			)
		if sim.powers.run.slams != seen:
			seen = sim.powers.run.slams
			print("SLAM %d at frame %d (drawn %d)" % [seen, _frame, Engine.get_frames_drawn()])
	print("broken %d by the body %d slams %d" % [sim.chunks_destroyed, sim.body.broken, seen])
	quit()


## Out of the river: set at the street's foot facing down it, stand, then charge.
func _input(sim: RampageSim) -> Dictionary:
	_frame += 1
	if sim.emerge.active:
		return {"move": Vector2.ZERO}
	if _placed < 0:  # the body has not stepped since the rise: it sweeps from here
		_placed = _frame
		sim.kaiju_pos = _start
		sim.facing = _dir
		sim.body.heading = _dir
	var go := _frame >= _placed + roundi(SETTLE_S * Engine.physics_ticks_per_second)
	return {"move": _dir if go else Vector2.ZERO}


## The street for the case: its foot (_start) and way (_dir), nearest where he rises (a short
## hop for the camera).
func _pick(sim: RampageSim) -> bool:
	var shoulder := _shoulder(sim)
	var front := 0.0
	var back := 0.0
	for d: Array in sim.body.discs():
		front = maxf(front, Num.f(d[0]) + Num.f(d[1]))
		back = maxf(back, Num.f(d[1]) - Num.f(d[0]))
	front *= sim.body_scale()
	back *= sim.body_scale()
	var rise := sim.kaiju_pos
	var best := INF
	for b: RampageSim.Building in sim.buildings:
		if not b.in_arena or b.landmark != "":
			continue
		for dir: Vector2 in DIRS:
			var face := Vector2(b.x, b.z) - dir * (_half_along(b, dir) + 0.01)
			var foot := face - dir * (RUN_UP + front)
			if not _fits(sim, b, face - dir * (RUN_UP + front + back), face):
				continue
			var score := foot.distance_to(rise)
			if score < best and sim.clamp_to_arena(foot) == foot:
				best = score
				_start = foot
				_dir = dir
	print("PICK %s start %s dir %s shoulder %.2f" % [_case, _start, _dir, shoulder])
	return best < INF


## Whether the street from `tail` (behind his body where he stands) to building `first`'s near
## `face` is clear, and what lies on: for a crash, at least two buildings, all under his crash
## height; for a slam, `first` over it.
func _fits(sim: RampageSim, first: RampageSim.Building, tail: Vector2, face: Vector2) -> bool:
	var top := _shoulder(sim)
	var dir := (face - tail).normalized()
	if _case == "slam" and first.height < top + 1.0:
		return false
	if _case == "crash" and first.height >= top:
		return false
	var run_up := _corridor(tail, face, dir)
	var path := _corridor(face, face + dir * PATH, dir)
	var on := 0
	for b: RampageSim.Building in sim.buildings:
		if b.frame.alive_count == 0:
			continue
		var r := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
		if r.intersects(run_up):
			return false
		if _case == "crash" and r.intersects(path):
			if b.height >= top:
				return false
			on += 1
	return _case == "slam" or on >= 2


func _corridor(from: Vector2, to: Vector2, dir: Vector2) -> Rect2:
	var side := dir.orthogonal() * HALF
	return Rect2(from - side, Vector2.ZERO).expand(from + side).expand(to - side).expand(to + side)


func _half_along(b: RampageSim.Building, dir: Vector2) -> float:
	return (b.d if dir.x == 0.0 else b.w) * 0.5


## His crash height now (Momentum.crash_height reads the titan's entry).
func _shoulder(sim: RampageSim) -> float:
	return sim.powers.run.crash_height()
