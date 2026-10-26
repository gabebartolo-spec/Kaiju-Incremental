class_name SmokeSoft
extends RefCounted
## Render plan item 13, soft smoke (tuning render_opt.soft_smoke, soft_smoke_m). Smoke, fire
## columns, street dust and blast clouds all draw with smoke.gdshader, which fades a puff's alpha
## over its gap to the roof, wall or street behind it, so it melts into them instead of showing a
## hard intersection line. The fade width is the global shader uniform `smoke_soft_m`
## (project.godot, 0 = no fade): this class turns the data into that one number, so no smoke user
## needs touching.

const GLOBAL := "smoke_soft_m"

## The width last handed on (the headless renderer cannot read a global back); -1 before any.
static var applied: float = -1.0


## The fade width in metres for a render_opt table: 0 (no fade) with the flag off or no width.
static func soft_m_from(opt: Dictionary) -> float:
	if opt.get("soft_smoke", false) != true:
		return 0.0
	return maxf(Num.f(opt.get("soft_smoke_m", 0.0)), 0.0)


## The fade width the shipped data asks for.
static func soft_m() -> float:
	return soft_m_from(Content.section("render_opt"))


## Hands the width to every smoke material; a city view does this once when it is built.
static func apply() -> void:
	applied = soft_m()
	RenderingServer.global_shader_parameter_set(GLOBAL, applied)
