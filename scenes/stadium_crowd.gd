class_name StadiumCrowd
extends Node3D
## The stadium's crowd (director 2026-10-18, D-078: "full of people"): a fan on nearly every
## seat of the baked model, in the two teams' colours and street clothes, bobbing as they watch.
## When the match panics every fan is on their feet at once, arms up, and each after its own
## moment runs straight out up the stands to the back and steps down out of sight through the
## exits, so the stands empty over several seconds with the fans in view all the way (director
## playtest, 2026-10-19: "shouldnt disappear so suddenly, let us kill them"). They die like any
## civilian: under a blow where they are running (crush), or with the stand that falls under
## them; each dead fan counts as a civilian crushed (StreetLife.civilians_killed). One static
## MultiMesh per outfit, written once; the bob, the standing, the run and the exit are all
## crowd.gdshader's. This script places fans with the shader's formula only when it needs to
## (a blow, a fallen chunk), counts who is out and hides the dead. Presentation only; tuning in
## data/tuning.json "crowd".

enum State { SEATED, UP, GONE }

const SHADER := preload("res://scenes/crowd.gdshader")
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
## The shader's per-fan hash of its instance id (crowd.gdshader): the share of the flee delay.
const GOLDEN := 0.6180339887
const PALE := 0.25  # a kit shirt this unsaturated (and bright) reads as an empty seat from above

## Frame-time checks: false and the match seats no crowd.
static var enabled := true


class Fan:
	extends RefCounted
	var pos := Vector3.ZERO
	var outfit := 0
	var slot := 0
	var state := State.SEATED
	var leaves := 0.0  # seconds after the panic it starts running
	var run := 0.0  # metres from its seat to the back of the stands
	var out_at := 0.0  # seconds after the panic it is through an exit


var fans: Array[Fan] = []
var fleeing := false
## For the dust puff where fans die (StadiumMatch sets it); null in tests that build none.
var fx: Fx
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
var _half := Vector2.ZERO
var _corner := Vector2.ZERO
var _reach := 0.0
## The stadium's chunks as built: a chunk standing then and gone now has fallen.
var _built := PackedFloat32Array()
## Fans still to check against fallen chunks since the stadium last lost one, and where the
## round-robin check is (check_per_frame a frame, so a break never costs a frame spike).
var _to_check := 0
var _cursor := 0
var _puffs := 0
var _static: Array[MultiMesh] = []
var _standing: Array[ArrayMesh] = []
var _mat: ShaderMaterial
var _queue: Array[Fan] = []
var _next := 0
var _alive := -1
var _since := -1.0


## index: the stadium's building. kits: the match's two kits. rng: the run's presentation stream.
func _init(p_sim: RampageSim, index: int, kits: Array, rng: RandomNumberGenerator) -> void:
	_sim = p_sim
	_index = index
	_rng = rng
	_cfg = Content.section("crowd")
	var b := _sim.buildings[index]
	_centre = Vector2(b.x, b.z)
	_half = Vector2(b.w, b.d) * 0.5
	_corner = _centre - _half
	_reach = _half.length()
	var v := BuildingVoxels.VOXEL
	var origin := Vector3(_corner.x + v * 0.5, 0.0, _corner.y + v * 0.5)
	var outfits := _outfits(kits)
	var share := Num.f(_cfg["team_share"])
	var skins := StadiumMatch.SKINS.size()
	for cell: Vector3i in _seats(LandmarkVoxels.voxels(b.landmark)):
		var fan := Fan.new()
		fan.pos = origin + Vector3(cell.x, cell.y + 1, cell.z) * v
		var shirt := (
			_rng.randi_range(0, kits.size() - 1)
			if _rng.randf() < share
			else _rng.randi_range(kits.size(), kits.size() + _neutral().size() - 1)
		)
		fan.outfit = shirt * skins + _rng.randi_range(0, skins - 1)
		fans.append(fan)
	_built = b.frame.standing().duplicate()
	_left = fans.size()
	_build(outfits)


