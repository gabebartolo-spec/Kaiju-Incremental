class_name CityShore
extends RefCounted
## The sand shore the kaiju climbs out of the river on (CityRiver.shore; director 2026-10-21 #17:
## "perhaps make a small shoreline that he can embark upon"): one sloped slab of sand from the
## river's floor up to the street across the bay's city-side edge, where the quay wall is open.
## Part of CityGround. Presentation only: the sim's Emergence climbs the same slope
## (CityRiver.floor_at).

const THICK := 0.4  # the slab's depth under its sloped top
const OVERLAP := 0.3  # it runs this far onto the street and under the river's floor


static func draw(ground: CityGround, plan: Dictionary, cfg: Dictionary, depth: float) -> void:
	var sand := CityRiver.shore(plan, cfg)
	if not sand.has_area():
		return
	var top := Vector3(sand.get_center().x, CityGround.PAVE_TOP, sand.position.y)
	var foot := Vector3(top.x, -depth, sand.end.y)
	var down := (foot - top).normalized()
	top -= down * OVERLAP
	foot += down * OVERLAP
	var up := Vector3.RIGHT.cross(down).normalized()
	if up.y < 0.0:
		up = -up
	var basis := Basis(Vector3.RIGHT * sand.size.x, up * THICK, down * top.distance_to(foot))
	var centre := (top + foot) * 0.5 - up * THICK * 0.5
	ground._into.append({"t": Transform3D(basis, centre), "c": Look.color("sand")})
