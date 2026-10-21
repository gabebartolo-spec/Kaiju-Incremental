extends SceneTree
## Build 2 note 22: the side of a building that touched a neighbour carries the real facade, not
## a blank wall. Stills of touching pairs (the taller building A, its shorter neighbour M on side
## S): both standing, then after M is demolished (every cell of it destroyed, the falls landed),
## from the game camera's angle when M is south of A and from the exposed side otherwise. Shows
## proud awnings and sills on the exposed wall (none floating, none z-fighting). Needs a window:
## run it off-screen with the no_focus override or on CI.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_party_facades.gd -- --out=<dir> [--tier=1] [--pairs=3]

const SETTLE := 6
const AFTER := 360
const SPECIES := "reptilian"
## Rampage.CAMERA_OFFSET: the in-game camera, before its zoom by body scale.
const GAME_CAMERA := Vector3(0, 27, 19)
const LEVELS := [{"claws": 3, "hide": 2}, {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1}]
const DT := 1.0 / 30.0
const FALL_SECONDS := 10.0

var _out := "user://party_facades"
var _tier := 1
var _pairs := 3
## --at=ax,az,mx,mz: shoot the pair of buildings at these centres (A, then its neighbour M).
var _at := PackedFloat32Array()
var _sim: RampageSim
var _city: CityView


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--tier="):
			_tier = int(arg.substr(7))
		elif arg.begins_with("--at="):
			for part: String in arg.substr(5).split(","):
				_at.append(float(part))
		elif arg.begins_with("--pairs="):
			_pairs = int(arg.substr(8))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def(SPECIES)
	var levels: Dictionary = LEVELS[_tier - 1]
	var tree := UpgradeTree.new(Content.upgrades(), levels, SPECIES)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var tuning := CityGrowth.tuning_for(Content.tuning(), _tier)
	var layout := CityGrowth.layout(Content.tuning(), _tier, Seeds.make("city", 0))
	_sim = RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	_sim.time_left = 1.0e6
	var stage := Node3D.new()
	_city = CityView.new(_sim, Seeds.make("fx", 0))
	stage.add_child(_city)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 4000.0
	stage.add_child(cam)
	root.add_child(stage)
	cam.current = true
	var found := _find_pairs() if _at.is_empty() else _named_pair()
	print("touching pairs (A taller than M, neither a landmark): ", found.size())
	var shot := 0
	for pair: Array in found:
		if shot >= _pairs:
			break
		await _pair(cam, pair, shot)
		shot += 1
	quit()


## [a index, m index, side] for each building A with a shorter touching neighbour M, spread over
## the city: the south sides (the game camera sees them) first, the rest after.
func _find_pairs() -> Array:
	var south: Array = []
	var other: Array = []
	var bs := _sim.buildings
	for n: int in bs.size():
		var a := bs[n]
		if a.landmark != "" or a.height < 6:
			continue
		for m: int in bs.size():
			var o := bs[m]
			if m == n or o.landmark != "" or o.height < 3 or o.height >= a.height - 2:
				continue
			var gap_x := absf(a.x - o.x) - (a.w + o.w) * 0.5
			var gap_z := absf(a.z - o.z) - (a.d + o.d) * 0.5
			var side := Vector2i.ZERO
			if absf(gap_x) < 0.01 and gap_z < -3.0:
				side = Vector2i(1 if o.x > a.x else -1, 0)
			elif absf(gap_z) < 0.01 and gap_x < -3.0:
				side = Vector2i(0, 1 if o.z > a.z else -1)
			if side == Vector2i.ZERO:
				continue
			(south if side == Vector2i(0, 1) else other).append([n, m, side])
	var out: Array = []
	# One south pair and one east or west pair first, then whatever else.
	if not south.is_empty():
		out.append(south[0])
	if not other.is_empty():
		out.append(other[0])
	out.append_array(south.slice(1, 4))
	out.append_array(other.slice(1, 4))
	return out


## The pair --at names: A, M and the side of A that M touches.
func _named_pair() -> Array:
	var a := -1
	var m := -1
	for n: int in _sim.buildings.size():
		var b := _sim.buildings[n]
		if is_equal_approx(b.x, _at[0]) and is_equal_approx(b.z, _at[1]):
			a = n
		if is_equal_approx(b.x, _at[2]) and is_equal_approx(b.z, _at[3]):
			m = n
	var d := Vector2(_at[2] - _at[0], _at[3] - _at[1])
	var side := (
		Vector2i(signi(roundi(d.x)), 0)
		if absf(d.x) > absf(d.y)
		else Vector2i(0, signi(roundi(d.y)))
	)
	return [[a, m, side]]


