class_name CityShore
extends RefCounted
## The sand shore the kaiju climbs out of the river on (CityRiver.shore; director 2026-10-21 #17:
## "perhaps make a small shoreline that he can embark upon"): one sloped slab of sand with a
## grain of voxel-size speckles from the river's floor up to the street across the bay's
## city-side edge, where the quay wall is open.
## Part of CityGround. Presentation only: the sim's Emergence climbs the same slope
## (CityRiver.floor_at).

const THICK := 0.4  # the slab's depth under its sloped top
const OVERLAP := 0.3  # it runs this far onto the street and under the river's floor
const CELL := 0.125  # a grain of sand is one city voxel (building voxels: 8 to the unit)
const GRAIN := 0.065  # how far a grain's shade strays from the sand's (share of its lightness)
const LIFT := 0.003  # the grain sheet floats this far over the slab


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
	var length := top.distance_to(foot)
	var basis := Basis(Vector3.RIGHT * sand.size.x, up * THICK, down * length)
	var centre := (top + foot) * 0.5 - up * THICK * 0.5
	var colour := Look.color("sand")
	ground._slabs.append({"t": Transform3D(basis, centre), "c": colour})
	ground.add_child(_grain(colour, sand.size.x, length, (top + foot) * 0.5 + up * LIFT, down))


## The slab's sloped top: a sheet of voxel-size grains, each a slightly different shade of sand
## (nearest filtered, so each stays a hard-edged square like the city's cubes).
static func _grain(
	colour: Color, width: float, length: float, at: Vector3, down: Vector3
) -> MeshInstance3D:
	var img := Image.create(ceili(width / CELL), ceili(length / CELL), false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	for y: int in img.get_height():
		for x: int in img.get_width():
			img.set_pixel(x, y, colour.lightened(rng.randf_range(-GRAIN, GRAIN)))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var basis := Basis(Vector3.RIGHT * width, down * length, Vector3.RIGHT.cross(down))
	mi.transform = Transform3D(basis, at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
