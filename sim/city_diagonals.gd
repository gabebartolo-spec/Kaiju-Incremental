class_name CityDiagonals
extends RefCounted
## The city's diagonal avenues as lines (part of CityGen.map, split out to keep files small): each
## is {at, dir}, a point it passes and its direction (unit, ground plane). Pure.


## Every diagonal avenue of cfg: the first (city.diagonal_through, city.diagonal_deg), then
## city.diagonal_count - 1 more through the same point, turned evenly round the half circle
## (Carthago's spokes, D-435: they meet in the open site there, CityPlaza, which holds its round
## harbour, CityWater).
static func of(cfg: Dictionary) -> Array[Dictionary]:
	var through: Array = cfg["diagonal_through"]
	var angle := deg_to_rad(Num.f(cfg["diagonal_deg"]))
	var at := Vector2(Num.f(through[0]), Num.f(through[1]))
	var dir := Vector2(cos(angle), sin(angle))
	var out: Array[Dictionary] = [{"at": at, "dir": dir}]
	var count := Num.i(cfg["diagonal_count"])
	for k: int in range(1, count):
		out.append({"at": at, "dir": dir.rotated(PI * k / count)})
	return out


## Where a diagonal crosses x-line x (its z), and z-line z (its x).
static func at_x(diag: Dictionary, x: float) -> float:
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	return at.y + (x - at.x) * dir.y / dir.x


static func at_z(diag: Dictionary, z: float) -> float:
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	return at.x + (z - at.y) * dir.x / dir.y
