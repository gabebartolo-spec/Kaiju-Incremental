extends SceneTree
## The Lightning Breath on a building: a reptilian walks to the nearest tall building and breathes
## once; stills from two cameras behind it (right, left), counted from the strike.
## Needs a window (no --headless) and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_breath.gd -- --out=<dir> --run=1
## --time: the time of day (default dusk, D-359).
## --shots=a,b: frames after the strike to still (default 3,8,16).
## --audit=1: no stills; checks frame by frame that the bolt never draws through a chunk the sim
## left standing (AUDIT line: in_standing_chunks must be 0) and times the cut (cut_ms).

const Kit := preload("res://tools/capture/capture_kit.gd")
## The adolescent body with the breath upgraded (as the VFX sheet).
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1, "sig_power": 2}
const SETTLE := 60
## The target: the nearest building of at least this many floors; the kaiju stops this share of
## the breath's reach short of its middle, facing it.
const MIN_FLOORS := 6
const STAND_OFF := 0.85
## Caps in physics frames: the walk to the building and the press-to-strike wait.
const WALK_MAX := 600
const STRIKE_MAX := 180
## The audit: sample each drawn line every TOUCH_STEP; stop after AUDIT_MAX frames.
const TOUCH_STEP := 0.25
const AUDIT_MAX := 240
## The breath's cameras, body-scale units from the kaiju's feet as (right, ahead, up): behind it on
## the open ground it came from, so only the target stands between them and the column.
const VIEWS := {"right": Vector3(16.0, -14.0, 12.0), "left": Vector3(-16.0, -14.0, 12.0)}

var _out := "user://breath"
var _rampage: Rampage
var _input: Dictionary = {}
var _time := "dusk"
var _shots: Array = [3, 8, 16]
var _audit := false


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"out": _out, "run": 1, "shots": "", "time": "dusk", "audit": 0})
	_out = str(a["out"])
	if str(a["shots"]) != "":
		_shots = []
		for text: String in str(a["shots"]).split(","):
			_shots.append(text.to_int())
	_time = str(a["time"])
	_audit = Num.i(a["audit"]) == 1
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(Num.i(a["run"]))


func _run(run: int) -> void:
	await process_frame
	_rampage = Kit.rampage("reptilian", Kit.stats("reptilian", LEVELS), run)
	_rampage.scripted = func(_sim: RampageSim) -> Dictionary: return _input
	Content.set_time(_time)  # dusk by default (D-359)
	root.add_child(_rampage)
	await _rampage.wait_loaded()
	while _rampage.sim.emerge.active:
		await physics_frame
	await Kit.frames(self, SETTLE)
	var sim := _rampage.sim
	var target := _target(sim)
	var walked := 0
	while target.distance_to(sim.kaiju_pos) > sim.ability_reach() * STAND_OFF and walked < WALK_MAX:
		_input = {"move": (target - sim.kaiju_pos).normalized()}
		await physics_frame
		walked += 1
	sim.facing = (target - sim.kaiju_pos).normalized()
	_input = {}
	sim.breath_ready_in = 0.0
	await Kit.frames(self, 20)
	var before: Array = []
	for b: RampageSim.Building in sim.buildings:
		before.append(_floors(b.frame))
	_input = {"breath": true}
	await physics_frame
	await physics_frame
	_input = {}
	var waited_strike := 0
	while not _rampage.ability_fx.played.has("breath") and waited_strike < STRIKE_MAX:
		await physics_frame
		waited_strike += 1
	await physics_frame
	_report(sim, before)
	if _audit:
		await _touch_audit(sim, before)
		quit()
		return
	var waited := 0
	for n: int in _shots:
		await Kit.frames(self, n - waited)
		waited = n
		for view: String in VIEWS:
			await _view_still(view, "breath_%s_%02d" % [view, n])
	print(
		(
			"BREATH played=%s at=%s target=%s walked=%d"
			% [_rampage.ability_fx.played, sim.kaiju_pos, target, walked]
		)
	)
	quit()


## The middle of the nearest building of MIN_FLOORS or more.
func _target(sim: RampageSim) -> Vector2:
	var best := sim.kaiju_pos + sim.facing
	var best_d := INF
	for b: RampageSim.Building in sim.buildings:
		if b.is_span() or b.height < MIN_FLOORS:
			continue
		var at := Vector2(b.x + b.w * 0.5, b.z + b.d * 0.5)
		var d := at.distance_to(sim.kaiju_pos)
		if d < best_d:
			best_d = d
			best = at
	return best


