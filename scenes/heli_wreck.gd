class_name HeliWreck
extends Node3D
## How a downed helicopter looks (D-140, D-141, D-145; the sim's AirWing decides which):
## "burst" blows it apart in the air (a flash and a light, a ball of Fire's flame voxels hot at the
## core and shrinking to specks at the rim, lobed smoke rising off it, the camera kicked on that
## frame; the model's own rotors, gun and body thrown out on visible arcs, the hull burning, lit by
## its fire and trailing smoke until it lands with an impact); "spin" sets it burning and falling
## along the sim's drift, its rotors sheared off, flames along its body lit from under and a thick
## smoke trail behind it, pitching, rolling and spinning faster, crew bailing out under pale
## canopies (HeliCrew), until "heli_crashed" lands it: a flash and light, a fireball, dust and a
## ring, its body left burning; "grabbed" just takes the model away (the tentacle's throw draws the
## rest). Every look is an existing family (docs/VFX_STYLE.md): Fire, smoke, dust, flashes, debris
## (HeliFx, HeliDebris). Numbers: tuning "heli_wreck". Part of PowersView. Presentation only.

const PARTS := 4  # the model's parts: hull, main rotor, tail rotor, gun
const WRECK_HALF := 0.7  # how high the body's middle rides when it lies on the street
const BLAST := Color("ffb468")
const CRASH_BLAST := Color("ff8a3a")

## The rampage's sounds (PowersView passes its own on).
var sfx: Sfx
var _city: CityView
var _sim: RampageSim
var _cfg: Dictionary
var _debris: HeliDebris
var _crew: HeliCrew
var _rng := Seeds.make("heli_wreck")
## id -> Fall: wrecks falling.
var _falling: Dictionary = {}


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


func _init(city: CityView, sim: RampageSim) -> void:
	_city = city
	_sim = sim
	_cfg = Content.section("heli_wreck")
	_debris = HeliDebris.new(_cfg, _rng)
	_debris.landed.connect(_hull_landed)
	add_child(_debris)
	_crew = HeliCrew.new(_cfg)
	add_child(_crew)


## The sim downed helicopter `node` (its model, already off the circle) with `event`.
func downed(node: Node3D, event: Dictionary) -> void:
	node.set_meta("opacity", 1.0)  # a screen-door fade never carries on to the wreck
	node.set_meta("no_fade", true)  # and the dying helicopter is never faded again (VehicleFade)
	VehicleParts.set_opacity(node, 1.0)
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
		fall.node.global_position = Vector3(ground.x, 0.0, ground.z)  # exactly the sim's crash point
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
	# A lasting fire at the wreck: real flame tongues, less of Fire's own smoke column.
	var burning := _city.fire(
		ground, Num.f(_cfg["crash_fire"]), HeliFx.tongues(_cfg, Num.f(_cfg["crash_smoke_density"]))
	)
	burning.add_child(_firelight(Vector3(0, 2.0, 0)))  # a zoomed fire has no light of its own
	_city.fx.dust(ground + Vector3(0, 0.4, 0), scale)
	_city.fx.shockwave(ground, scale * Num.f(_cfg["crash_ring"]))
	_debris.shards(ground + Vector3(0, 0.8, 0), Num.i(_cfg["crash_shards"]), 2, 0.7)
	_hull_landed(ground)  # the same impact beat as a thrown hull's (flash, dust, ring, kick)
	_trauma("heli_crash", ground)
	if sfx != null:
		sfx.play_at("heli_crash", ground)


func _process(delta: float) -> void:
	for fall: Fall in _falling.values():
		_fall(fall, delta)


## One frame of a wreck falling: its height drops slowly then fast (it falls, it is not lowered),
## it pitches nose down, rolls and spins up as it goes; its flames and smoke follow it, and the fire
## lights its hull from under.
func _fall(fall: Fall, delta: float) -> void:
	fall.t += delta
	fall.node.position = HeliArc.point(fall.from, fall.drift, fall.side, fall.seconds, fall.t, _cfg)
	fall.node.basis = HeliArc.basis(fall.seconds, fall.t, _cfg)
	fall.yaw = HeliArc.yaw(fall.seconds, fall.t, _cfg)
	var along := Num.f(_cfg["trail_offset"])
	for k: int in fall.fires.size():
		var offset := Vector3(0, 0.5, (k - 1) * along)
		fall.fires[k].global_position = fall.node.to_global(offset)
	fall.trail.global_position = fall.node.global_position
	var flicker := 1.0 + 0.25 * sin(fall.t * 23.0) + 0.15 * sin(fall.t * 37.0)
	var glow := Color(str(_cfg["ember_light"])) * Num.f(_cfg["hull_ember"]) * flicker
	VehicleParts.set_ember(fall.node, glow)


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
	get_tree().create_timer(Num.f(_cfg["smoke_delay"])).timeout.connect(
		func() -> void: HeliFx.smoke_puff(_city, at, _cfg)  # the flames first
	)
	VehicleParts.flash(
		node,
		self,
		Num.f(_cfg["hull_flash"]),
		Num.f(_cfg["hull_flash_seconds"]),
		Num.f(_cfg["hull_char_seconds"])
	)
	_break_up(node, 1.0, true)
	_debris.shards(at, Num.i(_cfg["burst_shards"]), Num.i(_cfg["burst_burning"]))
	_trauma("heli_burst", at)
	if sfx != null:
		sfx.play_at("heli_crash", at)


