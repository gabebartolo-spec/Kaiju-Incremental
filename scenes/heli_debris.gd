class_name HeliDebris
extends Node3D
## Pieces of a wrecked helicopter thrown through the air (HeliWreck): the model's own parts (rotors,
## gun, body) and lit tan and charcoal chunks in the heli's colours, each tumbling on a visible
## arc, a few trailing Fire, then bouncing once, lying on the street and fading away. Cosmetic:
## nothing here is a physics body or decides an outcome (D-094). Numbers: tuning "heli_wreck".

## A heavy piece (the burning hull) met the street at `at`: the impact beat (HeliWreck).
signal landed(at: Vector3)

const CHARCOAL := Color("3a3d40")
const SCORCH := Color("5a4a36")
const COLORS: Array[Color] = [HelicopterModel.TAN, CHARCOAL, SCORCH, HelicopterModel.TAN]
## A piece that lands faster than this (m/s down) bounces once.
const BOUNCE_BELOW := -3.0
const BOUNCE_KEEP := 0.3

var _cfg: Dictionary
var _rng: RandomNumberGenerator
var _pieces: Array[Piece] = []


## One thing in the air or lying on the street.
class Piece:
	var node: Node3D
	var vel: Vector3
	var spin: Vector3
	var fire: Fire
	var half := 0.2  # how high its middle rides above the street when it lies there
	var lie := 0.0  # a long part (the body, a rotor) lies on its side at this roll; 0: any face
	var flat := false  # a part that lies level (rotors, gun) at roll `lie`, never on edge
	var rest := -1.0  # seconds since it came to rest (-1: still flying)
	var fire_left := 0.0
	var vanish := -1.0  # a part that burns away this many seconds after it is thrown (-1: stays)
	var age := 0.0
	var heavy := false  # the burning hull: smoke trail, firelight on it, an impact when it lands
	var trail: GPUParticles3D
	var struck := false  # a heavy piece has met the street


