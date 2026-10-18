class_name LandmarkRubble
extends RefCounted
## The heap a landmark's toppled section leaves (Ruin.strip hands landmarks here): highest against
## the stub it broke from, thinning to nothing within about one wall height past the wall, with
## a ragged outline, in the model's own colours near the breach (pale wall, red seats), never a
## flat slab with grid edges. Cosmetic, seeded by where it lands, built once.

const RES := BuildingVoxels.RES
## How far behind the tipping edge the heap starts (over the stub), in sim units.
const BACK := 2.0
## The share of the fall's length the heap reaches past the edge, and its cap (sim units).
const REACH := 0.6
const REACH_MAX := 3.5
## Peak height (floors) against the stub.
const PEAK := 1.4
## Colours are sampled from model voxels this near the tipping edge (sim units).
const SAMPLE_RADIUS := 3.5
const PALE := Color("c4bfb3")


## from: the tipping edge on the ground; to: where the top landed; width: across the fall.
static func heap(
	voxels: LandmarkVoxels, from: Vector3, to: Vector3, width: float
) -> MultiMeshInstance3D:
	return pile(voxels, from, to, width).build({}, BuildingVoxels.VOXEL, 1.0, Vector3.ZERO)


## The heap's voxels (cells in world voxel units, colours DIRECT); heap() builds them.
static func pile(voxels: LandmarkVoxels, from: Vector3, to: Vector3, width: float) -> VoxelBuilder:
	var vox := VoxelBuilder.new()
	var palette := _colours(voxels, from)
	var along := to - from
	var dir := along / maxf(0.001, along.length())
	var side := Vector3(-dir.z, 0, dir.x)
	var reach := minf(along.length() * REACH, REACH_MAX)
	var seed := absi(hash(Vector3i((from * 4.0).round())))
	var t0 := -roundi(BACK * RES)
	var t1 := roundi(reach * RES)
	var half := width * 0.5 * RES
	for t: int in range(t0, t1 + 1):
		# Height falls off from the stub (t <= 0) to nothing at the far end; the outline wobbles.
		var u := clampf(float(t) / maxf(1.0, t1), 0.0, 1.0)
		var rise := clampf(float(t - t0) / (RES * 0.6), 0.0, 1.0)
		var top := RES * PEAK * pow(1.0 - u, 1.5) * rise
		var wobble := 0.75 + 0.35 * _noise(seed, t / 5.0)
		var shift := (_noise(seed + 7, t / 7.0) - 0.5) * RES * 0.8
		var reach_side := half * wobble * (1.0 - 0.45 * u)
		for s: int in range(-roundi(half * 1.2), roundi(half * 1.2) + 1):
			var across := absf(s - shift) / maxf(1.0, reach_side)
			if across > 1.0:
				continue
			var lump := float(absi(hash(Vector3i(t >> 1, s >> 1, seed))) % 5) - 2.0
			var h := roundi(top * (1.0 - across * across) + lump)
			if h <= 0:
				continue
			var p := from + dir * (t / float(RES)) + side * (s / float(RES))
			var base := Vector3i((p / BuildingVoxels.VOXEL).round())
			for y: int in h:
				var block := Vector3i(t / 3, y / 2, s / 3)
				vox.put_color(base + Vector3i(0, y, 0), palette[absi(hash(block)) % palette.size()])
	vox.salt = seed % 997
	return vox


## The model's colours near the breach (LandmarkVoxels.rubble_colors: not its ground colours),
## paled toward broken concrete and darkened at random so the heap reads as rubble.
static func _colours(voxels: LandmarkVoxels, at: Vector3) -> Array[Color]:
	var near: Array[Color] = []
	var origin := voxels.origin()
	for column: Vector2i in voxels.rubble_colors:
		var p := origin + Vector3(column.x + 0.5, 0, column.y + 0.5)
		if Vector2(p.x - at.x, p.z - at.z).length() <= SAMPLE_RADIUS:
			var found: Array = voxels.rubble_colors[column]
			for c: Color in found:
				near.append(c)
	var out: Array[Color] = []
	for k: int in 24:
		var c := PALE if near.is_empty() else near[absi(hash(k * 131)) % near.size()]
		var shade := 0.72 + 0.28 * float(absi(hash(k * 17)) % 100) / 100.0
		out.append(Color(c.lerp(PALE, 0.3) * shade, 1.0))
	return out


## Smooth 1D value noise in [0, 1].
static func _noise(seed: int, x: float) -> float:
	var k := floori(x)
	var f := x - k
	var a := float(absi(hash(Vector2i(seed, k))) % 1000) / 1000.0
	var b := float(absi(hash(Vector2i(seed, k + 1))) % 1000) / 1000.0
	return lerpf(a, b, f * f * (3.0 - 2.0 * f))
