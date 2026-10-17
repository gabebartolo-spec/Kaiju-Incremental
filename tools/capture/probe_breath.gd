extends SceneTree
## Prints where Atomic Breath fires against where the kaiju's head is: the sim facing, the
## model's heading, the beam's mouth and struck point, and the head/jaw bones' world positions.
## Headless:  godot --headless --path . --script tools/capture/probe_breath.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var levels := {"claws": 2, "hide": 1, "evolve1": 1, "sig_power": 2}
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	var played := rampage.ability_fx.played
	for _i: int in 1200:
		await physics_frame
		if played.has("breath"):
			break
	var sim := rampage.sim
	var model: Node3D = rampage._kaiju
	print("facing ", sim.facing, " heading want ", atan2(-sim.facing.x, -sim.facing.y))
	print("model rot.y ", model.rotation.y, " model fwd(-Z) ", -model.global_basis.z)
	print("kaiju_at ", rampage._kaiju_at, " body_scale ", sim.body_scale())
	for node: Node in model.find_children("*", "Skeleton3D", true, false):
		var sk: Skeleton3D = node
		for b: int in sk.get_bone_count():
			var n := sk.get_bone_name(b)
			print("bone ", n, " ", sk.global_transform * sk.get_bone_global_pose(b).origin)
	for node: Node in rampage.ability_fx.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is CylinderMesh:
			var m: MeshInstance3D = node
			var cyl: CylinderMesh = m.mesh
			print(
				"beam centre ", m.global_position, " axis ", m.global_basis.y, " len ", cyl.height
			)
	var cam := rampage.get_viewport().get_camera_3d()
	if cam != null:
		print("camera ", cam.global_position, " looks ", -cam.global_basis.z)
	for _i: int in 20:
		await physics_frame
	if cam != null:
		print("camera +20 ", cam.global_position, " looks ", -cam.global_basis.z)
	quit()
