class_name KaijuFootprint
extends RefCounted
## Where the drawn kaiju's body meets the ground, for the city's trample (D-065): read from the
## model itself, so it is right at every stage, species and scale. Presentation only.


## The KaijuModel beside `from` in the scene (Rampage holds the city and the kaiju), or null.
static func find(from: Node) -> KaijuModel:
	var up := from.get_parent()
	while up != null:
		for n: Node in up.get_children():
			if n is KaijuModel:
				return n
		up = up.get_parent()
	return null


## The model's ground box in its own frame (x across, y along its z), from its voxel cells, cut
## to the middle `share` of each side: the splayed feet and the tail tip only reach its corners.
static func of(model: KaijuModel, share: float) -> Rect2:
	var into := model.global_transform.affine_inverse()
	var box := AABB()
	# The voxel parts (head, jaw, legs, tail), which together span the body. Skipped: anything
	# with a set culling box (the skin's is far wider than the body) and the particle effects
	# attached to the body.
	for n: Node in model.find_children("*", "MultiMeshInstance3D", true, false):
		var g := n as MultiMeshInstance3D
		if g.multimesh == null or g.custom_aabb.has_volume():
			continue
		var b := into * g.global_transform * g.multimesh.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	var rect := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	var cut := rect.size * (1.0 - share) * 0.5
	return rect.grow_individual(-cut.x, -cut.y, -cut.x, -cut.y)
