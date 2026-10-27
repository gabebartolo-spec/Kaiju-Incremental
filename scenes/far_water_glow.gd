class_name FarWaterGlow
extends RefCounted
## The far city's window light on the bay (director comment #37: "something funky going on with the
## distant city"; lead 2026-10-27: real night bays show the city's lit windows reflected on the
## water near the far shore). A faint band of the window palette's light (looks
## "window_lit_color") over the bay's own water material, as its next pass, so the water and its
## colour stay as they are everywhere else. It reaches tuning city far_reflect "reach" metres out
## from the far shore and is as strong as "strength" times the share of windows lit (looks
## "window_lit"): none by day, nothing near the camera. Presentation only.

const SHADER := preload("res://scenes/bay_glow.gdshader")


## Lays the glow over `bay`'s water, the far shore at z `shore`; null (nothing drawn) when tuning
## has it off or no window is lit.
static func cover(bay: MeshInstance3D, cfg: Dictionary, shore: float) -> ShaderMaterial:
	var lit := Look.value("window_lit")
	if bay == null or cfg.get("on", false) != true or lit <= 0.0:
		return null
	var glow := ShaderMaterial.new()
	glow.shader = SHADER
	glow.set_shader_parameter("glow_color", Look.color("window_lit_color"))
	glow.set_shader_parameter("energy", Num.f(cfg["energy"]))
	glow.set_shader_parameter("strength", Num.f(cfg["strength"]) * lit)
	glow.set_shader_parameter("shore_z", shore)
	glow.set_shader_parameter("reach", Num.f(cfg["reach"]))
	(bay.mesh as PrimitiveMesh).material.next_pass = glow
	return glow


## The glow over `bay`'s water, or null.
static func of(bay: MeshInstance3D) -> ShaderMaterial:
	var water := (bay.mesh as PrimitiveMesh).material
	return water.next_pass as ShaderMaterial if water.next_pass != null else null


## The share of the water's light the glow takes `metres` out from the far shore
## (bay_glow.gdshader).
static func share_at(glow: ShaderMaterial, metres: float) -> float:
	if glow == null:
		return 0.0
	var reach := Num.f(glow.get_shader_parameter("reach"))
	var fade := 1.0 - smoothstep(0.0, reach, maxf(metres, 0.0))
	return Num.f(glow.get_shader_parameter("strength")) * fade
