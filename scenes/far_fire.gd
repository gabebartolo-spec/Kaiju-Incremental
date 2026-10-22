class_name FarFire
extends Node3D
## A fire seen from far across the bay (the title's burning towers): the game's own Fire (voxel
## flames, embers and the charcoal smoke column, scenes/fire.gd) at a zoom that multiplies every
## size and speed for the distance, so a fire at 230 m reads as the same fire as one in the street
## (the director's consistency rule: no separate title-only fire style), plus a soft flickering
## glow standing in for the light the street fire casts on its surroundings.
## Presentation only. Numbers: tuning "title" "fires" "far" and "window".

## Draw order of the transparent layers, back to front whatever their depth: sky smoke (-1), the
## fires' smoke and glows (0), the colossus (1: it stands in front of the smoke), the flames (2).
const FLAME_PRIORITY := 2
## How strong the fire's own light is on the wall around it (the soft glow's alpha).
const GLOW_ALPHA := 0.3

static var _disc: GradientTexture2D

var _cfg: Dictionary
var _glow: MeshInstance3D
var _t := 0.0
var _seed := 0.0


func _init(cfg: Dictionary, seed_value: float) -> void:
	_cfg = cfg
	_seed = seed_value


func _ready() -> void:
	_glow = _glow_sprite()
	add_child(_glow)
	var fire := Fire.new(Num.f(_cfg["size"]), _seed, _cfg)
	for child: Node in fire.get_children():
		var system := child as GPUParticles3D
		if system == null:
			continue
		system.preprocess = system.lifetime  # already burning when the title appears
		# Fewer simulation steps a second: the preprocess is most of the title's build time.
		system.fixed_fps = Num.i(_cfg["fixed_fps"])
		var cube := system.draw_pass_1 as BoxMesh
		if cube != null:
			# The flames and embers draw over the colossus; the smoke behind it.
			(cube.material as ShaderMaterial).render_priority = FLAME_PRIORITY
	add_child(fire)


func _process(delta: float) -> void:
	_t += delta
	var beat := sin(_t * Num.f(_cfg["flicker_hz"]) + _seed) * sin(_t * 2.3 + _seed * 3.0)
	_glow.scale = Vector3.ONE * Num.f(_cfg["glow_size"]) * (0.8 + 0.2 * beat)


## The fire's own light on the wall around it.
func _glow_sprite() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	mat.albedo_color = Color(Color(str(_cfg["glow_color"])), GLOW_ALPHA)
	mat.albedo_texture = soft_disc()
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.scale = Vector3.ONE * Num.f(_cfg["glow_size"])
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## A white disc that fades out smoothly toward its edge, shared by every sprite.
static func soft_disc() -> GradientTexture2D:
	if _disc != null:
		return _disc
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 0.4))
	_disc = GradientTexture2D.new()
	_disc.gradient = fade
	_disc.fill = GradientTexture2D.FILL_RADIAL
	_disc.fill_from = Vector2(0.5, 0.5)
	_disc.fill_to = Vector2(1.0, 0.5)
	_disc.width = 128
	_disc.height = 128
	return _disc
