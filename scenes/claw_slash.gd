class_name ClawSlash
extends RefCounted
## The claw swipe's cue (Claws, D-095; PR #89 motion review): broad hot claw marks that fan out
## from the claw tip along the arm's rake arc (centred on the raking shoulder, at the arm's
## reach), drawn across the front as the arm crosses, plus a debris puff where the claws strike.
## They show a beat after the arm crosses and sweep on along its arc in about three frames, gone a
## few frames later: follow-through, not a bar. Sized up on a young body so the
## rake reads at the game camera. Additive, fading in a moment,
## so it never hides the kaiju (D-025). Presentation only; sizes and timings: "claw_fx".

## One unit box every claw mark scales (b2-3: a new mesh per segment cost a swipe 17 ms).
static var _unit: BoxMesh


## event: a sim "swipe" event (side, near, far, width, top); ahead: the facing on the ground;
## arc: the model's claw_arc ({"centre", "radius"}, or {} to fall back on the rake band); bs: the
## body scale.
static func play(
	city: CityView, kaiju_at: Vector3, ahead: Vector3, event: Dictionary, arc: Dictionary
) -> void:
	var cfg: Dictionary = Content.section("claw_fx")
	var bs := city.sim.body_scale()
	var boost := clampf(
		Num.f(cfg["fx_ref_scale"]) / maxf(0.01, bs), 1.0, Num.f(cfg["fx_boost_max"])
	)
	var side := Num.f(event["side"])
	var across := ahead.cross(Vector3.UP).normalized()  # the body's right
	var centre := kaiju_at + ahead * Num.f(event["near"]) + Vector3.UP * Num.f(event["top"]) * 0.6
	var radius := lerpf(Num.f(event["near"]), Num.f(event["far"]), 0.35)
	if not arc.is_empty():
		centre = arc["centre"]
		radius = Num.f(arc["radius"])
	radius *= Num.f(cfg["arc_reach"])
	var strike := (
		centre + _arc_point(ahead, across, side, radius, 0.0, Num.f(cfg["arc_drop"]) * radius * 0.5)
	)
	if arc.get("trailed", false):  # the arm lays its own streak (ClawTrail): only the dust is left
		var claw: Vector3 = arc.get("tip", strike)  # the hit shows at the claw, not the shoulder
		_strike_dust(city, claw, Num.f(cfg["puff"]) * bs * boost * Num.f(cfg["tip_puff"]))
		city.fx.sparks(claw)
		city.fx.sparks(claw + Vector3.UP * 0.25 * bs)  # a second burst, so the hit reads from behind
		return
	var root := Node3D.new()
	city.add_child(root)
	root.global_position = centre
	var mat := marks_material(cfg)
	var thick := Num.f(cfg["streak_thick"]) * bs * boost
	var gap := Num.f(cfg["streak_gap"]) * bs * boost
	var segments := Num.i(cfg["segments"])
	var a0 := deg_to_rad(Num.f(cfg["arc_from_deg"]))
	var a1 := deg_to_rad(Num.f(cfg["arc_to_deg"]))
	var drop := Num.f(cfg["arc_drop"]) * radius
	var streaks := Num.i(cfg["streaks"])
	var hidden: Dictionary = {}  # segment index along the arc -> the streaks' segments there
	for n: int in streaks:
		var r := radius + (n - (streaks - 1) * 0.5) * gap
		for k: int in segments:
			var u0 := float(k) / segments
			var u1 := float(k + 1) / segments
			var p0 := _arc_point(ahead, across, side, r, lerpf(a0, a1, u0), drop * u0)
			var p1 := _arc_point(ahead, across, side, r, lerpf(a0, a1, u1), drop * u1)
			# Marks taper to a point at both ends of the stroke, broadest mid-arc.
			var taper := sin(PI * (u0 + u1) * 0.5) * 0.8 + 0.2
			var seg := MeshInstance3D.new()
			seg.mesh = _unit_box()
			seg.material_override = mat
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(seg)
			seg.look_at_from_position(centre + (p0 + p1) * 0.5, centre + p1, Vector3.UP)
			seg.scale = Vector3(thick * taper, thick * 0.35, p0.distance_to(p1) * 1.05)
			seg.visible = false  # the whole stroke draws on, from the arm's outer end to its far end
			var at: Array = hidden.get_or_add(k, [])
			at.append(seg)
	var tween := root.create_tween()
	root.visible = false  # the marks follow the arm by a beat (slash_delay_s): follow-through
	tween.tween_callback(root.show).set_delay(Num.f(cfg["slash_delay_s"]))
	var draw := Num.f(cfg["sweep_s"])
	for k: int in hidden:
		var at: Array = hidden[k]
		tween.tween_callback(_show_all.bind(at)).set_delay(draw / maxf(1.0, hidden.size()))
	tween.tween_property(mat, "albedo_color:a", 0.0, Num.f(cfg["fade_s"]))
	tween.tween_callback(root.queue_free)
	# The claws strike: a puff of debris dust where the arc crosses the snout line.
	_strike_dust(city, strike, Num.f(cfg["puff"]) * bs * boost)


static func _strike_dust(city: CityView, at: Vector3, size: float) -> void:
	city.fx.dust(Vector3(at.x, maxf(0.3, at.y * 0.5), at.z), size)


## A point on the rake arc, from the centre: at `angle` from straight ahead toward the raking
## side (positive) or the far side (negative), `down` below the centre.
static func _arc_point(
	ahead: Vector3, across: Vector3, side: float, r: float, angle: float, down: float
) -> Vector3:
	return (ahead * cos(angle) + across * side * sin(angle)) * r - Vector3.UP * down


## The claw marks' additive, unshaded material (Fx keeps one compiled: ShaderKeep).
static func marks_material(cfg: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true  # the streak shows over the body: from behind the camera sees it
	mat.albedo_color = Color(str(cfg["streak_color"]))
	return mat


static func _unit_box() -> BoxMesh:
	if _unit == null:
		_unit = BoxMesh.new()
		_unit.size = Vector3.ONE
	return _unit


static func _show_all(segments: Array) -> void:
	for seg: Node3D in segments:
		if is_instance_valid(seg):
			seg.show()
