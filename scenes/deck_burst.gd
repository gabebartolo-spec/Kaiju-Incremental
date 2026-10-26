class_name DeckBurst
extends Node3D
## The bay's decks the kaiju bursts up through at the start of a run (Emergence.burst; director
## 2026-10-21, "burst through": he rises up through the bridge deck and breaks it, the street grid
## stays whole). The holes are open from the first frame, so no piece pops out of the shot at the
## break; the sim's "deck_burst" throws asphalt and stone fragments and dust up from them. Part
## of CityGround; the deck around each hole is CityRiver.decks_after. Presentation only.

const CHUNKS_PER_M2 := 1.2  # fragments thrown per square metre of broken deck
const MAX_CHUNKS := 60  # per hole
const THROW_UP := 1.5  # how much more up than sideways the fragments fly

var _holes: Array[Rect2]  # east-west decks' holes, then north-south ones
var _asphalt: Color
var _stone: Color


func _init(holes: Array[Rect2], holes_ns: Array[Rect2], asphalt: Color, stone: Color) -> void:
	_holes = holes.duplicate()
	_holes.append_array(holes_ns)
	_asphalt = asphalt
	_stone = stone


## The deck breaks: fragments fly up and out from the hole, dust rises.
func burst(debris: DebrisField, fx: Fx, rng: RandomNumberGenerator) -> void:
	for hole: Rect2 in _holes:
		var centre := hole.get_center()
		var count := mini(MAX_CHUNKS, ceili(hole.get_area() * CHUNKS_PER_M2))
		for k: int in count:
			var x := rng.randf_range(hole.position.x, hole.end.x)
			var z := rng.randf_range(hole.position.y, hole.end.y)
			var out := Vector3(signf(x - centre.x), THROW_UP, signf(z - centre.y)).normalized()
			debris.spawn(Vector3(x, 0.2, z), _asphalt if k % 3 else _stone, out)
		fx.dust(Vector3(centre.x, 0.3, centre.y), maxf(hole.size.x, hole.size.y) * 0.5)
