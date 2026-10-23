extends SceneTree
## Fits the sim's tail chain (tuning body_class <class> tail "chain", D-208) to a kaiju's drawn
## tail: for each tail bone, its length over the ground and the half-width of its voxels across the
## bone (the mesh's reach to either side), and the lowest and highest its voxels reach over every
## frame of the clips. Rig units are body-scale-1 units. Prints the JSON to paste. Headless is fine.
##
##   godot --headless --path . --script tools/capture/fit_tail_chain.gd -- --stage=adult

const Kit := preload("res://tools/capture/capture_kit.gd")
const CLIPS: Array[String] = ["walk", "idle", "roar", "turn_left"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var a := Kit.args({"stage": "adult"})
	var def := Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, str(a["stage"]))
	root.add_child(kaiju)
	await process_frame
	var rig: KaijuRig = kaiju._rig
	var g: ClipGait = rig.gait
	var clips := g.clips
	var spec: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/kaiju/%s.rig.json" % rig.kind)
	)
	var model := Kvox.read("res://assets/kaiju/%s.kvox" % rig.kind)
	var voxel := rig._voxel
	var defs: Array = spec["bones"]
	var names: Array[String] = []
	for d: Dictionary in defs:
		names.append(str(d["name"]))
	var tails: Array[String] = []
	var points := {}  # tail bone -> its voxel centres in the bone's rest frame (rig units)
	for name: String in names:
		if name.begins_with("tail"):
			tails.append(name)
			points[name] = []
	var vox: VoxelBuilder = model.frames[0]
	for cell: Vector3i in vox.cells:
		var index: int = vox.flags.get(cell, 0)  # the bone's index, as KaijuRig._build reads it
		var name := names[index]
		if points.has(name):
			var list: Array = points[name]
			list.append(Vector3(cell) * voxel + Vector3.ONE * voxel * 0.5 - rig.head_of(name))
	var lo: Array[float] = []
	var hi: Array[float] = []
	for n: String in tails:
		lo.append(INF)
		hi.append(-INF)
	var to_rig := rig.global_transform.affine_inverse()
	for clip: String in CLIPS:
		for f: int in clips.frames_of(clip):
			var pose := clips.pose_at(clip, f)
			for i: int in clips.bones.size():
				var off := pose.offset * clips.rig_scale if i == 0 else Vector3.ZERO
				rig.pose_basis(clips.bones[i], Basis(pose.turns[i]), off)
			for k: int in tails.size():
				var to_bone := to_rig * rig.bone(tails[k]).global_transform
				for p: Vector3 in points[tails[k]]:
					var y := (to_bone * p).y
					lo[k] = minf(lo[k], y)
					hi[k] = maxf(hi[k], y)
	var chain: Array = []
	for k: int in tails.size():
		var h := rig.head_of(tails[k])
		var t := rig.head_of(tails[k + 1]) if k + 1 < tails.size() else h + rig.dir_of(tails[k])
		var across := 0.0
		for p: Vector3 in points[tails[k]]:
			across = maxf(across, absf(p.x))
		var flat := Vector2(t.x - h.x, t.z - h.z).length()
		chain.append([snappedf(flat, 0.01), snappedf(across, 0.01), snappedf(lo[k], 0.01), snappedf(hi[k], 0.01)])
	var root_at := rig.head_of(tails[0])
	print("TAIL_ROOT %s" % JSON.stringify([snappedf(-root_at.z, 0.01)]))
	print("TAIL_CHAIN %s" % JSON.stringify(chain))
	quit()
