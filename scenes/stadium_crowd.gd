class_name StadiumCrowd
extends Node3D
## The stadium's crowd (director 2026-10-18, D-078): spectators seated on every seat tier of the
## baked model, in the two teams' shirts and street clothes, bobbing as they watch (in
## crowd.gdshader: a seated crowd costs nothing per frame). When the
## match panics, the fans whose seats' chunks fall go with them (hidden), and the rest stand,
## run along their row to the nearest exit away from the kaiju, then up its aisle and out.
## One MultiMesh per outfit and pose. Presentation only; tuning in data/tuning.json "crowd".

enum State { SEATED, STANDING, ALONG, UP, GONE }

const POSES := 3  # seated, then the arms-up run's two frames
const RUN_HZ := 6.0
const STRIDE := 3  # a fleeing fan moves every third frame (a third of the cost; 20 steps a second)
const SHADER := preload("res://scenes/crowd.gdshader")

## Frame-time checks: false and the match seats no crowd.
static var enabled := true


class Fan:
	extends RefCounted
	var pos := Vector3.ZERO
	var heading := Vector2.ZERO
	var outfit := 0
	var phase := 0.0
	var state := State.SEATED
	var wait := 0.0
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
var _sim: RampageSim
var _index: int
var _cfg: Dictionary
var _rng: RandomNumberGenerator
var _centre := Vector2.ZERO
var _origin := Vector3.ZERO
var _corner := Vector2.ZERO
var _heights: Dictionary = {}
var _mms: Array[MultiMesh] = []
var _buffers: Array[PackedFloat32Array] = []
var _alive := -1
var _dirty := true
var _tick := 0
var _aisle := 0.0
var _out_after := 0.0
var _clock := 0.0


## index: the stadium's building. kits: the match's two kits. rng: the run's presentation stream.
func _init(p_sim: RampageSim, index: int, kits: Array, rng: RandomNumberGenerator) -> void:
	_sim = p_sim
	_index = index
	_rng = rng
	_cfg = Content.section("crowd")
	_aisle = Num.f(_cfg["aisle"])
	_out_after = Num.f(_cfg["out_after"])
	var b := _sim.buildings[index]
	_centre = Vector2(b.x, b.z)
	_corner = Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5)
	var v := BuildingVoxels.VOXEL
	_origin = Vector3(_corner.x + v * 0.5, 0.0, _corner.y + v * 0.5)
	var outfits := _outfits(kits)
	var seats := _seats(LandmarkVoxels.voxels(b.landmark))
	var share := Num.f(_cfg["team_share"])
	for cell: Vector3i in seats:
		var fan := Fan.new()
		fan.pos = _origin + Vector3(cell.x, cell.y + 1, cell.z) * v
		fan.heading = (_centre - Vector2(fan.pos.x, fan.pos.z)).normalized()
		var shirt := (
			_rng.randi_range(0, kits.size() - 1)
			if _rng.randf() < share
			else _rng.randi_range(kits.size(), kits.size() + _neutral().size() - 1)
		)
		fan.outfit = (
			shirt * StadiumMatch.SKINS.size() + _rng.randi_range(0, StadiumMatch.SKINS.size() - 1)
		)
		fan.phase = _rng.randf()
		fans.append(fan)
	_build(outfits)


## Fans still in the stands (seated or on their way out).
func in_stands() -> int:
	var n := 0
	for fan: Fan in fans:
		n += 1 if fan.state != State.GONE else 0
	return n


## Fans up and running (standing, along a row or up an aisle).
func running() -> int:
	var n := 0
	for fan: Fan in fans:
		n += 1 if fan.state != State.GONE and fan.state != State.SEATED else 0
	return n


## The wall gave: every fan stands after a moment and makes for the nearest exit on the side of
## the stadium away from the kaiju.
func panic(kaiju: Vector2) -> void:
	fleeing = true
	var count := Num.i(_cfg["exits"])
	var toward := (kaiju - _centre).normalized()
	var react: Array = _cfg["react"]
	var run: Array = _cfg["run_speed"]
	for fan: Fan in fans:
		var at := Vector2(fan.pos.x, fan.pos.z) - _centre
		fan.radius = at.length()
		var best := INF
		for k: int in count:
			var angle := (k + 0.5) * TAU / count
			var turn := absf(angle_difference(at.angle(), angle))
			if Vector2.from_angle(angle).dot(toward) < 0.3 and turn < best:
				best = turn
				fan.exit = angle
		fan.wait = _rng.randf_range(Num.f(react[0]), Num.f(react[1]))
		fan.speed = _rng.randf_range(Num.f(run[0]), Num.f(run[1]))
		if fan.state == State.SEATED:
			fan.state = State.STANDING


