class_name CephalopodStandIn
extends RefCounted
## A code-built octopus kaiju for the radial gait until the sculpt exists: a mantle and head
## with eyes, eight tentacles (six bones each) splayed on the ground, suckers underneath.
## Same rig format as tools/blender/rig_voxel.py writes for a "radial" body.

const ARMS := 8
const SEGMENTS := 6
## Rig units (the model is about 10 tall at body scale 1); voxels per unit.
const PER_UNIT := 8.0
const MANTLE := Vector3(0, 3.6, 1.5)
const MANTLE_R := Vector3(1.8, 2.2, 2.5)
const HEAD := Vector3(0, 2.0, -0.5)
const HEAD_R := 1.6
## Tentacles: root ring radius and height, reach along the ground, thickness root -> tip.
const ROOT_RING := 1.3
const ROOT_Y := 1.2
const REACH := 9.5
const THICK := Vector2(0.8, 0.15)


static func build(colors: Dictionary, model_height: float, glow: float) -> KaijuRig:
	var body := Color(str(colors.get("body", "4a2a36")))
	var belly := Color(str(colors.get("belly", "9a7a78")))
	var accent := Color(str(colors.get("accent", "1e1016")))
	var eye := Color(str(colors.get("eye", "ffd23a")))
	var vox := VoxelBuilder.new()
	var v := 1.0 / PER_UNIT
	var bones: Array = [
		{
			"name": "mantle0",
			"parent": null,
			"head": _cells(Vector3(0, 1.0, 0.4), v),
			"tail": _cells(MANTLE + Vector3(0, MANTLE_R.y, 0), v),
			"physics": false,
		}
	]
	_ellipsoid(vox, MANTLE, MANTLE_R, v, body, accent, 0)
	_ellipsoid(vox, HEAD, Vector3.ONE * HEAD_R, v, body, accent, 0)
	for side: int in [-1, 1]:
		var at := HEAD + Vector3(side * HEAD_R * 0.85, 0.35, -0.5)
		_ellipsoid(vox, at, Vector3(0.45, 0.55, 0.45), v, eye, eye, 0)
		vox.put_color(Vector3i((at + Vector3(side * 0.42, 0, -0.1)) / v), Color("15130f"))
	for arm: int in ARMS:
		_arm(vox, bones, arm, [v, body, belly])
	vox.height_hint = roundi((MANTLE.y + MANTLE_R.y) / v)
	var spec := {"type": "radial", "bones": bones}
	var scale := model_height / ((MANTLE.y + MANTLE_R.y) / v)
	return KaijuRig.from_spec(spec, vox, scale, glow)


## Arm `arm` of the ring: its joints out from the mantle, a bone per segment (appended to `bones`)
## and a tapering tube of voxels. `look` is [voxel size, body colour, belly colour].
static func _arm(vox: VoxelBuilder, bones: Array, arm: int, look: Array) -> void:
	var v: float = look[0]
	var body: Color = look[1]
	var belly: Color = look[2]
	var angle := TAU * (arm + 0.5) / ARMS
	var dir := Vector3(sin(angle), 0, -cos(angle))
	var joints: Array[Vector3] = []
	for j: int in SEGMENTS + 1:
		var f := float(j) / SEGMENTS
		var r := ROOT_RING + REACH * f
		var y := lerpf(ROOT_Y, lerpf(THICK.x, THICK.y, f), sqrt(f))
		joints.append(dir * r + Vector3(0, y, 0))
	var parent := "mantle0"
	for j: int in SEGMENTS:
		var name := "tentacle%d_%d" % [arm, j]
		(
			bones
			. append(
				{
					"name": name,
					"parent": parent,
					"head": _cells(joints[j], v),
					"tail": _cells(joints[j + 1], v),
					"physics": true,
				}
			)
		)
		var index := bones.size() - 1
		var r0 := lerpf(THICK.x, THICK.y, float(j) / SEGMENTS)
		var r1 := lerpf(THICK.x, THICK.y, float(j + 1) / SEGMENTS)
		_tube(vox, joints[j], joints[j + 1], Vector2(r0, r1), v, [body, belly], index)
		parent = name


static func _cells(p: Vector3, v: float) -> Array:
	return [p.x / v, p.y / v, p.z / v]


static func _ellipsoid(
	vox: VoxelBuilder, c: Vector3, r: Vector3, v: float, color: Color, speck: Color, bone: int
) -> void:
	var lo := Vector3i(((c - r) / v).floor())
	var hi := Vector3i(((c + r) / v).ceil())
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				var p := (Vector3(x, y, z) + Vector3.ONE * 0.5) * v - c
				var q := Vector3(p.x / r.x, p.y / r.y, p.z / r.z).length()
				if q > 1.0 or q < 1.0 - 2.5 * v / minf(r.x, minf(r.y, r.z)):
					continue  # the shell only
				var cell := Vector3i(x, y, z)
				var k := absi(hash(cell)) % 100
				vox.put_color(cell, speck if k < 10 else color.darkened(0.08 * (k % 3)))
				if bone != 0:
					vox.flags[cell] = bone


## A tapering tube, belly-coloured underneath with sucker dots.
static func _tube(
	vox: VoxelBuilder, a: Vector3, b: Vector3, r: Vector2, v: float, tones: Array, bone: int
) -> void:
	var body: Color = tones[0]
	var belly: Color = tones[1]
	var steps := maxi(2, ceili(a.distance_to(b) / v))
	for i: int in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var rr := lerpf(r.x, r.y, t)
		var n := ceili(rr / v)
		for x: int in range(-n, n + 1):
			for y: int in range(-n, n + 1):
				for z: int in range(-n, n + 1):
					var off := Vector3(x, y, z) * v
					var d := off.length()
					if d > rr or d < rr - 2.0 * v:
						continue
					var cell := Vector3i(((p + off) / v).floor())
					if vox.cells.has(cell) and vox.flags.get(cell, 0) == bone:
						continue
					var under := off.y < -rr * 0.35
					var sucker := under and posmod(cell.x * 3 + cell.z * 5, 7) == 0
					var color := belly.lightened(0.25) if sucker else (belly if under else body)
					vox.put_color(cell, color)
					vox.flags[cell] = bone