func _init(cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_rng = rng


## Throws `node` (in the tree, its world transform kept) with `vel`, tumbling at `spin` rad/s; a
## `fire_size` above 0 sets it burning (flames that ride it). Set the piece's `half`: its middle's
## height lying down.
func throw(node: Node3D, vel: Vector3, spin: Vector3, fire_size := 0.0) -> Piece:
	var piece := Piece.new()
	if not node is MeshInstance3D:  # a model part (voxels): chunks and blades land on any face
		piece.lie = _rng.randf_range(0.7, 1.4) * (1.0 if _rng.randf() < 0.5 else -1.0)
	piece.node = node
	piece.vel = vel
	piece.spin = spin
	if fire_size > 0.0:
		var smoke := Num.f(_cfg["piece_smoke"])
		piece.fire = HeliFx.riding_fire(fire_size, _rng.randf() * 10.0, _cfg, smoke)
		add_child(piece.fire)
		piece.fire.global_position = node.global_position
	_pieces.append(piece)
	return piece


## Makes a thrown piece heavy (the burning hull): it trails smoke, is lit from under by its own fire
## and its landing is an impact (`landed`).
func make_heavy(piece: Piece) -> void:
	piece.heavy = true
	piece.trail = HeliFx.smoke_trail(self, _cfg, Num.f(_cfg["piece_trail"]))
	piece.trail.global_position = piece.node.global_position
	piece.trail.emitting = false  # no smoke in the middle of the flames: it starts once they have risen
	var trail := piece.trail
	get_tree().create_timer(Num.f(_cfg["trail_delay"])).timeout.connect(
		func() -> void:
			if is_instance_valid(trail):
				trail.emitting = true
	)


## `count` chunks from `at`, thrown out and up at the tuning's speeds; `burning` of them carry a
## small Fire. Sizes run from a splinter to a block; the rotor blades are the model's own.
func shards(at: Vector3, count: int, burning: int, reach := 1.0) -> void:
	for n: int in count:
		var side := TAU * (n + _rng.randf()) / maxf(1.0, count)
		var out := (
			Vector3(cos(side), 0.0, sin(side))
			* _rng.randf_range(Num.f(_cfg["throw_min"]), Num.f(_cfg["throw_max"]))
		)
		var vel := (
			out * reach
			+ Vector3(0, _rng.randf_range(Num.f(_cfg["up_min"]), Num.f(_cfg["up_max"])) * reach, 0)
		)
		var size := Vector3.ONE * _rng.randf_range(0.25, 0.7)
		var piece := _box(size, COLORS[n % COLORS.size()])
		add_child(piece)
		piece.global_position = at + out.normalized() * 0.5
		var fire_size := Num.f(_cfg["shard_fire"]) if n < burning else 0.0
		throw(piece, vel, _spin(_rng.randf_range(4.0, 12.0)), fire_size).half = size.y * 0.5


func _process(delta: float) -> void:
	var gravity := Num.f(_cfg["gravity"])
	var kept: Array[Piece] = []
	for piece: Piece in _pieces:
		if _step(piece, delta, gravity):
			kept.append(piece)
	_pieces = kept


## Moves one piece; false once it has faded away and been freed.
func _step(piece: Piece, delta: float, gravity: float) -> bool:
	var node := piece.node
	if not is_instance_valid(node):
		_put_out(piece)
		return false
	piece.age += delta
	if piece.vanish >= 0.0 and piece.age > piece.vanish and _burn_away(piece):
		return false
	if piece.rest < 0.0:
		piece.vel.y -= gravity * delta
		node.global_position += piece.vel * delta
		node.rotation += piece.spin * delta
		if node.global_position.y <= piece.half and piece.vel.y < 0.0:
			_land(piece)
	elif _lie(piece, delta):
		return false
	if piece.fire != null and not piece.fire.is_out():
		piece.fire.global_position = node.global_position
	if piece.heavy:
		_burn(piece)
	return true


## A heavy piece burning: its smoke trail follows it, and the fire under it lights its underside
## (flickering) so it reads as a helicopter, not a black shape, while it falls and lies.
func _burn(piece: Piece) -> void:
	if piece.trail != null:
		piece.trail.global_position = piece.node.global_position
	var lit := piece.fire != null and not piece.fire.is_out()
	var flicker := 1.0 + 0.25 * sin(piece.age * 23.0) + 0.15 * sin(piece.age * 37.0)
	var glow := Color(str(_cfg["ember_light"])) * Num.f(_cfg["hull_ember"]) * flicker
	VehicleParts.set_ember(piece.node, glow if lit else Color.BLACK)


## A part that burns away (a rotor) shrinks to nothing; true once it is gone and freed.
func _burn_away(piece: Piece) -> bool:
	var left := 1.0 - (piece.age - piece.vanish) / Num.f(_cfg["rotor_fade"])
	piece.node.scale = Vector3.ONE * maxf(0.0, left)
	if left > 0.0:
		return false
	piece.node.queue_free()
	_put_out(piece)
	return true


## A piece at rest: its fire goes out, then it shrinks away; true once it is gone and freed.
func _lie(piece: Piece, delta: float) -> bool:
	piece.rest += delta
	var seconds := Num.f(_cfg["rest_seconds"])
	var fade := Num.f(_cfg["fade_seconds"])
	if piece.fire != null and piece.rest > seconds * 0.6:
		_put_out(piece)
	if piece.rest > seconds:
		piece.node.scale = Vector3.ONE * maxf(0.0, 1.0 - (piece.rest - seconds) / fade)
	if piece.rest <= seconds + fade:
		return false
	piece.node.queue_free()
	_put_out(piece)
	return true


func _land(piece: Piece) -> void:
	var node := piece.node
	node.global_position.y = piece.half
	if piece.heavy and not piece.struck:
		piece.struck = true
		landed.emit(node.global_position)
		if piece.trail != null:
			HeliFx.end_trail(piece.trail)
			piece.trail = null
	if piece.vel.y < BOUNCE_BELOW:
		piece.vel = Vector3(piece.vel.x * 0.5, -piece.vel.y * BOUNCE_KEEP, piece.vel.z * 0.5)
		piece.spin *= 0.5
		return
	piece.vel = Vector3.ZERO
	piece.spin = Vector3.ZERO
	piece.rest = 0.0
	if piece.lie != 0.0 or piece.flat:
		node.rotation.x = 0.0  # a long part never stands on end: level, rolled onto its side
		node.rotation.z = piece.lie
		return
	node.rotation.x = roundf(node.rotation.x / (PI * 0.5)) * PI * 0.5  # lies flat on a face
	node.rotation.z = roundf(node.rotation.z / (PI * 0.5)) * PI * 0.5


func _put_out(piece: Piece) -> void:
	if piece.fire != null:
		piece.fire.go_out()
		piece.fire = null
	if piece.trail != null:
		HeliFx.end_trail(piece.trail)
		piece.trail = null


func _spin(rate: float) -> Vector3:
	return Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * rate


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi
