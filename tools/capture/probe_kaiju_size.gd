extends SceneTree
## The kaiju's drawn size and ground contact per stage, for a voxel re-bake (D-107: the kaiju at
## double voxel density must keep its scale, footprint and contacts). Headless, fixed steps:
##
##   godot --headless --path . --script tools/capture/probe_kaiju_size.gd -- --species=reptilian
##
## One KAIJU line per stage: the rig's voxel size, the skin's cube count, the drawn box at rest
## (min y = feet on the ground, height, width, length), the hip height and focus point, and over a
## WALK_S walk the planted feet's heights (min / max y) and the number of footfalls.

const STAGES: Array[String] = ["baby", "adolescent", "adult"]
const STEP := 1.0 / 60.0
const SETTLE_FRAMES := 30
const WALK_S := 4.0
const WALK_SPEED := 5.0  # m/s, about the species' base speed

var _species := "reptilian"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var def: Dictionary = Content.species_def(_species)
	var colors: Dictionary = def["colors"]
	for stage: String in STAGES:
		var kaiju := KaijuModel.new(_species, colors, stage)
		root.add_child(kaiju)
		for _i: int in SETTLE_FRAMES:
			kaiju.animate(STEP, 0.0)
			await process_frame
		var box := _box(kaiju)
		var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
		var cubes := 0
		for mmi: Node in kaiju.find_children("*", "MultiMeshInstance3D", true, false):
			var mm := (mmi as MultiMeshInstance3D).multimesh
			if mm != null:
				cubes += mm.instance_count
		var feet: Array[float] = []
		kaiju.foot_planted.connect(
			func(_side: String, _strength: float, at: Vector3) -> void: feet.append(at.y)
		)
		for _i: int in int(WALK_S / STEP):
			kaiju.position += Vector3(0, 0, -WALK_SPEED * STEP)
			kaiju.animate(STEP, 1.0)
			await process_frame
		print(
			(
				(
					"KAIJU %s voxel %.4f cubes %d min_y %.3f height %.3f width %.3f length %.3f"
					% [
						stage,
						rig.voxel_size(),
						cubes,
						box.position.y,
						box.size.y,
						box.size.x,
						box.size.z
					]
				)
				+ (
					" hip %.3f focus_y %.3f footfalls %d foot_y %.3f..%.3f"
					% [
						kaiju.hip_height(),
						kaiju.focus().y,
						feet.size(),
						feet.min() if not feet.is_empty() else 0.0,
						feet.max() if not feet.is_empty() else 0.0,
					]
				)
			)
		)
		kaiju.queue_free()
		await process_frame
	quit()


## The world box of everything the kaiju draws.
func _box(kaiju: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node: Node in kaiju.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if not geo.is_visible_in_tree():
			continue
		var part := geo.global_transform * geo.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box
