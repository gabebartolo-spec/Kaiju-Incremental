extends "res://tests/lib/runner.gd"
## Shot impacts on the kaiju's hide (director 2026-10-25): a shot finds the real cube it meets on the
## skinned body (SkinHits, a ray walked through each bone's rest grid under its current pose), the
## impact (HideHit) lies on that surface along its normal, is depth-tested, lasts under a tenth of a
## second and stays under the bloom threshold, and wounds ride the bones, are capped and fade.
##   godot --headless --path . --script tests/run_hide_hit_tests.gd

const DT := 1.0 / 60.0
const BLOOM := 0.9


func suite_name() -> String:
	return "Hide hit"


func run_checks() -> void:
	await _t("_check_ray_walks_the_grid")
	await _t("_check_ray_follows_the_pose")
	await _t("_check_wounds_cap_and_fade")
	await _t("_check_real_hide")
	await _t("_check_impact_look")


## A 3x3x3 block of cubes (x, z centred on the cell, y from it up) with a voxel of 1.
func _block(bones := 1) -> SkinHits:
	var hits := SkinHits.new()
	hits.setup(bones, 1.0, 48)
	for x: int in 3:
		for y: int in 3:
			for z: int in 3:
				hits.add_cell(0, Vector3i(x, y, z), Color.WHITE)
	return hits


func _f(d: Dictionary, key: String) -> float:
	var v: float = d[key]
	return v


func _v(d: Dictionary, key: String) -> Vector3:
	var v: Vector3 = d[key]
	return v


func _pose(shift := Vector3.ZERO) -> Array[Projection]:
	var out: Array[Projection] = [Projection(Transform3D(Basis(), shift))]
	return out


func _check_ray_walks_the_grid() -> void:
	var hits := _block()
	var front := hits.cast(_pose(), Transform3D(), Vector3(1, 1.5, -5), Vector3(1, 1.5, 5))
	check(not front.is_empty(), "a ray at the block's front meets it")
	check(absf(_f(front, "t") - 0.45) < 1e-3, "the front face is at z -0.5 (t %s)" % front.get("t"))
	check(_v(front, "normal").is_equal_approx(Vector3(0, 0, -1)), "the front face looks at the shooter")
	var top := hits.cast(_pose(), Transform3D(), Vector3(1, 10, 1), Vector3(1, -5, 1))
	check(absf(_f(top, "t") - 7.0 / 15.0) < 1e-3, "a shot from above lands on the top face (y 3)")
	check(_v(top, "normal").is_equal_approx(Vector3.UP), "the top face looks up")
	var miss := hits.cast(_pose(), Transform3D(), Vector3(10, 1.5, -5), Vector3(10, 1.5, 5))
	check(miss.is_empty(), "a ray beside the block misses")
	var short := hits.cast(_pose(), Transform3D(), Vector3(1, 1.5, -5), Vector3(1, 1.5, -2))
	check(short.is_empty(), "a segment that stops short does not reach it")
	var back := hits.cast(_pose(), Transform3D(), Vector3(1, 1.5, 5), Vector3(1, 1.5, -5))
	check(absf(_f(back, "t") - 0.25) < 1e-3, "from behind it meets the back face first")
	check(_v(front, "point").z < 0.0 and _v(back, "point").z > 2.0, "front and back hits are on opposite sides")


func _check_ray_follows_the_pose() -> void:
	var hits := _block()
	var moved := hits.cast(_pose(Vector3(5, 0, 0)), Transform3D(), Vector3(6, 1.5, -5), Vector3(6, 1.5, 5))
	check(not moved.is_empty(), "a bone moved by the pose is hit where it now is")
	var old := hits.cast(_pose(Vector3(5, 0, 0)), Transform3D(), Vector3(1, 1.5, -5), Vector3(1, 1.5, 5))
	check(old.is_empty(), "and no longer where it was")
	var rest := _v(moved, "rest")
	check(rest.is_equal_approx(Vector3(1, 1.5, -0.5)), "the hit is recorded in rest space (the wound rides the bone): %s" % rest)
	var turned := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1, 0, 1))
	var spun := hits.cast(_pose(), turned, Vector3(1, 1.5, -5), Vector3(1, 1.5, 5))
	check(not spun.is_empty() and _v(spun, "normal").is_equal_approx(Vector3(0, 0, -1)), "the world transform turns the normal")


func _check_wounds_cap_and_fade() -> void:
	var hits := _block()
	for i: int in 70:
		hits.add_wound(Vector3(i, 0, 0), 1.0)
	check(hits.live() == 48, "the ring buffer holds the cap (%d)" % hits.live())
	check(hits.wounds().size() == SkinHits.SHADER_CAP, "the shader array is a fixed size")
	hits.age(180.0, 360.0)
	check(absf(hits.wounds()[0].w - 0.5) < 1e-3, "a wound is half gone after half its life")
	hits.age(200.0, 360.0)
	check(hits.live() == 0, "and gone after all of it")


