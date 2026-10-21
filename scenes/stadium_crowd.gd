class_name StadiumCrowd
extends Node3D
## The stadium's crowd (director 2026-10-18, D-078: "full of people"): a fan on nearly every
## seat of the baked model, in the two teams' colours and street clothes, bobbing as they watch.
## When the match panics every fan is on their feet at once, arms up, and each after its own
## moment runs straight out up the stands to the back and steps down out of sight through the
## exits, so the stands empty over many seconds with the fans in view all the way (director
## playtest, 2026-10-19: "shouldnt disappear so suddenly, let us kill them").
## They die like any civilian, and never vanish: under a blow where they are running (crush), or
## with the stand under them, and each dead fan counts as a civilian crushed
## (StreetLife.civilians_killed). A fan whose stand has gone (seated, or running over the gap)
## is brought down that frame or the next: it falls to what still stands below, lies there
## among the debris for a few seconds and is gone under the dust (director, playtest comments
## #17: "humans feet dangling in the air ... they should fall to the ground"; b2-8: "tens of
## thousands of people disappear in a heart beat"). One static MultiMesh per outfit, written
## once; the bob, the standing, the run, the exit and the fall are all crowd.gdshader's (the fall
## through each fan's custom data). This script places fans with the shader's formula only when
## it needs to (a blow, a fallen chunk), says when a fan starts to fall and counts who is still
## in view. Presentation only (a fan's death feeds no biomass); tuning in data/tuning.json "crowd".

enum State { SEATED, UP, DYING, GONE }

const SHADER := preload("res://scenes/crowd.gdshader")
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
## The shader's per-fan hash of its instance id (crowd.gdshader): the share of the flee delay.
const GOLDEN := 0.6180339887
## A body takes this long to go over once it lands (the shader's tilt ends with the fall).
const TOPPLE := 0.25
## Graves are kept in buckets of this many seconds, counted once their time has passed.
const BUCKET := 0.25

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
	var gone_at := 0.0  # crowd time its body is out of sight, once it falls

	## Killed, or falling, or lying among the debris, or gone.
	func is_dead() -> bool:
		return state == State.DYING or state == State.GONE


var fans: Array[Fan] = []
var fleeing := false
## For the dust puff where fans die (StadiumMatch sets it); null in tests that build none.
var fx: Fx
## Running totals (tests and the capture tool read them).
var fallen := 0
var escaped := 0
var killed := 0
var _left := 0
var _dying := 0
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
## Chunk index -> the fans seated in it, until it goes.
var _hosts: Dictionary = {}
## Fans on the run, checked a slice a frame against the chunks (see _sweep).
var _runners: Array[Fan] = []
var _by_leave: Array[Fan] = []
var _started := 0
var _sweep_at := 0
var _puffs := 0
var _static: Array[MultiMesh] = []
var _standing: Array[ArrayMesh] = []
var _mat: ShaderMaterial
var _queue: Array[Fan] = []
var _next := 0
var _alive := -1
var _whole := 0  # chunks the stadium was built with
var _since := -1.0
var _clock := 0.0
## From tuning, read once: the fall's gravity, how long a body lies (min, max), how long it shrinks.
var _gravity := 30.0
var _linger := Vector2.ZERO
var _shrink := 0.5
## Bodies by the bucket of the time they are out of sight: index -> Array[Fan].
var _graves: Dictionary = {}
var _grave_next := 0


