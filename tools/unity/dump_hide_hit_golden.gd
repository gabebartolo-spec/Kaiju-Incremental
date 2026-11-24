extends SceneTree
## Writes where Godot's shots meet the croc's hide (KaijuModel.hide_cast, SkinHits) and the wounds
## they leave, so the Unity port (unity/Assets/Scripts/GameLogic/SkinHits.cs, HideEye.cs) can be
## checked against it ray for ray.
##
##   godot --headless --fixed-fps 60 --path . --script tools/unity/dump_hide_hit_golden.gd
##
## Output: unity/SimTests/golden/hide_hit.txt, read by HideHitCheck
## (`dotnet run --project unity/SimTests`). The skin's pose after a short walk (POSE, one per bone,
## rest -> rig as basis x, y, z then origin), the rig's world transform (RIG), then one RAY per
## shot with its hit (t, point, normal, rest, bone, cell, eye) or MISS, then the wounds those hits
## leave once aged (WOUND, LIVE).

const OUT := "res://unity/SimTests/golden/hide_hit.txt"
const SPECIES := "reptilian"
const FRAMES := 40
const AIMED := 72
const EYE_SHOTS := 8
const MISSES := 6
const AGE_FRAMES := 90

var _lines: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var def: Dictionary = Content.species_def(SPECIES)
	var colors: Dictionary = def["colors"]
	var model := KaijuModel.new(SPECIES, colors, "adult")
	root.add_child(model)
	model.position = Vector3(3.5, 0.25, -2.0)
	model.rotation.y = 0.7
	model.scale = Vector3.ONE * 1.3
	await process_frame
	var dt := 1.0 / 60.0
	for _f: int in FRAMES:
		model.animate(dt, 1.0)
	var skin: VoxelSkin = model._skin
	var hits := skin.hits
	var rig: Transform3D = model._rig.global_transform
	_lines.append("VOXEL %s BONES %d EYE %s" % [_g(hits.voxel), skin.pose.size(), str(colors["eye"])])
	_lines.append("RIG %s" % _xf(rig))
	for b: int in skin.pose.size():
		_lines.append("POSE %d %s" % [b, _xf(Transform3D(skin.pose[b]))])
	var rng := RandomNumberGenerator.new()
	rng.seed = 484
	var targets := _targets(model, hits, rng)
	var wounds := 0
	for shot: Array in targets:
		var from: Vector3 = shot[0]
		var to: Vector3 = shot[1]
		var hit := model.hide_cast(from, to)
		var line := "RAY %s %s" % [_v(from), _v(to)]
		if hit.is_empty():
			_lines.append(line + " MISS")
			continue
		var c: Vector3i = hit["cell"]
		var t: float = hit["t"]
		var point: Vector3 = hit["point"]
		var normal: Vector3 = hit["normal"]
		var rest: Vector3 = hit["rest"]
		var bone: int = hit["bone"]
		var on_eye: bool = hit["eye"]
		_lines.append(
			(
				line
				+ " HIT %s %s %s %s %d %d %d %d %d"
				% [_g(t), _v(point), _v(normal), _v(rest), bone, c.x, c.y, c.z, 1 if on_eye else 0]
			)
		)
		if not on_eye:
			hits.add_wound(rest, 1.0 - 0.01 * wounds)
			wounds += 1
	for _f: int in AGE_FRAMES:
		model.animate(dt, 1.0)
	var w := hits.wounds()
	for i: int in w.size():
		_lines.append("WOUND %d %s %s %s %s" % [i, _g(w[i].x), _g(w[i].y), _g(w[i].z), _g(w[i].w)])
	_lines.append("LIVE %d AGED %d" % [hits.live(), AGE_FRAMES])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("wrote %s (%d lines, %d wounds)" % [OUT, _lines.size(), wounds])
	quit()


## Shots aimed through random cubes' centres from random sides (some at the eyes), and a few that
## pass clear of him.
func _targets(model: KaijuModel, hits: SkinHits, rng: RandomNumberGenerator) -> Array:
	var skin: VoxelSkin = model._skin
	var rig: Transform3D = model._rig.global_transform
	var eye: Color = model._colors.get("eye", Color.BLACK)
	var all: Array = []
	var eyes: Array = []
	for b: int in hits._cells.size():
		for cell: Vector3i in hits._cells[b]:
			all.append([b, cell])
			var c: Color = hits._cells[b][cell]
			if KaijuModel._near(c, eye) or KaijuModel._near(c, KaijuModel.IVORY):
				eyes.append([b, cell])
	var out: Array = []
	for i: int in AIMED + EYE_SHOTS:
		var pick: Array = (
			eyes[rng.randi() % eyes.size()]
			if i >= AIMED and not eyes.is_empty()
			else all[rng.randi() % all.size()]
		)
		var b: int = pick[0]
		var cell: Vector3i = pick[1]
		var rest := Vector3(cell.x, cell.y + 0.5, cell.z) * hits.voxel
		var p := skin.pose[b]
		var full := rig * Transform3D(Basis(Vector3(p.x.x, p.x.y, p.x.z), Vector3(p.y.x, p.y.y, p.y.z), Vector3(p.z.x, p.z.y, p.z.z)), Vector3(p.w.x, p.w.y, p.w.z))
		var at := full * rest
		var dir := Vector3.FORWARD.rotated(Vector3.RIGHT, rng.randf_range(-0.6, 0.9))
		dir = dir.rotated(Vector3.UP, rng.randf_range(-PI, PI))
		out.append([at - dir * 30.0, at + dir * 4.0])
	for i: int in MISSES:
		var side := Vector3(60.0, 20.0 + i, -40.0 + 10.0 * i)
		out.append([side, side + Vector3(0, 0, 25)])
	return out


static func _g(x: float) -> String:
	return "%.7f" % x


static func _v(v: Vector3) -> String:
	return "%s %s %s" % [_g(v.x), _g(v.y), _g(v.z)]


static func _xf(t: Transform3D) -> String:
	return "%s %s %s %s" % [_v(t.basis.x), _v(t.basis.y), _v(t.basis.z), _v(t.origin)]