func _kaiju(stage: String) -> KaijuModel:
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	root.add_child(kaiju)
	for _i: int in 30:
		kaiju.animate(DT, 0.0)
	return kaiju


func _check_real_hide() -> void:
	var tune: Dictionary = Content.section("fx")["hide_hit"]
	for stage: String in ["baby", "adolescent"]:
		var kaiju := _kaiju(stage)
		var mid := kaiju.global_position + Vector3(0, 6.0, 0)
		var near := kaiju.hide_cast(mid + Vector3(1, 0.5, 15), mid - Vector3(1, 0.5, 15))
		check(not near.is_empty(), "%s: a shot at his middle meets the hide" % stage)
		if near.is_empty():
			continue
		var far := kaiju.hide_cast(mid + Vector3(1, 0.5, -15), mid + Vector3(-1, -0.5, 15))
		check(not far.is_empty(), "%s: so does one from the other side" % stage)
		var p := _v(near, "point")
		check(p.distance_to(mid) < 8.0, "%s: the near hit is on the body round the aim point (%s)" % [stage, p])
		check(_v(near, "normal").dot((mid - (mid + Vector3(1, 0.5, 15))).normalized()) < 0.0, "%s: its normal faces the shooter" % stage)
		check(_v(near, "point").z > _v(far, "point").z, "%s: the two sides differ, nearest first" % stage)
		var before := kaiju.wounds_live()
		kaiju.add_wound(_v(near, "rest"))
		check(kaiju.wounds_live() == before + 1, "%s: a wound is kept" % stage)
		for _i: int in 600:
			kaiju.animate(DT, 1.0)
		var again := kaiju.hide_cast(mid + Vector3(1, 0.5, 15), mid - Vector3(1, 0.5, 15))
		check(again.is_empty() or again.has("point"), "%s: still answers after walking" % stage)
		check(kaiju.voxel_world() > 0.0, "%s: one voxel has a size" % stage)
		kaiju.queue_free()
	check(Num.i(tune["max_wounds"]) <= SkinHits.SHADER_CAP, "the wound cap fits the shader")


func _check_impact_look() -> void:
	var tune: Dictionary = Content.section("fx")["hide_hit"]
	var fx := Fx.new()
	root.add_child(fx)
	await process_frame
	var kaiju := _kaiju("adolescent")
	var mid := kaiju.global_position + Vector3(0, 4.0, 0)  # between the legs of a Behemoth
	var from := mid + Vector3(1, 0.5, 15)
	var result := HideHit.land(fx, kaiju, from, mid)
	var landed: bool = result["hit"]
	check(landed, "the shot landed on the hide")
	var hide: HideHit = fx.get("_hide_hit")
	var quads: Array[MeshInstance3D] = []
	for c: Node in hide.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).global_position.y > -10.0:  # not the prewarm's
			quads.append(c)
	check(quads.size() == 1, "one flash quad")
	if quads.size() == 1:
		var q := quads[0]
		var mat := q.material_override as ShaderMaterial
		check(not mat.shader.code.contains("depth_test_disabled"), "the flash is depth-tested")
		check(not mat.shader.code.contains("blend_add"), "the flash is alpha-blended, not additive")
		check(q.basis.z.normalized().is_equal_approx(_v(result, "normal")), "the flash lies on the surface, facing the normal")
		var width := q.basis.x.length()
		check(width <= 5.01 * kaiju.voxel_world(), "the flash is a few cubes across (%.3f m)" % width)
	var tint := Color(str(tune["flash_tint"])).srgb_to_linear()
	check(maxf(tint.r, maxf(tint.g, tint.b)) * Num.f(tune["flash_alpha"]) < BLOOM, "the flash stays under the bloom threshold")
	check(Num.f(tune["flash_seconds"]) < 0.1, "the flash lasts under 0.1 s")
	check(Num.f(tune["glance_seconds"]) < 0.1, "a glance too")
	for key: String in ["spark_tint", "glance_tint"]:
		var c := Color(str(tune[key])).srgb_to_linear()
		check(maxf(c.r, maxf(c.g, c.b)) < BLOOM, "%s stays under the bloom threshold" % key)
	check(Num.f(tune["mist_seconds"]) <= 0.6, "the blood mist is gone by 0.6 s")
	var mist := Color(str(tune["mist_tint"]))
	check(mist.r > mist.g and mist.r > mist.b and mist.v < 0.5, "the mist is a dark red")
	var wounds := kaiju.wounds_live()
	check(wounds == 1, "a landed shot leaves one wound (%d)" % wounds)
	HideHit.land(fx, kaiju, from, mid, true, Vector3.UP)
	check(kaiju.wounds_live() == wounds, "a glance leaves none")
	await create_timer(1.0).timeout
	check(not is_instance_valid(quads[0]) if quads.size() == 1 else true, "the flash frees itself")
