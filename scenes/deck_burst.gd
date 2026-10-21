class_name DeckBurst
extends Node3D
## The pieces of the bay's decks the kaiju bursts up through at the start of a run
## (Emergence.burst; director 2026-10-21, "burst through": he rises up through the bridge deck
## and breaks it, the street grid stays whole). Drawn whole until the sim's "deck_burst", then
## gone in a spray of asphalt and stone fragments and a dust cloud. Part of CityGround; the
## deck around each hole is CityRiver.decks_after. Presentation only: the sim decides the holes.

const CHUNKS_PER_M2 := 1.2  # fragments thrown per square metre of broken deck
const MAX_CHUNKS := 60  # per hole
const THROW_UP := 1.5  # how much more up than sideways the fragments fly

var _holes: Array[Rect2]
var _asphalt: Color
var _stone: Color
var _pieces: Array[MeshInstance3D] = []


func _init(holes: Array[Rect2], asphalt: Color, stone: Color) -> void:
	_holes = holes
	_asphalt = asphalt
	_stone = stone


func _ready() -> void:
	var rail := CityGround.PARAPET
	for hole: Rect2 in _holes:
		_box(hole, Vector2(0.001, 0.5), _asphalt)
		for edge: float in [0.0, 1.0]:
			var z := hole.position.y + (hole.size.y - rail.y) * edge
			_box(Rect2(hole.position.x, z, hole.size.x, rail.y), Vector2(rail.x, 1.0), _stone)


## The deck breaks: its pieces vanish, fragments fly up and out from the hole, dust rises.
func burst(debris: DebrisField, fx: Fx, rng: RandomNumberGenerator) -> void:
	for piece: MeshInstance3D in _pieces:
		piece.visible = false
	for hole: Rect2 in _holes:
		var centre := hole.get_center()
		var count := mini(MAX_CHUNKS, ceili(hole.get_area() * CHUNKS_PER_M2))
		for k: int in count:
			var x := rng.randf_range(hole.position.x, hole.end.x)
			var z := rng.randf_range(hole.position.y, hole.end.y)
			var out := Vector3(signf(x - centre.x), THROW_UP, signf(z - centre.y)).normalized()
			debris.spawn(Vector3(x, 0.2, z), _asphalt if k % 3 else _stone, out)
		fx.dust(Vector3(centre.x, 0.3, centre.y), maxf(hole.size.x, hole.size.y) * 0.5)


## A box covering rect (x, z); y: (top, thickness).
func _box(rect: Rect2, y: Vector2, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(rect.size.x, y.y, rect.size.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	box.material = mat
	mi.mesh = box
	var mid := rect.get_center()
	mi.position = Vector3(mid.x, y.x - y.y * 0.5, mid.y)
	add_child(mi)
	_pieces.append(mi)
