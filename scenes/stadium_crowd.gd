class_name StadiumCrowd
extends Node3D
## The stadium's crowd (director 2026-10-18, D-078: "full of people"): a fan on nearly every
## seat of the baked model, in the two teams' shirts and street clothes, bobbing as they watch.
## When the match panics they all jump up, arms raised, hopping (crowd.gdshader, no CPU), and
## stream out: a few hundred at a time leave their seat and run along their row to the nearest
## exit away from the kaiju, then up its aisle and out, the next taking their place as they go.
## Fans whose seats' chunks fall go with them. Seated and standing fans sit in one static
## MultiMesh per outfit (written once; a fan who leaves is hidden in place); only the runners
## are rewritten each frame. Presentation only; tuning in data/tuning.json "crowd".

enum State { SEATED, STANDING, ALONG, UP, GONE }

const RUN_HZ := 6.0
const STRIDE := 2  # a runner moves every other frame (half the cost; 30 steps a second)
const SHADER := preload("res://scenes/crowd.gdshader")
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

## Frame-time checks: false and the match seats no crowd.
static var enabled := true


class Fan:
	extends RefCounted
	var pos := Vector3.ZERO
	var heading := Vector2.ZERO
	var outfit := 0
	var slot := 0
	var phase := 0.0
	var state := State.SEATED
	var go_at := 0.0
	var speed := 1.0
	var radius := 0.0
	var exit := 0.0
	var missed := 0.0


var fans: Array[Fan] = []
var fleeing := false
## Running totals (tests and the capture tool read them).
var fallen := 0
var escaped := 0
var killed := 0
var _left := 0
var _sim: RampageSim
var _index: int
var _cfg: Dictionary
var _rng: RandomNumberGenerator
var _centre := Vector2.ZERO
var _origin := Vector3.ZERO
var _corner := Vector2.ZERO
var _reach := 0.0
var _heights: Dictionary = {}
## Seat chunk -> the fans seated in it (until it falls).
var _by_chunk: Dictionary = {}
var _static: Array[MultiMesh] = []
var _standing: Array[ArrayMesh] = []
var _static_mat: ShaderMaterial
var _run_mms: Array[MultiMesh] = []
var _queue: Array[Fan] = []
var _next := 0
var _runners: Array[Fan] = []
var _alive := -1
var _tick := 0
var _aisle := 0.0
var _out_after := 0.0
var _cap := 0
var _clock := 0.0


## index: the stadium's building. kits: the match's two kits. rng: the run's presentation stream.
func _init(p_sim: RampageSim, index: int, kits: Array, rng: RandomNumberGenerator) -> void:
	_sim = p_sim
	_index = index
	_rng = rng
	_cfg = Content.section("crowd")
	_aisle = Num.f(_cfg["aisle"])
	_out_after = Num.f(_cfg["out_after"])
	_cap = Num.i(_cfg["runners"])
	var b := _sim.buildings[index]
	_centre = Vector2(b.x, b.z)
	_corner = Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5)
	_reach = Vector2(b.w, b.d).length() * 0.5
	var v := BuildingVoxels.VOXEL
	_origin = Vector3(_corner.x + v * 0.5, 0.0, _corner.y + v * 0.5)
	var outfits := _outfits(kits)
	var share := Num.f(_cfg["team_share"])
	var skins := StadiumMatch.SKINS.size()
	for cell: Vector3i in _seats(LandmarkVoxels.voxels(b.landmark)):
		var fan := Fan.new()
		fan.pos = _origin + Vector3(cell.x, cell.y + 1, cell.z) * v
		fan.heading = (_centre - Vector2(fan.pos.x, fan.pos.z)).normalized()
		var shirt := (
			_rng.randi_range(0, kits.size() - 1)
			if _rng.randf() < share
			else _rng.randi_range(kits.size(), kits.size() + _neutral().size() - 1)
		)
		fan.outfit = shirt * skins + _rng.randi_range(0, skins - 1)
		fan.phase = _rng.randf()
		fans.append(fan)
		var chunk := _chunk(fan.pos)
		var list: Array = _by_chunk.get(chunk, [])
		list.append(fan)
		_by_chunk[chunk] = list
	_left = fans.size()
	_build(outfits)


## Fans still in the stands (seated, standing or on their way out).
func in_stands() -> int:
	return _left


## Fans on their feet: everyone left once the match panics.
func running() -> int:
	return _left if fleeing else 0


