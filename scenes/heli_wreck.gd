class_name HeliWreck
extends Node3D
## How a downed helicopter looks (D-140, D-141, D-145; the sim's AirWing decides which):
## "burst" blows it apart in the air (a flash and a light, a ball of Fire's flame voxels, a smoke
## puff, the model's own rotors, gun and body thrown out on visible arcs with flames and chunks);
## "spin" sets it burning and falling along the sim's drift, flames along its body and a thick
## smoke trail behind it, pitching, rolling and spinning faster, crew bailing out under pale
## canopies, until "heli_crashed" lands it: a flash and light, a fireball, dust and a ring, its
## rotors thrown off and its body left burning; "grabbed" just takes the model away (the
## tentacle's throw draws the rest). Every look is an existing family (docs/VFX_STYLE.md): Fire,
## smoke, dust, flashes, debris (HeliFx, HeliDebris). Numbers: tuning "heli_wreck". Part of
## PowersView. Presentation only.

const CREW_OUTFIT := 2  # VoxelPerson.ROOFTOP_OUTFITS: a soldier in drab
const CANOPY := Color("e2dac4")
const WRECK_HALF := 0.7  # how high the body's middle rides when it lies on the street
const BLAST := Color("ffb468")
const CRASH_BLAST := Color("ff8a3a")

## The rampage's sounds (PowersView passes its own on).
var sfx: Sfx
var _city: CityView
var _sim: RampageSim
var _cfg: Dictionary
var _debris: HeliDebris
var _rng := Seeds.make("heli_wreck")
## id -> Fall: wrecks falling.
var _falling: Dictionary = {}
var _crew: Array[Chute] = []


## A wreck falling along the sim's drift, trailing its fire and smoke.
class Fall:
	var node: Node3D
	var fires: Array[Fire] = []
	var trail: GPUParticles3D
	var from: Vector3
	var drift: Vector3
	var side: Vector3  # which way its path bows out of the straight line
	var seconds: float
	var t := 0.0
	var yaw := 0.0


## A crew member under a canopy, drifting from `from` to `to`.
class Chute:
	var node: Node3D
	var from: Vector3
	var to: Vector3
	var seconds: float
	var t := 0.0


func _init(city: CityView, sim: RampageSim) -> void:
	_city = city
	_sim = sim
	_cfg = Content.section("heli_wreck")
	_debris = HeliDebris.new(_cfg, _rng)
	add_child(_debris)


## The sim downed helicopter `node` (its model, already off the circle) with `event`.
func downed(node: Node3D, event: Dictionary) -> void:
	var at := Vector3(Num.f(event["x"]), _sim.air.altitude(), Num.f(event["z"]))
	match str(event.get("fate", "burst")):
		"grabbed":
			node.queue_free()
		"spin":
			_spin(node, at, event)
		_:
			_burst(node, at)


## A spinning wreck reached the street at the sim's crash point.
func crashed(event: Dictionary) -> void:
	var id := Num.i(event["heli"])
	var ground := Vector3(Num.f(event["x"]), 0.0, Num.f(event["z"]))
	if _falling.has(id):
		var fall: Fall = _falling[id]
		_end_fall(fall)
		_break_up(fall.node, 0.6, false)
		_falling.erase(id)
	var scale := Num.f(_cfg["crash_scale"])
	HeliFx.flare(_city, ground + Vector3(0, 2.0, 0), Num.f(_cfg["crash_flare"]), 0.3)
	_city.flash(
		ground + Vector3(0, 2.0, 0),
		CRASH_BLAST,
		Num.f(_cfg["crash_light"]),
		Num.f(_cfg["crash_light_seconds"])
	)
	HeliFx.fireball(_city, ground + Vector3(0, 1.0, 0), _cfg, Num.f(_cfg["crash_fireball"]))
	HeliFx.smoke_puff(_city, ground + Vector3(0, 1.5, 0), _cfg, Num.f(_cfg["crash_smoke"]))
	_city.fire(ground, Num.f(_cfg["crash_fire"]))
	_city.fx.dust(ground + Vector3(0, 0.4, 0), scale)
	_city.fx.shockwave(ground, scale * Num.f(_cfg["crash_ring"]))
	_debris.shards(ground + Vector3(0, 0.8, 0), Num.i(_cfg["crash_shards"]), 2, 0.7)
	if sfx != null:
		sfx.play_at("heli_crash", ground)