func _pair(cam: Camera3D, pair: Array, number: int) -> void:
	var a := _sim.buildings[Num.i(pair[0])]
	var m := _sim.buildings[Num.i(pair[1])]
	var side: Vector2i = pair[2]
	var tag := (
		"pair%d_%s_%dx%dx%d_beside_%dx%dx%d"
		% [
			number,
			"S" if side == Vector2i(0, 1) else "side",
			a.w,
			a.d,
			a.height,
			m.w,
			m.d,
			m.height
		]
	)
	print(tag, " A at ", a.x, ",", a.z, " M at ", m.x, ",", m.z, " side ", side)
	# The middle of the shared wall, where the exposed part of A will show.
	var joint := Vector3(a.x + side.x * a.w * 0.5, a.height * 0.35, a.z + side.y * a.d * 0.5)
	var dir := GAME_CAMERA.normalized()
	if side.x != 0:
		dir = Vector3(side.x * 0.8, 0.8, 0.45).normalized()
	_sim.kaiju_pos = Vector2(joint.x, joint.z) + Vector2(side) * 20.0
	var reach := maxf(a.height * 1.9, 28.0)
	cam.position = joint + dir * reach
	cam.look_at(joint)
	await _frames(SETTLE)
	_shot(tag + "_standing")
	# The neighbour's roofline at the shared wall, both standing: where proud cells of A (rails,
	# balconies) could cross the neighbour's roof and parapet cells.
	var roof := Vector3(joint.x, m.height + 1.0, joint.z)
	var over := Vector3(side.x, 0.0, side.y)
	cam.position = roof + over * 7.0 + Vector3(0.0, 6.0, 0.0) + Vector3(over.z, 0.0, over.x) * 6.0
	cam.look_at(roof)
	await _frames(SETTLE)
	_shot(tag + "_standing_roofline")
	_demolish(Num.i(pair[1]))
	var t := 0.0
	while t < FALL_SECONDS:
		_apply(_sim.step(DT, Vector2.ZERO, false))
		t += DT
		await process_frame
	await _frames(AFTER)
	_shot(tag + "_neighbour_down")
	# Close in on the ground floor of the exposed wall, from the street: awnings and sills.
	var street := Vector3(side.x, 0.0, side.y)
	var low := Vector3(joint.x, 0.0, joint.z) + street * 12.0 + Vector3(0.0, 4.5, 0.0)
	if side.x == 0:
		low.x += 5.0
	else:
		low.z += 5.0
	cam.position = low
	cam.look_at(Vector3(joint.x, 2.5, joint.z))
	await _frames(SETTLE)
	_shot(tag + "_neighbour_down_street")
	# And the same without the ruin's heap, which hides the ground floor (the ruins' own look is
	# not what this checks).
	_city.ruins().visible = false
	await _frames(SETTLE)
	_shot(tag + "_neighbour_down_street_clear")
	_city.ruins().visible = true
	print(
		tag,
		": neighbour chunks left ",
		m.frame.alive_count,
		", A chunks left ",
		a.frame.alive_count
	)


## Every cell of building `index` destroyed at once; the sim settles it and the view draws it.
func _demolish(index: int) -> void:
	var b := _sim.buildings[index]
	var cells: Array[Vector3i] = []
	for y: int in b.height:
		for x: int in b.w:
			for z: int in b.d:
				if b.frame.alive(Vector3i(x, y, z)):
					cells.append(Vector3i(x, y, z))
	_sim.damage_chunks(index, cells, 1.0e6)
	# Events made outside step() wait in the sim; draw them now, as step()'s are.
	var made: Array[Dictionary] = _sim.events.duplicate()
	_sim.events.clear()
	_apply(made)


func _apply(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		match str(event["type"]):
			"chunks_broken":
				var cells: Array[Vector3i] = event["cells"]
				_city.chunks_broken(Num.i(event["building"]), cells, Vector3.ZERO)
			"fall_start":
				_city.fall_start(event)
			"fall_land":
				_city.fall_land(event)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(shot_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