## The wall gave: every fan jumps up, and in a staggered order, a few hundred at a time, makes
## for the nearest exit round the ring that is not on the kaiju's side.
func panic(kaiju: Vector2) -> void:
	fleeing = true
	var count := Num.i(_cfg["exits"])
	var toward := (kaiju - _centre).normalized()
	var react: Array = _cfg["react"]
	var run: Array = _cfg["run_speed"]
	for o: int in _static.size():
		_static[o].mesh = _standing[o]
	var panic_bob: Array = _cfg["panic_bob"]
	_static_mat.set_shader_parameter("bob", Num.f(panic_bob[0]))
	_static_mat.set_shader_parameter("bob_hz", Vector2(Num.f(panic_bob[1]), Num.f(panic_bob[2])))
	for fan: Fan in fans:
		if fan.state != State.SEATED:
			continue
		var at := Vector2(fan.pos.x, fan.pos.z) - _centre
		fan.radius = at.length()
		var best := INF
		for k: int in count:
			var angle := (k + 0.5) * TAU / count
			var turn := absf(angle_difference(at.angle(), angle))
			if Vector2.from_angle(angle).dot(toward) < 0.7 and turn < best:
				best = turn
				fan.exit = angle
		fan.go_at = _clock + _rng.randf_range(Num.f(react[0]), Num.f(react[1]))
		fan.speed = _rng.randf_range(Num.f(run[0]), Num.f(run[1]))
		fan.state = State.STANDING
		_queue.append(fan)
	_queue.sort_custom(func(a: Fan, b: Fan) -> bool: return a.go_at < b.go_at)


## Every fan within `radius` of `at` (in plan) is crushed.
func crush(at: Vector3, radius: float) -> void:
	var c := Vector2(at.x, at.z)
	if c.distance_to(_centre) > _reach + radius:
		return
	for fan: Fan in fans:
		if fan.state != State.GONE and Vector2(fan.pos.x, fan.pos.z).distance_to(c) <= radius:
			_gone(fan)
			killed += 1


func _process(delta: float) -> void:
	_clock += delta
	var frame := _sim.buildings[_index].frame
	if frame.alive_count != _alive:
		_alive = frame.alive_count
		_fall(frame)
	if not fleeing:
		return
	while _next < _queue.size() and _runners.size() < _cap and _queue[_next].go_at <= _clock:
		var fan := _queue[_next]
		_next += 1
		if fan.state == State.STANDING:
			_static[fan.outfit].set_instance_transform(fan.slot, HIDDEN)
			fan.state = State.ALONG
			_runners.append(fan)
	_tick += 1
	for i: int in range(_tick % STRIDE, _runners.size(), STRIDE):
		_move(_runners[i], delta * STRIDE)
	_runners = _runners.filter(func(f: Fan) -> bool: return f.state != State.GONE)
	_draw_runners()


## Chunks went: every fan seated in a fallen one goes with it, and so does any runner on one.
func _fall(frame: Structure) -> void:
	for chunk: Vector3i in _by_chunk.keys():
		if frame.alive(chunk):
			continue
		for fan: Fan in _by_chunk[chunk]:
			if fan.state == State.SEATED or fan.state == State.STANDING:
				_gone(fan)
				fallen += 1
		_by_chunk.erase(chunk)
	for fan: Fan in _runners:
		if fan.state != State.GONE and not frame.alive(_chunk(fan.pos)):
			_gone(fan)
			fallen += 1


func _gone(fan: Fan) -> void:
	if fan.state == State.SEATED or fan.state == State.STANDING:
		_static[fan.outfit].set_instance_transform(fan.slot, HIDDEN)
	fan.state = State.GONE
	_left -= 1


## A runner: along the row (at its own radius) to the exit's angle, then straight out up the
## aisle until past the back of the seats.
func _move(fan: Fan, delta: float) -> void:
	var step := fan.speed * delta
	var at := Vector2(fan.pos.x, fan.pos.z) - _centre
	if fan.state == State.ALONG:
		var turn := angle_difference(at.angle(), fan.exit)
		if absf(turn) * fan.radius <= _aisle:
			fan.state = State.UP
			return
		var angle := at.angle() + signf(turn) * minf(step / fan.radius, absf(turn))
		fan.heading = Vector2.from_angle(angle + signf(turn) * PI * 0.5)
		_step(fan, _centre + Vector2.from_angle(angle) * fan.radius, 0.0)
	elif fan.state == State.UP:
		fan.heading = at.normalized()
		_step(fan, Vector2(fan.pos.x, fan.pos.z) + fan.heading * step, step)


## Moves a fan in plan, its feet on the seats there; off the seats for long enough, it is out.
func _step(fan: Fan, to: Vector2, step: float) -> void:
	var v := BuildingVoxels.VOXEL
	var col := Vector2i(roundi((to.x - _origin.x) / v), roundi((to.y - _origin.z) / v))
	var y := fan.pos.y
	if _heights.has(col):
		y = Num.i(_heights[col]) * v
		fan.missed = 0.0
	else:
		fan.missed += step
	fan.pos = Vector3(to.x, y, to.y)
	if fan.missed > _out_after:
		fan.state = State.GONE
		_left -= 1
		escaped += 1


func _chunk(at: Vector3) -> Vector3i:
	var v := BuildingVoxels.VOXEL
	return Vector3i(floori(at.x - _corner.x), floori(at.y - v * 0.5), floori(at.z - _corner.y))


