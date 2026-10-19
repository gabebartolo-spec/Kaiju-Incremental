class_name ClawSlash
extends RefCounted
## The claw swipe's cue (Claws, D-095; PR #89 motion review): broad hot claw marks that fan out
## from the claw tip along the arm's rake arc (centred on the raking shoulder, at the arm's
## reach), drawn across the front as the arm crosses, plus a debris puff where the claws strike.
## Sized up on a young body so the rake reads at the game camera. Additive, fading in a moment,
## so it never hides the kaiju (D-025). Presentation only; sizes and timings: "claw_fx".


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
	var root := Node3D.new()
	city.add_child(root)
	root.global_position = centre
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(str(cfg["streak_color"]))
	var thick := Num.f(cfg["streak_thick"]) * bs * boost
	var gap := Num.f(cfg["streak_gap"]) * bs * boost
	var segments := Num.i(cfg["segments"])
	var a0 := deg_to_rad(Num.f(cfg["arc_from_deg"]))
	var a1 := deg_to_rad(Num.f(cfg["arc_to_deg"]))
	var drop := Num.f(cfg["arc_drop"]) * radius
	var streaks := Num.i(cfg["streaks"])
	var cross := a0 / maxf(0.001, a0 - a1)  # how far along the arc the snout line is
	var hidden: Dictionary = {}  # segment index along the arc -> the streaks' segments there
	for n: int in streaks:
		var r := radius + (n - (streaks - 1) * 0.5) * gap
		for k: int in segments:
			var u0 := float(k) / segments
			var u1 := float(k + 1) / segments
			var p0 := _arc_point(ahead, across, side, r, lerpf(a0, a1, u0), drop * u0)
			var p1 := _arc_point(ahead, across, side, r, lerpf(a0, a1, u1), drop * u1)
			var box := BoxMesh.new()
			# Marks taper to a point at both ends of the stroke, broadest mid-arc.
			var taper := sin(PI * (u0 + u1) * 0.5) * 0.8 + 0.2
			box.size = Vector3(thick * taper, thick * 0.35, p0.distance_to(p1) * 1.05)
			box.material = mat
			var seg := MeshInstance3D.new()
			seg.mesh = box
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(seg)
			seg.look_at_from_position(centre + (p0 + p1) * 0.5, centre + p1, Vector3.UP)
			if u0 >= cross:  # the arm crosses the snout line now: the rest draws on
				seg.visible = false
				var at: Array = hidden.get_or_add(k, [])
				at.append(seg)
	var tween := root.create_tween()
	var draw := Num.f(cfg["strike_s"]) * 0.5
	for k: int in hidden:
		var at: Array = hidden[k]
		tween.tween_callback(_show_all.bind(at)).set_delay(draw / maxf(1.0, hidden.size()))
	tween.tween_property(mat, "albedo_color:a", 0.0, Num.f(cfg["fade_s"]))
	tween.tween_callback(root.queue_free)
	# The claws strike: a puff of debris dust where the arc crosses the snout line.
	var hit := centre + _arc_point(ahead, across, side, radius, 0.0, drop * 0.5)
	hit.y = maxf(0.3, hit.y * 0.5)
	city.fx.dust(hit, Num.f(cfg["puff"]) * bs * boost)


## A point on the rake arc, from the centre: at `angle` from straight ahead toward the raking
## side (positive) or the far side (negative), `down` below the centre.
static func _arc_point(
	ahead: Vector3, across: Vector3, side: float, r: float, angle: float, down: float
) -> Vector3:
	return (ahead * cos(angle) + across * side * sin(angle)) * r - Vector3.UP * down


static func _show_all(segments: Array) -> void:
	for seg: Node3D in segments:
		if is_instance_valid(seg):
			seg.show()
