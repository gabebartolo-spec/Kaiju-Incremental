class_name DeathView
extends Node3D
## His death as the player sees it (DeathOverload; director 2026-10-26: "overloaded with kaiju
## energy, crackling up, turning them to stone then exploding into shards"). Reads the sim's death
## each frame: through the stagger a violet crackle builds over his hide with a violet light on
## the street (Special K, creation.lab.colors.special_k); the stone creeps up from his feet; at the
## shatter he is gone into jagged stone chunks (director 2026-10-27, D-323: "Jagged stone chunks",
## irregular broken rock in his hide's texture, many sizes, tumbling with dust): his voxels burst
## out as small chunks that tumble and lie as rubble, the sim's shards fly their arcs as the big
## chunks, each trailing dust, to where they smash, and a flash; then, once the last shard is down
## (D-294 shards first), the dust ring of his blast. The chunks are the broken rock baked by
## tools/blender/death_chunks.py (tuning death.look.chunks), never a box, drawn with his own stone
## (death_stone.gdshader, the formula his hide turns to stone with, at his hide's voxel scale).
## Restrained until the burst (D-242: his own power is the one thing that goes big). Looks:
## data/tuning.json death.look. Presentation only: the sim decides every hit.

const STONE := preload("res://scenes/death_stone.gdshader")

var sim: RampageSim
var city: CityView
var kaiju: KaijuModel
## kick(amount, at): the camera's shake (Rampage.add_trauma).
var kick: Callable
var burst := false
var _blasted := false
var _look: Dictionary
var _cfg: Dictionary
var _violet: Color
var _light: OmniLight3D
var _flash := 0.0
var _rng := RandomNumberGenerator.new()
## The broken stone he flies apart into: each chunk's mesh (longest side 1) and its corners.
var _chunks: Array[Mesh] = []
var _corners: Array[PackedVector3Array] = []
var _stone_mat: ShaderMaterial
## His voxels as small chunks, and the sim's shards as big ones (DeathChunks, one each).
var _debris: DeathChunks
var _shards: DeathChunks
var _spin := PackedVector3Array()
var _trails: Array[GPUParticles3D] = []
var _landed: Dictionary = {}


func _init(p_sim: RampageSim, p_city: CityView, p_kaiju: KaijuModel, p_kick: Callable) -> void:
	sim = p_sim
	city = p_city
	kaiju = p_kaiju
	kick = p_kick
	name = "DeathView"
	_cfg = Content.section("death")
	_look = _cfg["look"]
	_violet = Color(str(Content.section("creation")["lab"]["colors"]["special_k"]))
	_rng.seed = 0xDEAD


func _process(delta: float) -> void:
	var d := sim.death
	if not d.active():
		return
	var stagger := Num.f(_cfg["stagger_s"])
	var charge := smoothstep(0.0, 1.0, d.t / maxf(0.001, stagger))
	var stone := clampf((d.t - stagger) / maxf(0.001, Num.f(_cfg["stone_s"])), 0.0, 1.0)
	if _light == null:
		_begin()
	if d.phase != DeathOverload.Phase.SHATTER:
		kaiju.death.overload(charge, stone)
		var flicker := 0.6 + 0.4 * _rng.randf()
		_light.light_energy = Num.f(_look["light_energy"]) * charge * flicker
		_light.global_position = kaiju.focus() + Vector3(0, kaiju.hip_height(), 0)
		return
	if not burst:
		_burst(d)
	_flash = maxf(0.0, _flash - delta / maxf(0.001, Num.f(_look["burst_s"])))
	_light.light_energy = Num.f(_look["burst_light"]) * _flash * _flash
	_debris.fall(delta, Num.f(_look["gravity"]))
	_fly_shards(d)
	if d.blast_began and not _blasted:
		_blast(d)


## He starts to die: the stagger clip (DeathPose), the violet light, and the chunks loaded ready.
func _begin() -> void:
	kaiju.death.start(str(_cfg["stagger_clip"]))
	_light = OmniLight3D.new()
	_light.light_color = _violet
	_light.omni_range = Num.f(_look["light_range"]) * sim.body_scale()
	_light.shadow_enabled = false
	add_child(_light)
	for path: String in _look["chunks"]:
		var mesh: Mesh = load(path)
		_chunks.append(mesh)
		var corners: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_corners.append(corners)
	_stone_mat = ShaderMaterial.new()
	_stone_mat.shader = STONE
	DeathStone.look(_stone_mat)


