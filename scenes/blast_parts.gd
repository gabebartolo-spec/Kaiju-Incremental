class_name BlastParts
extends RefCounted
## The shared explosion look, ported from claude/city-explosives-v2 (commit 5a9697db,
## scenes/blast_parts.gd: `fireball`, `flame_cube` and `emit`, verbatim, so that branch merges onto
## this file instead of duplicating it). The blast is the GAME'S OWN FIRE (director 2026-10-22,
## D-151: "consistency is absolutely key"): a sudden tall burst of Fire's flames,
## then that fire stays burning. The burst
## uses Fire's flame exactly: its voxel (Fire.FLAME_CUBE at Fire.FLAME_SCALE), its ember shader at
## its own heat, its colours and their ramp, rising like Fire's flames (narrow spread, gravity up,
## shrinking to a tenth); a bigger blast is more flames, never bigger cubes. It starts from a box
## (`half`: its half extents, `at` its centre). Looks come from the caller's "fireball" tuning dict.
## Presentation only.


## The burst: Fire's flame voxels (cube, sizes, ember shader at its own heat, colours, ramp) leaving
## the box, emitted over fireball.burst_seconds at a high rate (so the column builds in a few
## frames and every blast grows its own), going up on a narrow spread with gravity up like
## Fire's flames, damped to stop `top_scale` site heights up, and shrinking to a tenth. `amount`
## flames at a blast radius of 5, more for a bigger one.
static func fireball(
	host: Node3D, at: Vector3, half: Vector3, radius: float, cfg: Dictionary
) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = half
	mat.direction = Vector3.UP
	mat.spread = Num.f(cfg["spread"])
	var speed := radius * Num.f(cfg["speed_scale"])
	var rise := maxf(0.4, half.y * 2.0 * (Num.f(cfg["top_scale"]) - 1.0))
	mat.initial_velocity_min = speed * 0.5
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, Num.f(cfg["lift"]), 0)
	mat.damping_min = speed * speed / (2.0 * rise)
	mat.damping_max = mat.damping_min * 1.3
	mat.scale_min = Fire.FLAME_SCALE.x
	mat.scale_max = Fire.FLAME_SCALE.y
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.1))
	var tex := CurveTexture.new()
	tex.curve = curve
	mat.scale_curve = tex
	var flame := Gradient.new()  # as Fire's own ramp: an ordinary 8-bit texture, not an HDR one
	flame.colors = PackedColorArray(Fire.FLAME_COLORS)
	flame.offsets = PackedFloat32Array(Fire.FLAME_AT)
	var flame_tex := GradientTexture1D.new()
	flame_tex.gradient = flame
	mat.color_ramp = flame_tex
	var life := Num.f(cfg["seconds"])
	var amount := roundi(Num.f(cfg["amount"]) * clampf(radius / 5.0, 0.5, 1.6))
	var p := emit(host, mat, flame_cube(), amount, life, at)
	p.explosiveness = 1.0 - Num.f(cfg["burst_seconds"]) / life  # it spawns over burst_seconds


## A unit flame voxel: Fire's cube with its ember shader (its own heat).
static func flame_cube() -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * Fire.FLAME_CUBE
	var mat := ShaderMaterial.new()
	mat.shader = Fire.EMBER_SHADER
	cube.material = mat
	return cube


## A particle system that emits once and frees itself after `life`.
static func emit(
	host: Node3D,
	mat: ParticleProcessMaterial,
	mesh: Mesh,
	amount: int,
	life: float,
	at: Vector3,
	free_after := -1.0
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 60, 80))
	p.position = at
	p.emitting = true
	host.add_child(p)
	var gone := (free_after if free_after > 0.0 else life) + 0.3
	host.get_tree().create_timer(gone).timeout.connect(p.queue_free)
	return p
