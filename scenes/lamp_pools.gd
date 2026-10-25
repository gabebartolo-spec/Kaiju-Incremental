class_name LampPools
extends MultiMeshInstance3D
## The warm pools street lamps lay on the road and pavement at night (director 2026-10-25, the night
## roads: real night streets are lit in pools under the lamps). One flat disc per lamp, drawn
## additively a little over the ground (lamp_pool.gdshader); the pools carry the ground's own grain.
## The look's "ground_lamp_pool" is the strength (0 by day: no discs at all). Presentation only.

const SHADER := preload("res://scenes/lamp_pool.gdshader")
const RADIUS := 4.0  # a lamp's reach on the ground (m)
const LIFT := 0.13  # over the pavement (0.1), under everything that stands on it


func _init(spots: Array[Vector2]) -> void:
	var strength := Look.value("ground_lamp_pool")
	if strength <= 0.0 or spots.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * RADIUS * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("pool", strength)
	mat.set_shader_parameter("radius", RADIUS)
	GroundKit.apply_look(mat, Num.i(Content.section("city")["map_seed"]))
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = spots.size()
	for i: int in spots.size():
		mm.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, Vector3(spots[i].x, LIFT, spots[i].y))
		)
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	name = "LampPools"
