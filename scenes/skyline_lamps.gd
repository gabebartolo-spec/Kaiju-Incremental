class_name SkylineLamps
extends RefCounted
## CitySkyline's lamps past the playable edge: where they stand down the outer streets, and their
## glowing heads (no real lights: they only need to twinkle). Split out of CitySkyline to keep
## files small.


## Appends to `lamps` a lamp every 9 units down each outer street of `ground`'s plan, within
## CitySkyline.DETAIL_REACH of the centre (inside the playable city the decor puts real ones).
static func outer_streets(ground: CityGround, lamps: Array[Vector3]) -> void:
	var nodes: Array[Vector2] = ground.plan["nodes"]
	var half := Num.f(ground.cfg["half"])
	for street: Dictionary in ground.plan["streets"]:
		if str(street["kind"]) == CityGen.ALLEY:
			continue
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if maxf(absf(a.x), absf(a.y)) <= half + 1.0 and maxf(absf(b.x), absf(b.y)) <= half + 1.0:
			continue  # inside the playable city the decor puts real streetlights
		if minf(a.y, b.y) < ground.coast:
			continue
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * (Num.f(street["width"]) * 0.5 + 0.5)
		var t := 3.0
		while t < a.distance_to(b):
			var p := a + dir * t + side
			if p.length() < CitySkyline.DETAIL_REACH:
				lamps.append(Vector3(p.x, 2.6, p.y))
			t += 9.0


## The glowing heads of `lamps`, one multimesh.
static func heads(lamps: Array[Vector3]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 0.2, 0.35)
	mesh.material = CityView.glow(Color("ffd59a"), 4.0)
	mm.mesh = mesh
	mm.instance_count = lamps.size()
	for i: int in lamps.size():
		mm.set_instance_transform(i, Transform3D(Basis(), lamps[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.add_to_group("vfx_exempt")  # lamp heads are lights, not surfaces (director 2026-10-30)
	return mmi
