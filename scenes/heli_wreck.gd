class_name HeliWreck
extends Node3D
## How a downed helicopter looks (D-140, D-141, D-145; the sim's AirWing decides which):
## "burst" blows it apart in the air (a flash, a short burst of the game's Fire, its tan body and
## rotor in pieces raining onto the street); "spin" sets it burning and spinning down along the
## sim's drift, trailing Fire's flames and smoke, crew parachuting off it, until "heli_crashed"
## turns it into a ground fire, debris, dust and a ripple where it hits; "grabbed" just takes the
## model away (the tentacle's throw draws the rest). Every look is an existing family
## (docs/VFX_STYLE.md): Fire, debris, dust, flashes. Numbers: tuning "heli_wreck". Part of
## PowersView. Presentation only.

const CREW_OUTFIT := 2  # VoxelPerson.ROOFTOP_OUTFITS: a soldier in drab
const CANOPY := Color("c9c2b0")

## The rampage's sounds (PowersView passes its own on).
var sfx: Sfx
var _city: CityView
var _sim: RampageSim
var _cfg: Dictionary
## id -> Fall: wrecks spinning down.
var _falling: Dictionary = {}
var _crew: Array[Chute] = []


## A wreck spinning down along the sim's drift, trailing its fire.
class Fall:
	var node: Node3D
	var fire: Fire
	var from: Vector3
	var drift: Vector3
	var seconds: float
	var t := 0.0


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


## The sim downed helicopter `node` (its model, already off the circle) with `event`.
func downed(node: Node3D, event: Dictionary) -> void:
	var at := Vector3(Num.f(event["x"]), _sim.air.altitude(), Num.f(event["z"]))
	match str(event.get("fate", "burst")):
		"grabbed":
			node.queue_free()
		"spin":
			_spin(node, at, event)
		_:
			node.queue_free()
			_burst(at)


## A spinning wreck reached the street at the sim's crash point.
func crashed(event: Dictionary) -> void:
	var id := Num.i(event["heli"])
	var ground := Vector3(Num.f(event["x"]), 0.0, Num.f(event["z"]))
	if _falling.has(id):
		var fall: Fall = _falling[id]
		fall.node.queue_free()
		fall.fire.go_out()
		_falling.erase(id)
	var scale := Num.f(_cfg["crash_scale"])
	_city.flash(ground + Vector3(0, 2.0, 0), Color("ff8a3a"), Num.f(_cfg["crash_light"]), 0.6)
	_city.fire(ground, Num.f(_cfg["crash_fire"]))
	_city.fx.dust(ground + Vector3(0, 0.4, 0), scale)
	_city.fx.shockwave(ground, scale * 1.5)
	_pieces(ground + Vector3(0, 0.8, 0), Num.i(_cfg["crash_pieces"]), 1.0)
	if sfx != null:
		sfx.play_at("heli_crash", ground)


func _process(delta: float) -> void:
	for fall: Fall in _falling.values():
		fall.t += delta
		var u := clampf(fall.t / fall.seconds, 0.0, 1.0)
		# Height drops slowly then fast (it falls, it is not lowered); it spins up as it goes.
		fall.node.position = fall.from + fall.drift * fall.t - Vector3(0, fall.from.y * u * u, 0)
		fall.node.rotation.y += delta * Num.f(_cfg["spin"]) * (0.5 + u)
		fall.node.rotation.z = lerpf(0.0, deg_to_rad(Num.f(_cfg["roll_deg"])), u)
		fall.fire.global_position = fall.node.global_position
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


## Blown apart in the air: a flash, a short burst of the game's own flames and smoke, and the
## body and rotor raining down in pieces.
func _burst(at: Vector3) -> void:
	_city.flash(at, Color("ffb468"), Num.f(_cfg["burst_light"]), 0.4)
	var fire := Fire.new(Num.f(_cfg["burst_fire"]), at.x + at.z)
	_city.add_child(fire)
	fire.global_position = at
	get_tree().create_timer(Num.f(_cfg["burst_seconds"])).timeout.connect(fire.go_out)
	_pieces(at, Num.i(_cfg["burst_pieces"]), 2.0)
	if sfx != null:
		sfx.play_at("heli_crash", at)


func _spin(node: Node3D, at: Vector3, event: Dictionary) -> void:
	var seconds := Num.f(event["seconds"])
	var fire := Fire.new(Num.f(_cfg["trail_fire"]), at.x - at.z)  # flames and a smoke trail
	_city.add_child(fire)
	fire.global_position = at
	if not node.is_inside_tree():
		add_child(node)  # a model the view never drew still carries the fire down
	var fall := Fall.new()
	fall.node = node
	fall.fire = fire
	fall.from = at
	fall.drift = Vector3(Num.f(event["dx"]), 0.0, Num.f(event["dz"]))
	fall.seconds = seconds
	_falling[Num.i(event["heli"])] = fall
	_city.flash(at, Color("ff8a3a"), Num.f(_cfg["hit_light"]), 0.3)
	for n: int in Num.i(event.get("crew", 0)):
		_jump(at + Vector3(n - 0.5, -0.5, 0.5), fall.drift)


## One crew member bailing out: a soldier under a pale canopy drifting down with the wind.
func _jump(from: Vector3, drift: Vector3) -> void:
	var voxel := Num.f(Content.section("street")["person_voxel"])
	var mesh := VoxelPerson.dressed(
		VoxelPerson.ROOFTOP_OUTFITS[CREW_OUTFIT], VoxelPerson.Pose.WALK_A, voxel
	)
	var person := MeshInstance3D.new()
	person.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CANOPY
	var cells := Num.f(_cfg["canopy_cells"])
	for k: int in 3:  # an arched canopy: a crown panel and two lower, tilted side panels
		var side := k - 1
		var panel := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(voxel * cells / 3.0, voxel * 1.5, voxel * cells * 0.6)
		box.material = mat
		panel.mesh = box
		panel.position = Vector3(side * voxel * cells / 3.0, voxel * (18.0 - 2.0 * absf(side)), 0)
		panel.rotation.z = -side * 0.45
		person.add_child(panel)
	add_child(person)
	var seconds := from.y / Num.f(_cfg["chute_speed"])
	var to := Vector3(from.x, 0.0, from.z) + drift * seconds * 0.5
	var chute := Chute.new()
	chute.node = person
	chute.from = from
	chute.to = to
	chute.seconds = seconds
	_crew.append(chute)


## Pieces of the helicopter thrown out from `at`, falling as real debris.
func _pieces(at: Vector3, count: int, up: float) -> void:
	for n: int in count:
		var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * n / maxf(1.0, count))
		var color := HelicopterModel.TAN if n % 3 != 0 else Color("3a3d40")
		_city.debris(at + out * 0.4, color, out + Vector3(0, up, 0))