## The shatter: his voxels burst out as small chunks, the sim's shards take flight as the big ones
## with their dust, the flash and ring.
func _burst(d: DeathOverload) -> void:
	burst = true
	var points := kaiju.death.body_points(Num.i(_look["debris_max"]))
	kaiju.visible = false
	var centre := Vector3(d.centre.x, 0.0, d.centre.y)
	_flash = 1.0
	_stone_mat.set_shader_parameter("voxel", KaijuModel.VOXEL * sim.body_scale())
	_debris = _pieces("Debris", points.size(), KaijuModel.VOXEL * sim.body_scale(), "debris_size")
	var speed: Array = _look["debris_speed"]
	var up: Array = _look["debris_up"]
	var spin: Array = _look["debris_spin"]
	for i: int in points.size():
		var p: Vector3 = points[i]["pos"]
		var out := Vector3(p.x - centre.x, 0.0, p.z - centre.z).normalized()
		var v := out * _rng.randf_range(Num.f(speed[0]), Num.f(speed[1]))
		v.y = _rng.randf_range(Num.f(up[0]), Num.f(up[1]))
		var turn := _rng.randf_range(Num.f(spin[0]), Num.f(spin[1]))
		_debris.launch(i, p, v * sqrt(sim.body_scale()), _axis() * turn)
		var own: Color = points[i]["color"]
		_debris.paint(i, _piece(own))
	_shards = _pieces("Shards", d.shards.size(), d.cell_size(), "shard_size")
	var puff := FxParticles.dust_puff()
	var trail_look: Dictionary = _look["trail"]
	for s: DeathOverload.Shard in d.shards:
		_shards.paint(s.id, _piece(_own_colour(points, s.from)))
		_spin.append(_axis())
		var trail := FxParticles.dust_trail(_shards.size[s.id], trail_look, puff)
		add_child(trail)
		trail.global_position = s.from
		_trails.append(trail)
	kick.call(Num.f(_look["burst_trauma"]), centre)
	city.fx.shockwave(centre, sim.body.length() * 0.5)


## `count` chunks named `label`: each a seeded chunk mesh and a size (its longest side) of `unit`
## x a pick in tuning death.look[`sizes`], most of them small (size_skew), lying at a seeded turn.
func _pieces(label: String, count: int, unit: float, sizes: String) -> DeathChunks:
	var kinds := PackedInt32Array()
	var size := PackedFloat32Array()
	var lie: Array[Basis] = []
	var span: Array = _look[sizes]
	var skew := Num.f(_look["size_skew"])
	for i: int in count:
		kinds.append(_rng.randi_range(0, _chunks.size() - 1))
		var pick := pow(_rng.randf(), skew)
		size.append(unit * lerpf(Num.f(span[0]), Num.f(span[1]), pick))
		lie.append(Basis(_axis(), _rng.randf() * TAU))
	var group := DeathChunks.new(label, _chunks, _corners, _stone_mat)
	group.fill(kinds, size, lie)
	add_child(group)
	return group


## A seeded direction (a tumble's axis).
func _axis() -> Vector3:
	var v := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	return v.normalized() if v.length() > 0.01 else Vector3.UP


## The blast front starts (the sim: the last shard is down): its dust ring out to the blast.
func _blast(d: DeathOverload) -> void:
	_blasted = true
	var centre := Vector3(d.centre.x, 0.0, d.centre.y)
	kick.call(Num.f(_look["burst_trauma"]), centre)
	city.fx.shockwave(centre, d.blast_radius)


## A piece's instance colour: its own sRGB shade where it flew from, and in alpha its 0..1 hash
## (what the shader varies the stone and shifts its grain by).
func _piece(own: Color) -> Color:
	return Color(own.r, own.g, own.b, _rng.randf())


## His colour at `at`: that of the nearest of the points the burst was taken from.
func _own_colour(points: Array[Dictionary], at: Vector3) -> Color:
	var best := INF
	var out := Color.GRAY
	for p: Dictionary in points:
		var pos: Vector3 = p["pos"]
		var dist := at.distance_squared_to(pos)
		if dist < best:
			best = dist
			var own: Color = p["color"]
			out = own
	return out


## The sim's shards along their arcs (from his body to where the sim lands them), tumbling a turn
## and trailing dust; each comes to lie on its lowest corner where it lands, which crushes the
## street under it (cars, people, props), puffs dust and kicks the camera.
func _fly_shards(d: DeathOverload) -> void:
	var half := d.cell_size() * 0.5
	for s: DeathOverload.Shard in d.shards:
		var rest := _shards.lie[s.id]
		var to := Vector3(s.to.x, _shards.lift(s.id, rest), s.to.y)
		var k := clampf(d.since_shatter / maxf(0.001, s.t), 0.0, 1.0)
		var arc := Num.f(_look["shard_arc"]) * sim.body_scale() * 4.0 * k * (1.0 - k)
		var p := s.from.lerp(to, k) + Vector3(0, arc, 0)
		var turn := Basis(_spin[s.id], k * TAU) * rest if k < 1.0 else rest
		_shards.place(s.id, turn, p)
		if not _landed.has(s.id):
			_trails[s.id].global_position = p
		if s.landed and not _landed.has(s.id):
			_landed[s.id] = true
			_trails[s.id].emitting = false  # its dust hangs, then fades
			var at := Vector3(s.to.x, half, s.to.y)
			city.crush(at, Num.f(_look["crush_radius"]) * sim.body_scale())
			city.fx.dust(at, half * 4.0)
			kick.call(Num.f(_look["shard_trauma"]), at)