## Fans still in the stands (seated, standing or on their way out).
func in_stands() -> int:
	return _left


## Fans on their feet: everyone left once the match panics.
func running() -> int:
	return _left if fleeing else 0


## The wall gave: every fan stands at once and runs for the exits at the back on its own beat.
func panic(_kaiju: Vector2) -> void:
	fleeing = true
	_since = 0.0
	for o: int in _static.size():
		_static[o].mesh = _standing[o]
	var speed := Num.f(_cfg["flee_speed"])
	var delay := Num.f(_cfg["flee_delay"])
	var exit_r := Num.f(_cfg["exit_r"])
	var sink := Num.f(_cfg["sink"])
	for fan: Fan in fans:
		if fan.state != State.SEATED:
			continue
		fan.state = State.UP
		fan.leaves = fmod(fan.slot * GOLDEN, 1.0) * delay
		fan.run = _run_out(fan, exit_r)
		fan.out_at = fan.leaves + (fan.run + sink) / speed
		_queue.append(fan)
	_queue.sort_custom(func(a: Fan, b: Fan) -> bool: return a.out_at < b.out_at)
	_mat.set_shader_parameter("flee_t", 0.0)


## Where a fan's feet are now: its seat, or as far along its run as crowd.gdshader draws it.
func running_at(fan: Fan) -> Vector3:
	if fan.state != State.UP:
		return fan.pos
	var moved := Num.f(_cfg["flee_speed"]) * maxf(0.0, _since - fan.leaves)
	var along := minf(moved, fan.run)
	var down := maxf(0.0, moved - fan.run)
	var dir := (Vector2(fan.pos.x, fan.pos.z) - _centre).normalized()
	var slope := Num.f(_cfg["flee_slope"])
	return fan.pos + Vector3(dir.x * along, along * slope - down, dir.y * along)


## Every fan within `radius` of `at` (in plan), where it is now, is crushed. Returns how many.
func crush(at: Vector3, radius: float) -> int:
	var c := Vector2(at.x, at.z)
	if c.distance_to(_centre) > _reach + radius:
		return 0
	var dead := 0
	_puffs = 0
	for fan: Fan in fans:
		if fan.state == State.GONE:
			continue
		var p := running_at(fan)
		if Vector2(p.x, p.z).distance_to(c) <= radius:
			_die(fan, p)
			dead += 1
	killed += dead
	return dead


func _process(delta: float) -> void:
	var frame := _sim.buildings[_index].frame
	if frame.alive_count != _alive:
		_alive = frame.alive_count
		_to_check = fans.size()
		_puffs = 0
	if _to_check > 0:
		_fall(frame)
	if not fleeing:
		return
	_since += delta
	_mat.set_shader_parameter("flee_t", _since)
	while _next < _queue.size() and _queue[_next].out_at <= _since:
		var fan := _queue[_next]
		_next += 1
		if fan.state == State.UP:
			fan.state = State.GONE
			_left -= 1
			escaped += 1


## Chunks went: every fan standing (or running) on a chunk that has fallen since the match
## began goes with it. check_per_frame fans a frame, round robin, until all were checked.
func _fall(frame: Structure) -> void:
	var hp := frame.standing()
	var n := mini(_to_check, Num.i(_cfg["check_per_frame"]))
	_to_check -= n
	for _i: int in n:
		_cursor = (_cursor + 1) % fans.size()
		var fan := fans[_cursor]
		if fan.state == State.GONE:
			continue
		var p := running_at(fan)
		var c := _chunk(p)
		if not frame.inside(c):
			continue
		var i := frame.index(c)
		if _built[i] > 0.0 and hp[i] <= 0.0:
			_die(fan, p)
			fallen += 1


## Dead where it stood: hidden, and a puff of dust (a few per blow or fall, not one per fan).
func _die(fan: Fan, at: Vector3) -> void:
	_gone(fan)
	if fx != null and _puffs < Num.i(_cfg["max_puffs"]):
		_puffs += 1
		fx.puff(at + Vector3(0, 0.15, 0))