## Every fan within `radius` of `at` (in plan) is crushed.
func crush(at: Vector3, radius: float) -> void:
	var c := Vector2(at.x, at.z)
	for fan: Fan in fans:
		if fan.state != State.GONE and Vector2(fan.pos.x, fan.pos.z).distance_to(c) <= radius:
			fan.state = State.GONE
			killed += 1
			_dirty = true


func _process(delta: float) -> void:
	_clock += delta
	var frame := _sim.buildings[_index].frame
	if frame.alive_count != _alive:
		_alive = frame.alive_count
		for fan: Fan in fans:
			if fan.state != State.GONE and not frame.alive(_chunk(fan.pos)):
				fan.state = State.GONE
				fallen += 1
				_dirty = true
	if fleeing:
		_tick += 1
		for i: int in range(_tick % STRIDE, fans.size(), STRIDE):  # a share of the fans a frame
			_move(fans[i], delta * STRIDE)
	if _dirty or fleeing:
		_draw()
		_dirty = false


## Standing: wait out the reaction, then along the row (at its own radius) to the exit's
## angle, then straight out up the aisle until past the back of the seats.
func _move(fan: Fan, delta: float) -> void:
	var step := fan.speed * delta
	var at := Vector2(fan.pos.x, fan.pos.z) - _centre
	match fan.state:
		State.STANDING:
			fan.wait -= delta
			if fan.wait <= 0.0:
				fan.state = State.ALONG
		State.ALONG:
			var turn := angle_difference(at.angle(), fan.exit)
			if absf(turn) * fan.radius <= _aisle:
				fan.state = State.UP
				return
			var angle := at.angle() + signf(turn) * minf(step / fan.radius, absf(turn))
			var to := _centre + Vector2.from_angle(angle) * fan.radius
			fan.heading = Vector2.from_angle(angle + signf(turn) * PI * 0.5)
			_step(fan, to, 0.0)
		State.UP:
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


func _build(outfits: Array[Dictionary]) -> void:
	var per := PackedInt32Array()
	per.resize(outfits.size())
	for fan: Fan in fans:
		per[fan.outfit] += 1
	var voxel := Num.f(Content.section("street")["person_voxel"])
	var seated := ShaderMaterial.new()
	seated.shader = SHADER
	seated.set_shader_parameter("bob", Num.f(_cfg["bob"]))
	var hz: Array = _cfg["bob_hz"]
	seated.set_shader_parameter("bob_hz", Vector2(Num.f(hz[0]), Num.f(hz[1])))
	for o: int in outfits.size():
		for pose: int in POSES:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = (
				VoxelPerson.seated(outfits[o], voxel)
				if pose == 0
				else VoxelPerson.dressed(outfits[o], VoxelPerson.Pose.RUN_A + pose - 1, voxel)
			)
			mm.instance_count = maxi(1, per[o])
			mm.visible_instance_count = 0
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = seated if pose == 0 else null
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a third of their cost
			add_child(mmi)
			_mms.append(mm)
			var buffer := PackedFloat32Array()
			buffer.resize(mm.instance_count * 12)
			_buffers.append(buffer)


## Writes each bucket's transforms as one buffer upload (cheaper than a call per fan).
func _draw() -> void:
	var groups: Array[Array] = []
	groups.resize(_mms.size())
	for fan: Fan in fans:
		if fan.state == State.GONE:
			continue
		var pose := 0
		if fan.state == State.STANDING:
			pose = 1
		elif fan.state != State.SEATED:
			pose = 1 + int(_clock * RUN_HZ + fan.phase * 2.0) % 2
		groups[fan.outfit * POSES + pose].append(fan)
	for b: int in _mms.size():
		var group := groups[b]
		if group.is_empty() and _mms[b].visible_instance_count == 0:
			continue
		var buf := _buffers[b]
		var i := 0
		for fan: Fan in group:
			var c := -fan.heading.y  # the yaw that turns -Z onto the (unit) heading
			var s := -fan.heading.x
			buf[i] = c
			buf[i + 1] = 0.0
			buf[i + 2] = s
			buf[i + 3] = fan.pos.x
			buf[i + 4] = 0.0
			buf[i + 5] = 1.0
			buf[i + 6] = 0.0
			buf[i + 7] = fan.pos.y
			buf[i + 8] = -s
			buf[i + 9] = 0.0
			buf[i + 10] = c
			buf[i + 11] = fan.pos.z
			i += 12
		_buffers[b] = buf
		_mms[b].buffer = buf
		_mms[b].visible_instance_count = group.size()
