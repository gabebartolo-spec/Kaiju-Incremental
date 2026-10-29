class_name CityPort
extends RefCounted
## The working port's buildings (D-381; the director's port board picks 2026-10-29: A2
## ship-to-shore cranes, B1 container stacks, C1 quay sheds): pool models of district "port", role
## "fixed" (tools/port/build_port.py), stood at the same spots in every city (city "harbour"
## "port"), never drawn by CityPool. Like every block they stand only inside the real band
## (CityBand.real). Pure.


## The port's layout entries for this stage (CityPool's entry shape, palette 0, "fixed": true);
## [] with no front, no port list or the pool off.
static func entries(plan: Dictionary, cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pool := CityPool.rows(cfg)
	if not plan.has("harbour") or pool.is_empty():
		return out
	var h: Dictionary = cfg["harbour"]
	var port: Dictionary = h.get("port", {})
	for spec: Array in port.get("at", []):
		var row: Dictionary = pool.get(str(spec[0]), {})
		if not row.has("w"):
			continue
		var v := {"facing": Num.i(spec[3]), "mirror": spec[4] == true, "stretch": 0}
		var dims := ModelVariant.size(row, v)
		var at := Vector2(Num.f(spec[1]), Num.f(spec[2]))
		var size := Vector2(dims.x, dims.z)
		if not CityBand.real(Rect2(at - size * 0.5, size), cfg):
			continue
		(
			out
			. append(
				{
					"x": at.x,
					"z": at.y,
					"w": dims.x,
					"d": dims.z,
					"h": dims.y,
					"tier": CityGen.tier_for_height(dims.y, cfg),
					"style": 0,
					"model": str(spec[0]),
					"facing": v["facing"],
					"mirror": v["mirror"],
					"stretch": 0,
					"palette": 0,
					"fixed": true,
				}
			)
		)
	return out