func _gone(fan: Fan) -> void:
	_static[fan.outfit].set_instance_transform(fan.slot, HIDDEN)
	fan.state = State.GONE
	_left -= 1


## How far a fan runs, straight out from the middle, to normalised radius exit_r (as the
## shader does): the root of |q + d m| = exit_r, q its seat and d its direction over the half size.
func _run_out(fan: Fan, exit_r: float) -> float:
	var at := Vector2(fan.pos.x, fan.pos.z) - _centre
	var q := at / _half
	var d := at.normalized() / _half
	var a := d.dot(d)
	var b := q.dot(d)
	var c := q.dot(q) - exit_r * exit_r
	return maxf(0.0, (-b + sqrt(maxf(0.0, b * b - a * c))) / a)


func _chunk(at: Vector3) -> Vector3i:
	var v := BuildingVoxels.VOXEL
	return Vector3i(floori(at.x - _corner.x), floori(at.y - v * 0.5), floori(at.z - _corner.y))


## Seats: the model's seat-coloured voxels open to the sky, one per `spacing` square of plan,
## shuffled and capped at "max".
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
		var key := Vector2i(floori(cell.x / spacing), floori(cell.z / spacing))
		if seat and not pick.has(key):
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


## Every (shirt, skin) outfit: the kits' colours then the neutral shirts, on street trousers
## and hair. A pale kit shirt (cricket whites) reads as an empty grey seat from above, so its
## fans wear the kit's trim (its "hair" colour: caps and helmets) instead.
func _outfits(kits: Array) -> Array[Dictionary]:
	var shirts: Array[String] = []
	for kit: Dictionary in kits:
		var shirt := Color(str(kit["shirt"]))
		shirts.append(str(kit["hair"]) if shirt.s < PALE and shirt.v > 0.7 else str(kit["shirt"]))
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


## One static MultiMesh per outfit, every fan's seat written once, and its standing mesh for
## the panic. The fans face the pitch.
func _build(outfits: Array[Dictionary]) -> void:
	var per: Array[Array] = []
	per.resize(outfits.size())
	for fan: Fan in fans:
		fan.slot = per[fan.outfit].size()
		per[fan.outfit].append(fan)
	var voxel := Num.f(Content.section("street")["person_voxel"])
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("bob", Num.f(_cfg["bob"]))
	var hz: Array = _cfg["bob_hz"]
	_mat.set_shader_parameter("bob_hz", Vector2(Num.f(hz[0]), Num.f(hz[1])))
	_mat.set_shader_parameter("centre", _centre)
	_mat.set_shader_parameter("half_size", _half)
	_mat.set_shader_parameter("exit_r", Num.f(_cfg["exit_r"]))
	_mat.set_shader_parameter("speed", Num.f(_cfg["flee_speed"]))
	_mat.set_shader_parameter("slope", Num.f(_cfg["flee_slope"]))
	_mat.set_shader_parameter("delay", Num.f(_cfg["flee_delay"]))
	_mat.set_shader_parameter("sink", Num.f(_cfg["sink"]))
	for o: int in outfits.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = VoxelPerson.seated(outfits[o], voxel)
		mm.instance_count = maxi(1, per[o].size())
		mm.buffer = _transforms(per[o], mm.instance_count, _centre)
		mm.visible_instance_count = per[o].size()
		_static.append(mm)
		_standing.append(VoxelPerson.dressed(outfits[o], VoxelPerson.Pose.RUN_A, voxel))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a third of their cost
		add_child(mmi)


## A full buffer of `count` transforms, the fans' first, each facing `centre`, feet at its seat.
static func _transforms(group: Array, count: int, centre: Vector2) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(count * 12)
	var i := 0
	for fan: Fan in group:
		var facing := (centre - Vector2(fan.pos.x, fan.pos.z)).normalized()
		var c := -facing.y  # the yaw that turns -Z onto the facing
		var s := -facing.x
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
