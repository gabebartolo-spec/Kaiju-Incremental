class_name CreasePass
extends MeshInstance3D
## The screen-space crease pass (crease.gdshader): a full-screen quad that darkens depth and
## normal breaks. Built from the look's crease_* values; returns null when crease_strength is 0,
## so the look can switch it off in data.

const SHADER := preload("res://scenes/crease.gdshader")
const KEYS := {
	"strength": "crease_strength",
	"radius": "crease_radius",
	"depth_step": "crease_depth_step",
	"normal_step": "crease_normal_step",
	"fade_near": "crease_fade_near",
	"fade_far": "crease_fade_far",
}
## Drawn before every other transparent thing, so smoke, fire and effects stay on top.
const FIRST := Material.RENDER_PRIORITY_MIN
## The quad is placed in clip space by its shader; it must never be culled.
const NEVER_CULLED := AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))


static func make() -> CreasePass:
	if Look.value("crease_strength") <= 0.0:
		return null
	var pass_node := CreasePass.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	pass_node.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.render_priority = FIRST
	for param: String in KEYS:
		mat.set_shader_parameter(param, Look.value(str(KEYS[param])))
	pass_node.material_override = mat
	pass_node.custom_aabb = NEVER_CULLED
	pass_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pass_node
