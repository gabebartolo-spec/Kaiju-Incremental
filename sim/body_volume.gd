class_name BodyVolume
extends RefCounted
## The kaiju's body volume (BodyContact's discs) asked where it touches the city: how far it
## reaches, which standing buildings it can touch along a move, and every standing chunk inside it
## at a pose. Part of BodyContact; pure, no randomness.

## A chunk is one sim unit across: its centre is this far from its faces.
const CHUNK_HALF := 0.5

## The discs at body scale 1, in design units: [forward offset, radius, bottom, top].
var discs: Array = []
var sim: RampageSim
var cfg: Dictionary


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## How far the body reaches from its position, world units.
func reach() -> float:
	var reach := 0.0
	for d: Array in discs:
		reach = maxf(reach, absf(Num.f(d[0])) + Num.f(d[1]))
	return reach * sim.body_scale()


## Standing buildings the body can touch moving from `from` to `to`: one pass over the city.
func near(from: Vector2, to: Vector2, reach: float) -> Array[int]:
	var lo := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2.ONE * reach
	var hi := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2.ONE * reach
	var out: Array[int] = []
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.frame.alive_count == 0:
			continue
		if b.x + b.w * 0.5 < lo.x or b.x - b.w * 0.5 > hi.x:
			continue
		if b.z + b.d * 0.5 < lo.y or b.z - b.d * 0.5 > hi.y:
			continue
		out.append(i)
	return out


func collect(pos: Vector2, facing: Vector2, into: Dictionary, near: Array[int]) -> void:
	var s := sim.body_scale()
	var skin := Num.f(cfg["skin"])
	for d: Array in discs:
		var centre := pos + facing * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s - skin
		if r <= 0.0:
			continue
		var y_lo := sim.stand_y + Num.f(d[2]) * s + skin
		var y_hi := sim.stand_y + Num.f(d[3]) * s - skin
		for i: int in near:
			var b := sim.buildings[i]
			if absf(b.x - centre.x) > b.w * 0.5 + r or absf(b.z - centre.y) > b.d * 0.5 + r:
				continue
			# Local cell ranges the disc's square can touch.
			var x0 := maxi(0, floori(centre.x - r - (b.x - b.w * 0.5)))
			var x1 := mini(b.w - 1, floori(centre.x + r - (b.x - b.w * 0.5)))
			var z0 := maxi(0, floori(centre.y - r - (b.z - b.d * 0.5)))
			var z1 := mini(b.d - 1, floori(centre.y + r - (b.z - b.d * 0.5)))
			var y0 := maxi(0, floori(y_lo))
			var y1 := mini(b.height - 1, ceili(y_hi) - 1)
			for x: int in range(x0, x1 + 1):
				for z: int in range(z0, z1 + 1):
					var p := b.chunk_world(Vector3i(x, 0, z))
					var gap := Vector2(
						maxf(absf(p.x - centre.x) - CHUNK_HALF, 0.0),
						maxf(absf(p.z - centre.y) - CHUNK_HALF, 0.0)
					)
					if gap.length() >= r:
						continue
					for y: int in range(y0, y1 + 1):
						var c := Vector3i(x, y, z)
						if b.frame.alive(c):
							if not into.has(i):
								into[i] = {}
							var cells: Dictionary = into[i]
							cells[c] = true
