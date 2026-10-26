extends SceneTree
## Headless gate for the rooftop rifles (D-063) before any capture: plays the capture's scene
## (capture_rooftops.gd: the Behemoth where the most squads fire on screen) and, on the frame each
## hit lands on the hide (HideHit), builds the kaiju's silhouette from the game camera (every
## voxel of its rig projected to the screen, as its rig poses them) and checks the hit point
## (on the hide along the round's line to an upper-body bone's centre) falls inside it, dilated
## DILATE px.
## Prints the counts and the worst cost of a volley's hit search and of landing a round; exits 1
## on any miss.
##
##   godot --headless --path . --script tools/capture/rooftop_hit_gate.gd -- [--seed=0]

const Capture := preload("res://tools/capture/capture_rooftops.gd")
const GuiInput := preload("res://tests/lib/gui_input.gd")
const FRAMES := 60 * 6
const SIZE := Vector2i(1920, 1080)
const DILATE := 2

var _seed := 0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_seed = arg.substr(7).to_int()
	_run.call_deferred()


func _run() -> void:
	root.size = SIZE
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), Capture.LEVELS, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(
		Content.tuning(), Num.i(stats["size"]), Seeds.make("city", _seed)
	)
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, _seed)
	rampage.sim.kaiju_pos = Capture.new()._stand(rampage.sim)
	rampage.sim.facing = Vector2(0, -1)
	rampage.sim.emerge.active = false  # on land at the stand spot: the rise from the river is not
	rampage.sim.stand_y = 0.0  # what this gate plays, and holds the army back until it ends
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	root.add_child(rampage)
	await rampage.wait_loaded()  # the city builds over several frames
	var roofs: RooftopView = GuiInput.find_script(rampage, RooftopView)
	var rig := _player_rig(rampage)
	var camera := root.get_viewport().get_camera_3d()
	var logged := 0
	var inside := 0
	var on_screen := 0
	var misses: Array[String] = []
	for i: int in FRAMES:
		await physics_frame
		if logged == roofs.spark_log.size():
			continue
		var mask := _silhouette(rig, camera)
		while logged < roofs.spark_log.size():
			var at: Vector3 = roofs.spark_log[logged]["at"]
			logged += 1
			if camera.is_position_behind(at):
				continue
			var px := Vector2i(camera.unproject_position(at).round())
			if px.x < 0 or px.y < 0 or px.x >= SIZE.x or px.y >= SIZE.y:
				continue
			on_screen += 1
			if _covered(mask, px):
				inside += 1
			else:
				misses.append("frame %d at %s px %s" % [i, at, px])
	print(
		(
			"rooftop hits: %d hits, %d on screen, %d inside the kaiju's silhouette (+%d px)"
			% [logged, on_screen, inside, DILATE]
		)
	)
	for miss: String in misses:
		print("  MISS ", miss)
	print("worst volley hit search: %d usec" % roofs.worst_aim_usec)
	print("worst round landed on the hide: %d usec" % roofs.worst_land_usec)
	quit(0 if misses.is_empty() and on_screen > 0 else 1)


## The rig standing on the sim's kaiju: the HUD keeps a portrait rig of its own in a SubViewport,
## far off, that the first find would pick.
func _player_rig(rampage: Rampage) -> KaijuRig:
	var at := Vector3(rampage.sim.kaiju_pos.x, 0.0, rampage.sim.kaiju_pos.y)
	var best: KaijuRig = null
	for node: Node in rampage.find_children("*", "KaijuRig", true, false):
		var rig := node as KaijuRig
		var nearer := best == null
		nearer = (
			nearer or rig.global_position.distance_to(at) < best.global_position.distance_to(at)
		)
		if nearer:
			best = rig
	return best


## Every voxel of the rig projected to the screen as a square its own size: the silhouette. Voxel
## centres come from the rig's cells (KaijuRig.voxels_of), placed the way KaijuRig.attach_voxels
## and VoxelBuilder.build place them under each bone; the MultiMesh instance data is empty here
## (the headless renderer keeps none).
func _silhouette(rig: KaijuRig, camera: Camera3D) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(SIZE.x * SIZE.y)
	var voxel := rig.voxel_size()
	var lift := Vector3(0, voxel * 0.5, 0)
	for bone_name: String in rig.bone_names():
		var part := rig.voxels_of(bone_name)
		if part == null:
			continue
		var xf := rig.bone(bone_name).global_transform
		var origin := -rig.head_of(bone_name)
		var half := voxel * xf.basis.get_scale().x * 0.5
		for cell: Vector3i in part.cells:
			var c := xf * (origin + Vector3(cell) * voxel + lift)
			if camera.is_position_behind(c):
				continue
			var p := camera.unproject_position(c)
			var edge := camera.unproject_position(c + camera.global_basis.x * half)
			var r := ceili(p.distance_to(edge))
			for y: int in range(floori(p.y) - r, floori(p.y) + r + 1):
				for x: int in range(floori(p.x) - r, floori(p.x) + r + 1):
					if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y:
						mask[y * SIZE.x + x] = 1
	return mask


func _covered(mask: PackedByteArray, px: Vector2i) -> bool:
	for y: int in range(px.y - DILATE, px.y + DILATE + 1):
		for x: int in range(px.x - DILATE, px.x + DILATE + 1):
			if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y and mask[y * SIZE.x + x] == 1:
				return true
	return false