## index: the stadium's building. kits: the match's two kits. rng: the run's presentation stream.
func _init(p_sim: RampageSim, index: int, kits: Array, rng: RandomNumberGenerator) -> void:
	_sim = p_sim
	_index = index
	_rng = rng
	_cfg = Content.section("crowd")
	_gravity = Num.f(_sim.city["fall_gravity"])
	var linger: Array = _cfg["linger"]
	_linger = Vector2(Num.f(linger[0]), Num.f(linger[1]))
	_shrink = Num.f(_cfg["shrink"])
	var b := _sim.buildings[index]
	_centre = Vector2(b.x, b.z)
	_half = Vector2(b.w, b.d) * 0.5
	_corner = _centre - _half
	_reach = _half.length()
	var v := BuildingVoxels.VOXEL
	var origin := Vector3(_corner.x + v * 0.5, 0.0, _corner.y + v * 0.5)
	var neutral: Array = _cfg["neutral"]
	var outfits := CrowdBuild.outfits(kits, neutral)
	var share := Num.f(_cfg["team_share"])
	var skins := StadiumMatch.SKINS.size()
	for cell: Vector3i in CrowdBuild.seats(LandmarkVoxels.voxels(b.landmark), _cfg, _rng):
		var fan := Fan.new()
		fan.pos = origin + Vector3(cell.x, cell.y + 1, cell.z) * v
		var shirt := (
			_rng.randi_range(0, kits.size() - 1)
			if _rng.randf() < share
			else _rng.randi_range(kits.size(), kits.size() + neutral.size() - 1)
		)
		fan.outfit = shirt * skins + _rng.randi_range(0, skins - 1)
		fans.append(fan)
		var c := _chunk(fan.pos)
		if b.frame.inside(c):
			var at := b.frame.index(c)
			var seated: Array = _hosts.get(at, [])
			seated.append(fan)
			_hosts[at] = seated
	_built = b.frame.standing().duplicate()
	_whole = b.frame.alive_count
	_left = fans.size()
	_build(outfits)


## Fans still in view: seated, standing, on their way out, falling or lying among the debris.
func in_stands() -> int:
	return _left


## Fans on their feet: everyone not yet dead once the match panics.
func running() -> int:
	return _left - _dying if fleeing else 0


## Fans falling or lying in the wreck of a stand or under a blow, not yet out of sight.
func dying() -> int:
	return _dying


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
	_by_leave = _queue.duplicate()
	_by_leave.sort_custom(func(a: Fan, b: Fan) -> bool: return a.leaves < b.leaves)
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
		if fan.is_dead():
			continue
		var p := running_at(fan)
		if Vector2(p.x, p.z).distance_to(c) <= radius:
			_die(fan, p, p.y)
			dead += 1
	killed += dead
	return dead


func _process(delta: float) -> void:
	_clock += delta
	_mat.set_shader_parameter("clock", _clock)
	var frame := _sim.buildings[_index].frame
	if frame.alive_count != _alive:
		_alive = frame.alive_count
		_puffs = 0
		_lose_seats(frame)
	if fleeing:
		_since += delta
		_mat.set_shader_parameter("flee_t", _since)
		_leave()
		while _next < _queue.size() and _queue[_next].out_at <= _since:
			var fan := _queue[_next]
			_next += 1
			if fan.state == State.UP:
				fan.state = State.GONE
				_left -= 1
				escaped += 1
		if _alive < _whole:
			_sweep(frame)
	_bury()


## Chunks went: every fan still on its seat over a chunk that has gone falls with it, the frame
## it went (the seats are indexed by chunk, so nobody is left standing on nothing).
func _lose_seats(frame: Structure) -> void:
	var hp := frame.standing()
	for at: int in _hosts.keys():
		if _built[at] <= 0.0 or hp[at] > 0.0:
			continue
		for fan: Fan in _hosts[at]:
			if fan.state == State.SEATED or (fan.state == State.UP and _since <= fan.leaves):
				_down(frame, hp, fan, fan.pos)
		_hosts.erase(at)


## Fans whose moment has come take to the stands: from now they are checked against the chunks.
func _leave() -> void:
	while _started < _by_leave.size() and _by_leave[_started].leaves <= _since:
		_runners.append(_by_leave[_started])
		_started += 1


