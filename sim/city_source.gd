class_name CitySource
extends RefCounted
## Where the city comes from: the city config's "district" names a baked real district
## (CityDistrict, data/cities/<district>.json); empty means the seeded generic city (CityGen).
## Callers ask here, never CityGen or CityDistrict directly, so a new district slots in by
## adding its file and naming it.


static func district(cfg: Dictionary) -> String:
	return str(cfg.get("district", ""))


static func is_real(cfg: Dictionary) -> bool:
	return district(cfg) != ""


## The buildings of the playable city: x, z, w, d, h, tier, style each.
static func buildings(rng: RandomNumberGenerator, cfg: Dictionary) -> Array[Dictionary]:
	if is_real(cfg):
		return CityDistrict.buildings(district(cfg), cfg)
	return CityGen.generate(rng, cfg)


## The destructible rect, centred on the origin.
static func play(cfg: Dictionary) -> Rect2:
	if is_real(cfg):
		return CityDistrict.play(district(cfg))
	var half := CityGen.half_extent(cfg)
	return Rect2(-half, -half, half * 2.0, half * 2.0)


## Where the kaiju starts.
static func start(cfg: Dictionary) -> Vector2:
	if is_real(cfg):
		return CityDistrict.start(district(cfg))
	return Vector2(0.0, CityGen.half_extent(cfg) + Num.f(cfg["spacing"]))


## How far past the playable rect the kaiju may walk.
static func margin(cfg: Dictionary) -> float:
	if is_real(cfg):
		return Num.f(cfg["district_margin"])
	return Num.f(cfg["spacing"]) * 2.0