## Seats: the model's seat-coloured voxels open to the sky, one per `spacing` square of plan,
## shuffled and capped at "max". Records the seat height under every plan column for the run.
func _seats(vox: VoxelBuilder) -> Array[Vector3i]:
	var keys: Array = _cfg["seats"]
	var near := Num.f(_cfg["seat_match"]) / 255.0
	var spacing := float(Num.i(_cfg["spacing"]))
	var pick: Dictionary = {}
	for cell: Vector3i in vox.colors:
		if vox.colors.has(cell + Vector3i.UP):
			continue
		var c: Color = vox.colors[cell]
		var seat := false
		for key: String in keys:
			var s := Color(key)
			seat = seat or maxf(absf(c.r - s.r), maxf(absf(c.g - s.g), absf(c.b - s.b))) <= near
		if not seat:
			continue
		var col := Vector2i(cell.x, cell.z)
		_heights[col] = maxi(Num.i(_heights.get(col, 0)), cell.y + 1)
		var key := Vector2i(floori(cell.x / spacing), floori(cell.z / spacing))
		if not pick.has(key):
			pick[key] = cell
	var out: Array[Vector3i] = []
	for cell: Vector3i in pick.values():
		out.append(cell)
	for i: int in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := out[i]
		out[i] = out[j]
		out[j] = swap
	return out.slice(0, mini(out.size(), Num.i(_cfg["max"])))


func _neutral() -> Array:
	return _cfg["neutral"]


## Every (shirt, skin) outfit: the kits' shirts then the neutral ones, on street trousers and hair.
func _outfits(kits: Array) -> Array[Dictionary]:
	var shirts: Array[String] = []
	for kit: Dictionary in kits:
		shirts.append(str(kit["shirt"]))
	for n: Dictionary in _neutral():
		shirts.append(str(n["shirt"]))
	var out: Array[Dictionary] = []
	for i: int in shirts.size():
		var street: Dictionary = _neutral()[i % _neutral().size()]
		for skin: String in StadiumMatch.SKINS:
			out.append(
				{"shirt": shirts[i], "pants": street["pants"], "hair": street["hair"], "skin": skin}
			)
	return out


## One static MultiMesh per outfit, every fan's seat written once; and per outfit the two run
## frames for the runners, sized to the runner cap.
func _build(outfits: Array[Dictionary]) -> void:
	var per: Array[Array] = []
	per.resize(outfits.size())
	for fan: Fan in fans:
		fan.slot = per[fan.outfit].size()
		per[fan.outfit].append(fan)
	var voxel := Num.f(Content.section("street")["person_voxel"])
	_static_mat = ShaderMaterial.new()
	_static_mat.shader = SHADER
	_static_mat.set_shader_parameter("bob", Num.f(_cfg["bob"]))
	var hz: Array = _cfg["bob_hz"]
	_static_mat.set_shader_parameter("bob_hz", Vector2(Num.f(hz[0]), Num.f(hz[1])))
	for o: int in outfits.size():
		var mm := _multimesh(VoxelPerson.seated(outfits[o], voxel), maxi(1, per[o].size()))
		mm.buffer = _transforms(per[o], mm.instance_count)
		mm.visible_instance_count = per[o].size()
		_static.append(mm)
		_add(mm, _static_mat)
		_standing.append(VoxelPerson.dressed(outfits[o], VoxelPerson.Pose.RUN_A, voxel))
		for frame: int in 2:
			var pose := VoxelPerson.Pose.RUN_A + frame
			var run := _multimesh(
				VoxelPerson.dressed(outfits[o], pose, voxel), maxi(1, mini(per[o].size(), _cap))
			)
			_run_mms.append(run)
			_add(run, null)


func _multimesh(mesh: ArrayMesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	return mm


func _add(mm: MultiMesh, mat: Material) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a third of their cost
	add_child(mmi)


## The runners' two frames per outfit, each written as one buffer upload.
func _draw_runners() -> void:
	var groups: Array[Array] = []
	groups.resize(_run_mms.size())
	for fan: Fan in _runners:
		groups[fan.outfit * 2 + int(_clock * RUN_HZ + fan.phase * 2.0) % 2].append(fan)
	for b: int in _run_mms.size():
		var mm := _run_mms[b]
		if groups[b].is_empty() and mm.visible_instance_count == 0:
			continue
		var group := groups[b].slice(0, mm.instance_count)
		mm.buffer = _transforms(group, mm.instance_count)
		mm.visible_instance_count = group.size()


## A full buffer of `count` transforms, the fans' first: each faces its heading, feet at pos.
static func _transforms(group: Array, count: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(count * 12)
	var i := 0
	for fan: Fan in group:
		var c := -fan.heading.y  # the yaw that turns -Z onto the (unit) heading
		var s := -fan.heading.x
		buf[i] = c
		buf[i + 2] = s
		buf[i + 3] = fan.pos.x
		buf[i + 5] = 1.0
		buf[i + 7] = fan.pos.y
		buf[i + 8] = -s
		buf[i + 10] = c
		buf[i + 11] = fan.pos.z
		i += 12
	return buf