## The burning hull met the street: a short flash and light, the street's own dust and its ring, the
## camera kicked. Its flames are already burning (they rode it down).
func _hull_landed(at: Vector3) -> void:
	var ground := Vector3(at.x, 0.0, at.z)
	HeliFx.flare(_city, ground + Vector3(0, 1.2, 0), Num.f(_cfg["land_flare"]), 0.1)
	_city.flash(
		ground + Vector3(0, 1.5, 0),
		CRASH_BLAST,
		Num.f(_cfg["land_light"]),
		Num.f(_cfg["land_light_seconds"])
	)
	_city.fx.dust(ground + Vector3(0, 0.4, 0), Num.f(_cfg["land_dust"]))
	_city.fx.shockwave(ground, Num.f(_cfg["land_ring"]))
	_trauma("heli_land", ground)


## The camera's kick for `kind` (tuning camera_shake.sources) from a hit at `at`; the rampage owns
## the shake (PowersView's parent), a view without one just skips it.
func _trauma(kind: String, at: Vector3) -> void:
	var rampage := get_parent().get_parent() as Rampage if get_parent() != null else null
	if rampage != null:
		rampage.shake.kick(deg_to_rad(Num.f(_cfg["kick_deg"][kind])))  # one kick, on this frame
		rampage.add_trauma(rampage.shake.source(kind), at)


## The model's parts thrown from where they are (`reach` scales the throw; `in_air`: the body
## flies on burning, else it drops where it is and lies); a stand-in without a model has only the
## chunks.
func _break_up(node: Node3D, reach: float, in_air: bool) -> void:
	if not node is HelicopterModel:
		node.queue_free()
		return
	var parts := (node as HelicopterModel).break_up(_debris)
	for n: int in parts.size():
		if parts[n] != null:
			_throw_part(parts[n], n, reach, in_air)
	node.queue_free()


## One of the model's parts (0 hull, 1 main rotor, 2 tail rotor, 3 gun) thrown from where it is.
func _throw_part(part: Node3D, n: int, reach: float, in_air: bool) -> void:
	var side := TAU * (n + _rng.randf()) / PARTS
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
		part.rotation.y = PI * 0.5
		spin = Vector3(0.0, spin.y * 0.3, 0.8)
	if body and not in_air:
		vel = Vector3.ZERO
		spin = Vector3.ZERO
	if body and in_air:
		vel.y = -1.0  # the hull drops from the first frame: no hover at the top of a throw
	var burning := body and in_air  # the hull flies on burning: flames, smoke, firelight, an impact
	var fire_size := Num.f(_cfg["hull_fire"]) if burning else 0.0
	var piece := _debris.throw(part, vel * (0.5 if body else 1.0), spin * 7.0, fire_size)
	if burning:
		_debris.make_heavy(piece)
	piece.half = WRECK_HALF
	if n == 1 or n == 2:  # the rotors burn away at once: nothing plus-shaped is left lying
		piece.vanish = Num.f(_cfg["rotor_vanish"])
	if n > 0:  # the gun lies level on the street, never on edge
		piece.flat = true
		piece.lie = PI * 0.5 if n == 2 else 0.0  # (the tail rotor's disc stands, so roll it)
		piece.half = 0.3


func _spin(node: Node3D, at: Vector3, event: Dictionary) -> void:
	if not node.is_inside_tree():
		add_child(node)  # a model the view never drew still carries the fire down
	VehicleParts.set_opacity(node, 1.0)  # no longer fading for the camera: a solid wreck
	VehicleParts.flash(node, self, 0.0, 0.1, Num.f(_cfg["hull_char_seconds"]))  # it chars, no flash
	if node is HelicopterModel:  # the rotors shear off at the first blow: no plus sign in the air
		var rotors := (node as HelicopterModel).shed_rotors(_debris)
		for n: int in rotors.size():
			_throw_part(rotors[n], n + 1, 1.0, true)
	var fall := Fall.new()
	fall.node = node
	fall.from = at
	fall.drift = Vector3(Num.f(event["dx"]), 0.0, Num.f(event["dz"]))
	fall.seconds = Num.f(event["seconds"])
	fall.side = Vector3(-fall.drift.z, 0.0, fall.drift.x).normalized()
	if fall.side.length() < 0.5:
		fall.side = Vector3.RIGHT
	for k: int in 3:  # flames along the body: nose, middle, tail
		var fire := HeliFx.riding_fire(
			Num.f(_cfg["trail_fire"]), at.x - at.z + k, _cfg, Num.f(_cfg["hull_smoke"])
		)
		_city.add_child(fire)
		fire.global_position = at
		fall.fires.append(fire)
	node.add_child(_firelight(Vector3(0, 1.0, 0), 14.0))  # the burning hull lights itself
	fall.trail = HeliFx.smoke_trail(_city, _cfg)
	_falling[Num.i(event["heli"])] = fall
	HeliFx.flare(_city, at, Num.f(_cfg["hit_flare"]), Num.f(_cfg["flare_seconds"]))
	_city.flash(at, CRASH_BLAST, Num.f(_cfg["hit_light"]), 0.3)
	HeliFx.smoke_puff(_city, at, _cfg, Num.f(_cfg["hit_smoke"]))
	_trauma("heli_burst", at)
	for n: int in Num.i(event.get("crew", 0)):
		_crew.jump(at + fall.side * (5.0 + n * 3.5) + Vector3(0, 2.0, 0), fall.drift)


## A pooled orange light that rides a burning wreck (`reach` m).
func _firelight(at: Vector3, reach := 16.0) -> PooledLight:
	var glow := PooledLight.new("fire")
	glow.light_color = CRASH_BLAST
	glow.omni_range = reach
	glow.set_energy(Num.f(_cfg["hull_light"]))
	glow.position = at
	return glow