## Fans running up the stands, a slice of them a frame (every one is checked within
## "check_slices" frames): one that is over a chunk that has gone falls. Only while the stadium
## has lost a chunk at all.
func _sweep(frame: Structure) -> void:
	var hp := frame.standing()
	var n := ceili(float(_runners.size()) / Num.i(_cfg["check_slices"]))
	var i := _sweep_at
	while n > 0 and not _runners.is_empty():
		n -= 1
		if i >= _runners.size():
			i = 0
		var fan := _runners[i]
		if fan.state != State.UP:
			_runners[i] = _runners.back()
			_runners.pop_back()
			continue
		i += 1
		var p := running_at(fan)
		if Vector2(p.x - fan.pos.x, p.z - fan.pos.z).length() >= fan.run:
			continue  # stepping down the exit: out of sight in a moment
		var c := _chunk(p)
		if not frame.inside(c):
			continue
		var at := frame.index(c)
		if _built[at] > 0.0 and hp[at] <= 0.0:
			_down(frame, hp, fan, p)
	_sweep_at = i


## A fan's stand has gone from under it at `at`: it falls to what stands below, or the ground.
func _down(frame: Structure, hp: PackedFloat32Array, fan: Fan, at: Vector3) -> void:
	var c := _chunk(at)
	var land := 0
	if frame.inside(c):
		var plan := frame.w * frame.d
		var col := c.x + c.z * frame.w
		for y: int in range(mini(c.y, frame.h) - 1, -1, -1):
			if hp[col + y * plan] > 0.0:
				land = y + 1
				break
	_die(fan, at, minf(float(land), at.y))
	fallen += 1


## Dead where it stood, or falling to `land`: a body that goes over and lies there a few seconds,
## and a puff of dust (a few per blow or fall, not one per fan).
func _die(fan: Fan, at: Vector3, land: float) -> void:
	if fx != null and _puffs < Num.i(_cfg["max_puffs"]):
		_puffs += 1
		fx.puff(at + Vector3(0, 0.15, 0))
	if fan.state == State.UP and Vector2(at.x - fan.pos.x, at.z - fan.pos.z).length() >= fan.run:
		_gone(fan)  # already stepping down the exit, out of sight
		return
	var air := maxf(0.0, at.y - land)
	var lie := sqrt(2.0 * air / _gravity) + TOPPLE
	var stay := _rng.randf_range(_linger.x, _linger.y)
	fan.state = State.DYING
	fan.gone_at = _clock + lie + stay + _shrink
	var frozen := _since if fleeing else -1.0
	_static[fan.outfit].set_instance_custom_data(fan.slot, Color(_clock + 1.0, frozen, land, stay))
	_dying += 1
	var key := floori(fan.gone_at / BUCKET)
	var bodies: Array = _graves.get(key, [])
	bodies.append(fan)
	_graves[key] = bodies


## Bodies whose time has passed are out of sight: hidden and no longer counted.
func _bury() -> void:
	var now := floori(_clock / BUCKET)
	while _grave_next < now:
		if _graves.has(_grave_next):
			for fan: Fan in _graves[_grave_next]:
				_gone(fan)
			_graves.erase(_grave_next)
		_grave_next += 1


func _gone(fan: Fan) -> void:
	_static[fan.outfit].set_instance_transform(fan.slot, HIDDEN)
	if fan.state == State.DYING:
		_dying -= 1
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
	_mat.set_shader_parameter("fall_g", Num.f(_sim.city["fall_gravity"]))
	_mat.set_shader_parameter("shrink", Num.f(_cfg["shrink"]))
	_mat.set_shader_parameter("topple", TOPPLE)
	for o: int in outfits.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = VoxelPerson.seated(outfits[o], voxel)
		mm.instance_count = maxi(1, per[o].size())
		mm.buffer = CrowdBuild.transforms(per[o], mm.instance_count, _centre)
		mm.visible_instance_count = per[o].size()
		_static.append(mm)
		_standing.append(VoxelPerson.dressed(outfits[o], VoxelPerson.Pose.RUN_A, voxel))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a third of their cost
		add_child(mmi)
