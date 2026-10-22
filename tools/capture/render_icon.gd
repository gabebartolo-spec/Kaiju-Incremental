extends SceneTree
## Renders a model to a UI icon: a transparent square PNG (256 px) plus a small preview (80 px),
## 3/4 view, in the game's own light and look with the HUD's dark outline (IconStage), in two
## styles: "voxel" (the model voxelized through the game's voxel pipeline, IconVoxelizer) and
## "smooth" (the model as it is). Any lightning or beam is our own FX laid in the render (IconFx),
## never geometry of the model. Needs a window (the off-screen no_focus override.cfg, local GPU):
##
##   godot --path . --windowed --resolution 640x640 --script tools/capture/render_icon.gd -- \
##     --model=<file.glb|file.kvox> --style=both --out=<dir> --name=croc_head \
##     [--crop=x0,y0,z0,x1,y1,z1]   shares of the model's box to keep (the head: 0,0.5,0,1,1,0.4)
##     [--cells=32]                 voxels across the kept part's longest side (reads at 80 px)
##     [--face=0,0,-1] [--yaw=38] [--pitch=14] [--fov=28] [--size=256] [--preview=80]
##     [--yaw=0,90,180]             several yaws: one icon each, named _y<yaw>
##     [--margin=0.16]              share of the frame kept clear round the model
##     [--fx=none|lightning|beam|dash] [--aim=x,y,z]   the FX's way (default: --face)
##     [--reach=1.0]                the FX's length, in model sizes
##     [--exposure=1.0]             brighter than the game's (an icon sits on a dark disc)
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
	"size": "256",
	"preview": "80",
	"fx": "none",
	"mouth": "0.5,0.35,0",
	"rotate": "0",
	"margin": "0.16",
	"aim": "",
	"reach": "1.0",
	"exposure": "1.0",
}
var _scene: Node3D
var _parts: Array[Voxelizer.Part] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			_opts[arg.get_slice("=", 0).substr(2)] = arg.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(str(_opts["out"]))
	var styles: Array[String] = []
	if _opts["style"] == "both":
		styles.assign(["voxel", "smooth"])
	else:
		styles.append(str(_opts["style"]))
	var yaws := str(_opts["yaw"]).split(",")
	for style: String in styles:
		var model := _load_model(style)
		if model.is_empty():
			push_error("render_icon: nothing rendered for %s" % style)
			quit(1)
			return
		for yaw: String in yaws:
			var tag := "" if yaws.size() == 1 else "_y%s" % yaw
			await _icon(model, style, float(yaw), tag)
	quit()


## Renders one view of a loaded model: the master (--size) and the preview (--preview) PNGs.
func _icon(model: Dictionary, style: String, yaw: float, tag: String) -> void:
	var source: Node3D = model["node"]
	var subject: Node3D = source.duplicate()
	var fit: AABB = model["fit"]
	var size := int(_opts["size"])
	var face := _vec(str(_opts["face"]))
	var render_opts := {
		"yaw": yaw,
		"pitch": float(_opts["pitch"]),
		"fov": float(_opts["fov"]),
		"face": face,
		"margin": float(_opts["margin"]),
		"exposure": float(_opts["exposure"]),
	}
	if _opts["fx"] != "none":
		var mouth := fit.position + fit.size * _vec(str(_opts["mouth"]))
		var aim := _vec(str(_opts["aim"])) if _opts["aim"] != "" else face
		var toward := Stage.view_from(face, deg_to_rad(yaw), deg_to_rad(float(_opts["pitch"])))
		var fx := Fx.build(
			str(_opts["fx"]), mouth, aim, fit.size.length(), float(_opts["reach"]), -toward
		)
		render_opts["fx"] = fx
		render_opts["frame"] = fit.merge(Fx.bounds(fx))
	var image := await Stage.render(self, subject, fit, size, render_opts)
	var base := str(_opts["out"]).path_join("%s_%s%s" % [_opts["name"], style, tag])
	image.save_png(base + "_%d.png" % size)
	Stage.preview(image, int(_opts["preview"])).save_png(base + "_%d.png" % int(_opts["preview"]))
	print("render_icon: %s (%d voxels)" % [base, Num.i(model.get("voxels", 0))])


## {"node", "fit", "voxels"} for one style of the model, or {}. The GLB is read once.
func _load_model(style: String) -> Dictionary:
	var path := str(_opts["model"])
	var frac := PackedFloat32Array()
	for s: String in str(_opts["crop"]).split(","):
		frac.append(float(s))
	if path.get_extension() == "kvox":
		return _kvox(path, frac) if style == "voxel" else {}
	if _scene == null:
		_scene = Voxelizer.load_glb(path)
		if _scene == null:
			push_error("render_icon: cannot read %s" % path)
			return {}
		_scene.rotate_y(deg_to_rad(float(_opts["rotate"])))
		_parts = Voxelizer.surfaces(_scene)
	var whole := Voxelizer.bounds(_parts)
	var crop := Voxelizer.crop_box(whole, frac)
	if style == "smooth":
		if crop.is_equal_approx(whole):
			return {"node": _scene, "fit": whole}
		return {"node": Voxelizer.smooth(_parts, crop), "fit": crop}
	var voxel := maxf(crop.size.x, maxf(crop.size.y, crop.size.z)) / float(_opts["cells"])
	var builder := Voxelizer.voxelize(_parts, crop, voxel)
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
