class_name DeathStone
extends RefCounted
## The kaiju's stone look in one place (tuning death.look): the colour, per-block variation and the
## share of his own shade that a stoned cube keeps. His hide (VoxelSkin.overload) and the pieces
## that fly off when he shatters (DeathView) both take it from here, so they are one stone
## (stone_body.gdshaderinc is the matching formula).


## Sets the stone uniforms on `mat` (the voxel skin's, its filler's or the flying pieces').
static func look(mat: ShaderMaterial) -> void:
	var look_cfg: Dictionary = Content.section("death")["look"]
	mat.set_shader_parameter("stone_color", Color(str(look_cfg["stone"])))
	mat.set_shader_parameter("stone_vary", Num.f(look_cfg["stone_vary"]))
	mat.set_shader_parameter("stone_keep", Num.f(look_cfg["stone_keep"]))