func _view_still(view: String, shot_name: String) -> void:
	var game_cam := root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = CameraTuning.fov()
	cam.far = 4000.0
	_rampage.add_child(cam)
	var sim := _rampage.sim
	var bs := sim.body_scale()
	var feet := Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	var ahead := Vector3(sim.facing.x, 0.0, sim.facing.y)
	var right := Vector3(-ahead.z, 0.0, ahead.x)
	var middle := feet + ahead * sim.ability_reach() * 0.5 + Vector3.UP * 3.0 * bs
	var off: Vector3 = VIEWS[view]
	cam.position = feet + (right * off.x + ahead * off.y + Vector3.UP * off.z) * bs
	cam.look_at(middle)
	cam.current = true
	await process_frame
	Kit.still(self, _out, shot_name)
	game_cam.current = true
	cam.queue_free()


## Standing chunks per floor of `f`.
func _floors(f: Structure) -> Array[int]:
	var out: Array[int] = []
	for y: int in f.h:
		var n := 0
		for x: int in f.w:
			for z: int in f.d:
				n += 1 if f.alive(Vector3i(x, y, z)) else 0
		out.append(n)
	return out


## Every building the strike broke: its height, the floors it lost chunks on, and the chunks left
## standing on each floor, against how high the sim's blow reaches (reach_height).
func _report(sim: RampageSim, before: Array) -> void:
	print("DAMAGE reach_height=%.1f damage=%.1f" % [sim.reach_height(), sim.stat("ability_damage")])
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var was: Array[int] = before[i]
		var now := _floors(b.frame)
		var hit: Array[int] = []
		for y: int in was.size():
			if now[y] < was[y]:
				hit.append(y)
		if not hit.is_empty():
			print("DAMAGE b%d floors=%d hit=%s was=%s now=%s" % [i, b.height, hit, was, now])


## Frame by frame while the bolt is live: every point of every drawn line (main, branches,
## strands, pool, chains; sampled every TOUCH_STEP) that lies inside a building's footprint and
## floors. Counts points in chunks still standing (the bolt drawn through something the sim did
## not break) and lists each building the bolt reached against whether the strike damaged it.
func _touch_audit(sim: RampageSim, before: Array) -> void:
	var rig: BoltRig = _rampage.ability_fx._beam.rig
	var reached := {}
	var frames := 0
	var through := 0
	var points := 0
	var cut_ms := 0.0
	while rig.live and frames < AUDIT_MAX:
		var lines: Array[PackedVector3Array] = [rig.drawn_main]
		lines.append_array(rig.drawn_lines)
		var started := Time.get_ticks_usec()
		_rampage.ability_fx._cut_at_standing(lines)
		cut_ms = maxf(cut_ms, (Time.get_ticks_usec() - started) / 1000.0)
		var standing_hits := 0
		for line: PackedVector3Array in lines:
			for k: int in range(1, line.size()):
				var a := line[k - 1]
				var seg := line[k] - a
				var n := maxi(1, ceili(seg.length() / TOUCH_STEP))
				for j: int in n + 1:
					points += 1
					var hit := _cell_at(sim, a + seg * (float(j) / n))
					if hit.x < 0:
						continue
					reached[hit.x] = true
					if hit.y == 1:
						standing_hits += 1
						print(
							(
								"TOUCH frame=%d b%d standing chunk at %s"
								% [frames, hit.x, a + seg * (float(j) / n)]
							)
						)
		through += standing_hits
		frames += 1
		await physics_frame
	var undamaged: Array[int] = []
	for i: int in reached:
		var was: Array[int] = before[i]
		if _floors(sim.buildings[i].frame) == was:
			undamaged.append(i)
	print(
		(
			"AUDIT frames=%d points=%d in_standing_chunks=%d reached=%s reached_undamaged=%s cut_ms=%.2f"
			% [frames, points, through, reached.keys(), undamaged, cut_ms]
		)
	)


## (building index, 1 if the chunk there stands else 0) for a world point, or (-1, 0).
func _cell_at(sim: RampageSim, p: Vector3) -> Vector2i:
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var lx := p.x - (b.x - b.w * 0.5)
		var lz := p.z - (b.z - b.d * 0.5)
		var ly := p.y - b.base
		if lx < 0.0 or lz < 0.0 or ly < 0.0 or lx >= b.w or lz >= b.d or ly >= b.height:
			continue
		return Vector2i(i, 1 if b.frame.alive(Vector3i(floori(lx), floori(ly), floori(lz))) else 0)
	return Vector2i(-1, 0)
