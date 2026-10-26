class_name DeathView
extends Node3D
## His death as the player sees it (DeathOverload; director 2026-10-26: "overloaded with kaiju
## energy, crackling up, turning them to stone then exploding into shards"). Reads the sim's death
## each frame: through the stagger a violet crackle builds over his hide with a violet light on
## the street (Special K, creation.lab.colors.special_k); the stone creeps up from his feet; at the
## shatter he is gone into his own blocks: a burst of his voxels (stone now) thrown out to land and
## lie as rubble, the sim's shards flying their arcs to where they smash, a flash and the dust
## ring of his blast. Restrained until the burst (D-242: his own power is the one thing that goes
## big). Looks: data/tuning.json death.look. Presentation only: the sim decides every hit.

var sim: RampageSim
var city: CityView
var kaiju: KaijuModel
## kick(amount, at): the camera's shake (Rampage.add_trauma).
var kick: Callable
var burst := false
var _look: Dictionary
var _cfg: Dictionary
var _violet: Color
var _stone: Color
var _light: OmniLight3D
var _flash := 0.0
var _rng := RandomNumberGenerator.new()
var _debris: MultiMeshInstance3D
var _debris_pos := PackedVector3Array()
var _debris_vel := PackedVector3Array()
var _debris_half := 0.1
var _shards: MultiMeshInstance3D
var _landed: Dictionary = {}
var _spin := PackedVector3Array()


func _init(p_sim: RampageSim, p_city: CityView, p_kaiju: KaijuModel, p_kick: Callable) -> void:
	sim = p_sim
	city = p_city
	kaiju = p_kaiju
	kick = p_kick
	name = "DeathView"
	_cfg = Content.section("death")
	_look = _cfg["look"]
	_violet = Color(str(Content.section("creation")["lab"]["colors"]["special_k"]))
	_stone = Color(str(_look["stone"]))
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
	_fly_debris(delta)
	_fly_shards(d)


## He starts to die: the stagger clip (DeathPose) and the violet light.
func _begin() -> void:
	kaiju.death.start(str(_cfg["stagger_clip"]))
	_light = OmniLight3D.new()
	_light.light_color = _violet
	_light.omni_range = Num.f(_look["light_range"]) * sim.body_scale()
	_light.shadow_enabled = false
	add_child(_light)


## The shatter: his voxels burst out as stone, the sim's shards take flight, the flash and ring.
func _burst(d: DeathOverload) -> void:
	burst = true
	var points := kaiju.death.body_points(Num.i(_look["debris_max"]))
	kaiju.visible = false
	var centre := Vector3(d.centre.x, 0.0, d.centre.y)
	_flash = 1.0
	_debris_half = KaijuModel.VOXEL * Num.f(_look["debris_size"]) * sim.body_scale() * 0.5
	_debris = _cubes(points.size(), _debris_half * 2.0)
	var speed: Array = _look["debris_speed"]
	var up: Array = _look["debris_up"]
	for i: int in points.size():
		var p: Vector3 = points[i]["pos"]
		var out := Vector3(p.x - centre.x, 0.0, p.z - centre.z).normalized()
		var v := out * _rng.randf_range(Num.f(speed[0]), Num.f(speed[1]))
		v.y = _rng.randf_range(Num.f(up[0]), Num.f(up[1]))
		_debris_pos.append(p)
		_debris_vel.append(v * sqrt(sim.body_scale()))
		var own: Color = points[i]["color"]
		_debris.multimesh.set_instance_color(i, _rock(own))
	_shards = _cubes(d.shards.size(), d.cell_size())
	for s: DeathOverload.Shard in d.shards:
		_shards.multimesh.set_instance_color(s.id, _rock(Color(0.5, 0.5, 0.5)))
		_spin.append(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0).normalized())
	kick.call(Num.f(_look["burst_trauma"]), centre)
	var ring := maxf(d.blast_radius, sim.body.length() * 0.5)
	city.fx.shockwave(centre, ring)


## A stone block's colour: the stone grey varied block by block, keeping some of his own shade.
func _rock(own: Color) -> Color:
	var rock := _stone * (1.0 + _rng.randf_range(-1.0, 1.0) * Num.f(_look["stone_vary"]))
	var keep := Num.f(_look["stone_keep"])
	return rock.lerp(rock * (0.6 + own.get_luminance()), keep)


func _cubes(count: int, size: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	box.material = mat
	mm.mesh = box
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	add_child(node)
	return node


## His voxels fly, fall and stop where they hit the street (they stay: rubble).
func _fly_debris(delta: float) -> void:
	var g := Num.f(_look["gravity"])
	var mm := _debris.multimesh
	for i: int in _debris_pos.size():
		var v := _debris_vel[i]
		if v == Vector3.ZERO:
			continue
		v.y -= g * delta
		var p := _debris_pos[i] + v * delta
		if p.y <= _debris_half:
			p.y = _debris_half
			v = Vector3.ZERO
		_debris_pos[i] = p
		_debris_vel[i] = v
		mm.set_instance_transform(i, Transform3D(Basis(), p))


## The sim's shards along their arcs (from his body to where the sim lands them), tumbling; each
## landing crushes the street under it (cars, people, props) and kicks the camera.
func _fly_shards(d: DeathOverload) -> void:
	var mm := _shards.multimesh
	var half := d.cell_size() * 0.5
	for s: DeathOverload.Shard in d.shards:
		var to := Vector3(s.to.x, half, s.to.y)
		var k := clampf(d.since_shatter / maxf(0.001, s.t), 0.0, 1.0)
		var arc := Num.f(_look["shard_arc"]) * sim.body_scale() * 4.0 * k * (1.0 - k)
		var p := s.from.lerp(to, k) + Vector3(0, arc, 0)
		var turn := Basis(_spin[s.id], k * TAU) if k < 1.0 else Basis()
		mm.set_instance_transform(s.id, Transform3D(turn, p))
		if s.landed and not _landed.has(s.id):
			_landed[s.id] = true
			city.crush(to, Num.f(_look["crush_radius"]) * sim.body_scale())
			city.fx.dust(to, half * 4.0)
			kick.call(Num.f(_look["shard_trauma"]), to)
