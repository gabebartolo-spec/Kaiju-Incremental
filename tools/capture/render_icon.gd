extends SceneTree
## Renders a model to a UI icon: a transparent square PNG (512 px) plus a small preview (80 px),
## 3/4 view, in the game's own light and look with the HUD's dark outline (IconStage), in two
## styles: "voxel" (the model voxelized through the game's voxel pipeline, IconVoxelizer) and
## "smooth" (the model as it is). Any lightning or beam is our own FX laid in the render (IconFx),
## never geometry of the model. Needs a window (the off-screen no_focus override.cfg, local GPU):
##
##   godot --path . --windowed --resolution 640x640 --script tools/capture/render_icon.gd -- \
##     --model=<file.glb|file.kvox> --style=both --out=<dir> --name=croc_head \
##     [--crop=x0,y0,z0,x1,y1,z1]   shares of the model's box to keep (the head: 0,0.5,0,1,1,0.4)
##     [--cells=32]                 voxels across the kept part's longest side (reads at 80 px)
##     [--face=0,0,-1] [--yaw=38] [--pitch=14] [--fov=28] [--size=512] [--preview=80]
##     [--fx=none|lightning|beam]
##     [--mouth=0.5,0.35,0.0]       shares of the kept part: where the FX leaves
##     [--rotate=0]                 turns the model about up first (deg), if it faces another way

const Voxelizer := preload("res://tools/capture/icon_voxelizer.gd")
const Stage := preload("res://tools/capture/icon_stage.gd")
const Fx := preload("res://tools/capture/icon_fx.gd")

var _opts: Dictionary[String, String] = {
	"model": "",
	"style": "both",
	"out": "user://icons",
	"name": "icon",
	"crop": "0,0,0,1,1,1",
	"cells": "32",
	"face": "0,0,-1",
	"yaw": "38",
	"pitch": "14",
	"fov": "28",
	"size": "512",
	"preview": "80",
	"fx": "none",
	"mouth": "0.5,0.35,0",
	"rotate": "0",
}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			_opts[arg.get_slice("=", 0).substr(2)] = arg.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(str(_opts["out"]))
	var styles: Array[String] = (
		["voxel", "smooth"] if _opts["style"] == "both" else [str(_opts["style"])]
	)
	for style: String in styles:
		var made := await _icon(style)
		if made.is_empty():
			push_error("render_icon: nothing rendered for %s" % style)
			quit(1)
			return
	quit()


func _icon(style: String) -> Dictionary:
	var model := _load_model(style)
	if model.is_empty():
		return {}
	var subject: Node3D = model["node"]
	var fit: AABB = model["fit"]
	var size := int(_opts["size"])
	var render_opts := {
		"yaw": float(_opts["yaw"]),
		"pitch": float(_opts["pitch"]),
		"fov": float(_opts["fov"]),
		"face": _vec(str(_opts["face"])),
	}
	if _opts["fx"] != "none":
		var shares := _vec(str(_opts["mouth"]))
		var mouth := fit.position + fit.size * shares
		var toward := Stage.view_from(
			_vec(str(_opts["face"])),
			deg_to_rad(float(_opts["yaw"])),
			deg_to_rad(float(_opts["pitch"]))
		)
		render_opts["fx"] = Fx.build(
			str(_opts["fx"]), mouth, _vec(str(_opts["face"])), fit.size.length(), -toward
		)
	var image := await Stage.render(self, subject, fit, size, render_opts)
	var base := str(_opts["out"]).path_join("%s_%s" % [_opts["name"], style])
	image.save_png(base + "_%d.png" % size)
	Stage.preview(image, int(_opts["preview"])).save_png(base + "_%d.png" % int(_opts["preview"]))
	var voxels: int = model.get("voxels", 0)
	print("render_icon: %s (%d voxels)" % [base, voxels])
	return {"ok": true}


## {"node", "fit", "voxels"} for one style of the model, or {}.
func _load_model(style: String) -> Dictionary:
	var path := str(_opts["model"])
	var frac := PackedFloat32Array()
	for s: String in str(_opts["crop"]).split(","):
		frac.append(float(s))
	if path.get_extension() == "kvox":
		return _kvox(path, frac) if style == "voxel" else {}
	var scene := Voxelizer.load_glb(path)
	if scene == null:
		push_error("render_icon: cannot read %s" % path)
		return {}
	scene.rotate_y(deg_to_rad(float(_opts["rotate"])))
	var parts: Array[Voxelizer.Part] = Voxelizer.surfaces(scene)
	var whole := Voxelizer.bounds(parts)
	var crop := Voxelizer.crop_box(whole, frac)
	if style == "smooth":
		return {"node": Voxelizer.smooth(parts, crop), "fit": crop}
	var voxel := maxf(crop.size.x, maxf(crop.size.y, crop.size.z)) / float(_opts["cells"])
	var builder := Voxelizer.voxelize(parts, crop, voxel)
	var holder := Node3D.new()
	holder.add_child(builder.build({}, voxel, 0.0, crop.position))
	return {"node": holder, "fit": crop, "voxels": builder.cells.size()}


## One of our .kvox models, cropped, drawn by the game's own voxel build.
func _kvox(path: String, frac: PackedFloat32Array) -> Dictionary:
	var model := Kvox.read(path)
	if model.frames.is_empty():
		push_error("render_icon: cannot read %s" % path)
		return {}
	var all := model.frames[0]
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := Vector3i(-(1 << 20), -(1 << 20), -(1 << 20))
	for cell: Vector3i in all.cells:
		lo = lo.min(cell)
		hi = hi.max(cell)
	var span := Vector3(hi - lo + Vector3i.ONE)
	var keep_lo := Vector3(lo) + span * Vector3(frac[0], frac[1], frac[2])
	var keep_hi := Vector3(lo) + span * Vector3(frac[3], frac[4], frac[5])
	var part := VoxelBuilder.new()
	part.salt = 7
	var kept_lo := Vector3(1e9, 1e9, 1e9)
	var kept_hi := Vector3(-1e9, -1e9, -1e9)
	for cell: Vector3i in all.cells:
		var c := Vector3(cell)
		if c.x < keep_lo.x or c.y < keep_lo.y or c.z < keep_lo.z:
			continue
		if c.x >= keep_hi.x or c.y >= keep_hi.y or c.z >= keep_hi.z:
			continue
		var col: Color = all.colors[cell]
		part.put_color(cell, col)
		kept_lo = kept_lo.min(c)
		kept_hi = kept_hi.max(c + Vector3.ONE)
	var voxel := 1.0
	var holder := Node3D.new()
	holder.add_child(part.build({}, voxel, 0.0, Vector3.ZERO))
	return {"node": holder, "fit": AABB(kept_lo, kept_hi - kept_lo), "voxels": part.cells.size()}


static func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
