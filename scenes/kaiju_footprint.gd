class_name KaijuFootprint
extends RefCounted
## Where the drawn kaiju's body meets the ground, for the city's trample (D-065): read from the
## kaiju's own sculpt, so it is right at every stage and species, and turned and scaled with the
## model. Presentation only.


## The KaijuModel beside `from` in the scene (Rampage holds the city and the kaiju), or null.
static func find(from: Node) -> KaijuModel:
	var up := from.get_parent()
	while up != null:
		for n: Node in up.get_children():
			if n is KaijuModel:
				return n
		up = up.get_parent()
	return null


## The model's ground box in its own frame (x across, y along its z, at scale 1), cut to the
## middle `share` of each side: the splayed feet and the tail tip only reach its corners. Read
## from the sculpt's voxels (assets/kaiju/<species>_<stage>.kvox, the stage the model falls back
## to as KaijuModel does), so it is the same with or without a renderer; a model with no sculpt
## falls back to its drawn bounds.
static func of(model: KaijuModel, size_tier: int, share: float) -> Rect2:
	var rect := _sculpt(model.species_id, KaijuModel.stage_for(size_tier))
	if not rect.has_area():
		rect = _drawn(model)
	var cut := rect.size * (1.0 - share) * 0.5
	return rect.grow_individual(-cut.x, -cut.y, -cut.x, -cut.y)


## The sculpt's cells across x and z, sized as KaijuRig sizes them (MODEL_HEIGHT tall).
static func _sculpt(species_id: String, stage: String) -> Rect2:
	var stages: Array[String] = ["baby", "adolescent", "adult"]
	for i: int in range(maxi(0, stages.find(stage)), stages.size()):
		var model := Kvox.read("res://assets/kaiju/%s_%s.kvox" % [species_id, stages[i]])
		if model.height <= 0 or model.frames.is_empty():
			continue
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := -lo
		for cell: Vector3i in model.frames[0].cells:
			lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.z))
			hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.z))
		var size := KaijuModel.MODEL_HEIGHT / model.height
		return Rect2(Vector2(lo) * size, Vector2(hi - lo + Vector2i.ONE) * size)
	return Rect2()


## The drawn voxel parts' bounds (only where there is a renderer; the skin's culling box and the
## particle effects attached to the body are left out).
static func _drawn(model: KaijuModel) -> Rect2:
	var into := model.global_transform.affine_inverse()
	var box := AABB()
	for n: Node in model.find_children("*", "MultiMeshInstance3D", true, false):
		var g := n as MultiMeshInstance3D
		if g.multimesh == null or g.custom_aabb.has_volume():
			continue
		var b := into * g.global_transform * g.multimesh.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