func _process(delta: float) -> void:
	for fall: Fall in _falling.values():
		_fall(fall, delta)
	var still: Array[Chute] = []
	for chute: Chute in _crew:
		chute.t += delta
		var u := chute.t / chute.seconds
		if u >= 1.0:
			chute.node.queue_free()
			continue
		chute.node.position = chute.from.lerp(chute.to, u)
		chute.node.rotation.z = sin(chute.t * 2.0) * 0.15  # swinging under the canopy
		still.append(chute)
	_crew = still


## One frame of a wreck falling: its height drops slowly then fast (it falls, it is not lowered),
## it pitches nose down, rolls and spins up as it goes; its flames and smoke follow it.
func _fall(fall: Fall, delta: float) -> void:
	fall.t += delta
	var u := clampf(fall.t / fall.seconds, 0.0, 1.0)
	var bow := fall.side * sin(PI * u) * Num.f(_cfg["swing"])  # a falling arc, not a slide
	fall.node.position = (
		fall.from + fall.drift * fall.t + bow - Vector3(0, fall.from.y * u * u, 0)
	)
	fall.yaw += delta * Num.f(_cfg["spin"]) * (0.5 + u)
	var tumble := pow(u, 1.4)  # the pitch and roll build slowly, then it cartwheels
	var pitch := -deg_to_rad(Num.f(_cfg["pitch_deg"])) * tumble
	var roll := deg_to_rad(Num.f(_cfg["roll_deg"])) * tumble
	fall.node.basis = (
		Basis(Vector3.UP, fall.yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	)
	var along := Num.f(_cfg["trail_offset"])
	for k: int in fall.fires.size():
		var offset := Vector3(0, 0.5, (k - 1) * along)
		fall.fires[k].global_position = fall.node.to_global(offset)
	fall.trail.global_position = fall.node.global_position


func _end_fall(fall: Fall) -> void:
	for f: Fire in fall.fires:
		f.go_out()
	HeliFx.end_trail(fall.trail)


## Blown apart in the air: the flash, the ball of flame, the smoke, and the helicopter's own parts
## and a rain of chunks thrown out (see the header).
func _burst(node: Node3D, at: Vector3) -> void:
	HeliFx.flare(_city, at, Num.f(_cfg["flare_size"]), Num.f(_cfg["flare_seconds"]))
	_city.flash(at, BLAST, Num.f(_cfg["burst_light"]), Num.f(_cfg["burst_light_seconds"]))
	HeliFx.fireball(_city, at, _cfg)
	HeliFx.smoke_puff(_city, at + Vector3(0, 1.0, 0), _cfg)
	var fire := Fire.new(Num.f(_cfg["burst_fire"]), at.x + at.z)
	_city.add_child(fire)
	fire.global_position = at
	get_tree().create_timer(Num.f(_cfg["burst_seconds"])).timeout.connect(fire.go_out)
	_break_up(node, 1.0, true)
	_debris.shards(at, Num.i(_cfg["burst_shards"]), Num.i(_cfg["burst_burning"]))
	if sfx != null:
		sfx.play_at("heli_crash", at)


## The model's parts thrown from where they are (`reach` scales the throw; `in_air`: the body
## flies on burning, else it drops where it is and lies); a stand-in without a model has only the
## chunks.
func _break_up(node: Node3D, reach: float, in_air: bool) -> void:
	if not node is HelicopterModel:
		node.queue_free()
		return
	var parts := (node as HelicopterModel).break_up(_debris)
	for n: int in parts.size():
		var side := TAU * (n + _rng.randf()) / parts.size()
		var out := (
			Vector3(cos(side), 0.0, sin(side))
			* _rng.randf_range(Num.f(_cfg["throw_min"]), Num.f(_cfg["throw_max"]))
		)
		var vel := out * reach + Vector3(0, _rng.randf_range(2.0, Num.f(_cfg["up_max"])) * reach, 0)
		var spin := Vector3(
			_rng.randf_range(0.4, 1.0), _rng.randf_range(-1, 1), _rng.randf_range(0.4, 1.0)
		)
		var body := n == 0
		if body:  # the hull is long: it lies and rolls across the view, never end-on like a pole
			(parts[n] as Node3D).rotation.y = PI * 0.5
			spin = Vector3(0.0, spin.y * 0.3, 0.8)
		if body and not in_air:
			vel = Vector3.ZERO
			spin = Vector3.ZERO
		var fire_size := Num.f(_cfg["part_fire"]) if in_air and n % 2 == 0 else 0.0  # body, tail
		var piece := _debris.throw(parts[n], vel * (0.5 if body else 1.0), spin * 7.0, fire_size)
		piece.half = WRECK_HALF
		if n > 0:  # the rotors and the gun lie level on the street, never on edge
			piece.flat = true
			piece.lie = PI * 0.5 if n == 2 else 0.0  # (the tail rotor's disc stands, so roll it)
			piece.half = 0.3
	node.queue_free()


func _spin(node: Node3D, at: Vector3, event: Dictionary) -> void:
	if not node.is_inside_tree():
		add_child(node)  # a model the view never drew still carries the fire down
	var fall := Fall.new()
	fall.node = node
	fall.from = at
	fall.drift = Vector3(Num.f(event["dx"]), 0.0, Num.f(event["dz"]))
	fall.seconds = Num.f(event["seconds"])
	fall.side = Vector3(-fall.drift.z, 0.0, fall.drift.x).normalized()
	if fall.side.length() < 0.5:
		fall.side = Vector3.RIGHT
	for k: int in 3:  # flames along the body: nose, middle, tail
		var fire := Fire.new(Num.f(_cfg["trail_fire"]), at.x - at.z + k)
		_city.add_child(fire)
		fire.global_position = at
		fall.fires.append(fire)
	fall.trail = HeliFx.smoke_trail(_city, _cfg)
	_falling[Num.i(event["heli"])] = fall
	HeliFx.flare(_city, at, Num.f(_cfg["hit_flare"]), Num.f(_cfg["flare_seconds"]))
	_city.flash(at, CRASH_BLAST, Num.f(_cfg["hit_light"]), 0.3)
	HeliFx.smoke_puff(_city, at, _cfg, Num.f(_cfg["hit_smoke"]))
	for n: int in Num.i(event.get("crew", 0)):
		_jump(at + Vector3((n - 0.5) * 7.0, -0.5, 1.5), fall.drift)


## One crew member bailing out: a soldier hanging under a pale canopy, drifting down with the wind.
func _jump(from: Vector3, drift: Vector3) -> void:
	var voxel := Num.f(Content.section("street")["person_voxel"])
	var person := MeshInstance3D.new()
	person.mesh = VoxelPerson.dressed(
		VoxelPerson.ROOFTOP_OUTFITS[CREW_OUTFIT], VoxelPerson.Pose.RUN_A, voxel
	)
	add_child(person)
	person.add_child(_canopy())
	var seconds := from.y / Num.f(_cfg["chute_speed"])
	var chute := Chute.new()
	chute.node = person
	chute.from = from
	chute.to = Vector3(from.x, 0.0, from.z) + drift * seconds * 0.5
	chute.seconds = seconds
	_crew.append(chute)


## A voxel dome of pale fabric in alternating panels (one MultiMesh of cubes, widest at the rim),
## shroud lines down to the soldier's shoulders. It catches a little light of its own so it reads at
## night, under the bloom.
func _canopy() -> Node3D:
	var out := Node3D.new()
	var voxel := Num.f(_cfg["canopy_voxel"])
	var width := Num.f(_cfg["canopy_width"])
	var hang := Num.f(_cfg["canopy_hang"])
	var rim := roundi(width * 0.5 / voxel)
	var rise := maxi(1, roundi(rim * 0.55))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = CANOPY
	mat.emission_energy_multiplier = Num.f(_cfg["canopy_glow"])
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * voxel
	cube.material = mat
	var cells: Array[Vector3] = []
	for x: int in range(-rim, rim + 1):
		for z: int in range(-rim, rim + 1):
			for y: int in rise + 1:
				var flat := Vector2(x, z).length_squared() / float(rim * rim)
				if flat + float(y * y) / float(rise * rise) <= 1.0:
					cells.append(Vector3(x, y, z))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = cells.size()
	for n: int in cells.size():
		var cell := cells[n]
		mm.set_instance_transform(n, Transform3D(Basis(), cell * voxel))
		var panel := int(floorf((atan2(cell.z, cell.x) + PI) / (TAU / 8.0))) % 2
		mm.set_instance_color(n, CANOPY if panel == 0 else CANOPY.darkened(0.28))
	var dome := MultiMeshInstance3D.new()
	dome.multimesh = mm
	dome.position = Vector3(0, hang, 0)
	out.add_child(dome)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var from := Vector3(corner.x * width * 0.4, hang, corner.y * width * 0.4)
		out.add_child(_line(from, Vector3(0, hang * 0.45, 0), mat))
	return out


func _line(from: Vector3, to: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, from.distance_to(to))
	box.material = mat
	var line := MeshInstance3D.new()
	line.mesh = box
	line.transform = Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	return line
