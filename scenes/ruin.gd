class_name Ruin
extends RefCounted
## What is left when a building is gone: a low heap of its own voxels spilling past the
## footprint, nothing standing (director 2026-10-20: "they were previously reduced to rubble then
## emerge from the ground as flaming buildings"; the wall stubs that rose here are gone). Cold
## broken concrete and brick: no glowing coals or scorch ("we are removing the smouldering
## ruins", #111, R 26.1). Cosmetic, seeded, built once.

const RES := BuildingVoxels.RES
## A chunk's voxel shading salt is drawn below this (chunk()).
const SALTS := 997


## Builds the ruin for a building whose palette and footprint come from `voxels`.
static func build(voxels: BuildingVoxels, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	return heap(voxels, rng).build(
		rubble_palette(voxels), BuildingVoxels.VOXEL, 2.0, voxels.origin()
	)


## The ruin's cells (tests read them; build() draws them).
static func heap(voxels: BuildingVoxels, rng: RandomNumberGenerator) -> VoxelBuilder:
	var b := voxels.b
	var w := b.w * RES
	var d := b.d * RES
	var vox := VoxelBuilder.new()
	var keys: Array[String] = ["wall", "wall", "wall", "wall", "pillar", "trim", "slab", "window"]
	var peak := RES * (2.4 + b.tier * 0.9)
	var spill := RES + 2
	for x: int in range(-spill, w + spill):
		for z: int in range(-spill, d + spill):
			var cx := (x - w * 0.5) / (w * 0.5 + spill)
			var cz := (z - d * 0.5) / (d * 0.5 + spill)
			# A lumpy outline: the radius wobbles with direction, so the heap is no rectangle.
			var wobble := 0.9 + 0.1 * sin(atan2(cz, cx) * 3.0 + b.x) + rng.randf_range(-0.04, 0.04)
			var fall := 1.0 - sqrt(cx * cx + cz * cz) / wobble
			if fall <= 0.0:
				continue
			var h := maxi(1, roundi(peak * pow(fall, 0.8) + rng.randf_range(-1.5, 1.5)))
			for y: int in maxi(0, h):
				# Rubble comes down in chunks: one key per 2-4 cell block, not per voxel.
				var block := Vector3i(floori(x / 3.0), floori(y / 2.0), floori(z / 3.0))
				var key := keys[absi(hash(block + Vector3i(b.style, 0, 0))) % keys.size()]
				vox.put(Vector3i(x, y, z), key)
	vox.salt = b.style + 91
	return vox


## Rubble is mostly pale broken concrete with a little of the building's own colour, and some
## dark broken blocks ("char", the toppled strip's variety).
static func rubble_palette(voxels: BuildingVoxels) -> Dictionary:
	var palette := {}
	for key: String in voxels.palette:
		var c: Color = voxels.palette[key]
		palette[key] = Color(c.lerp(Color("6e706e"), 0.8), 1.0)
	palette["char"] = Color("2a2624")
	return palette


## The pile a toppled tower leaves along the street: chunky voxels in its own colours, a floor or
## two high along the middle of the strip, thinning at the edges. cfg (the "topple_fx" tuning,
## optional): rubble_block cells per colour block and per lump step, rubble_lump (floors a block
## rises or sinks), rubble_tint/rubble_tint_mix (pale concrete, so the heap stands out of the
## dark street).
static func strip(
	voxels: BuildingVoxels, from: Vector3, to: Vector3, width: float, cfg: Dictionary = {}
) -> MultiMeshInstance3D:
	if voxels is LandmarkVoxels:  # a ragged heap against the stub, in the model's colours
		return LandmarkRubble.heap(voxels as LandmarkVoxels, from, to, width)
	var vox := VoxelBuilder.new()
	var keys: Array[String] = ["wall", "wall", "wall", "pillar", "trim", "slab", "window", "char"]
	var along := to - from
	var length := along.length()
	var dir := along / maxf(0.001, length)
	var side := Vector3(-dir.z, 0, dir.x)
	var cells := roundi(length * RES)
	var half := roundi(width * 0.5 * RES) + 1
	var blk: Array = cfg.get("rubble_block", [3, 2, 3])
	var bx := Num.f(blk[0])
	var by := Num.f(blk[1])
	var bz := Num.f(blk[2])
	var lump := Num.f(cfg.get("rubble_lump", 0.0)) * RES
	for t: int in cells:
		for s: int in range(-half, half + 1):
			var across := absf(float(s)) / half
			# Big blocks rise or sink together, so the heap reads as slabs, not voxel noise.
			var slab := Vector2i(floori(t / bx), floori(s / bz))
			var step := (float(absi(hash(slab)) % 3) - 1.0) * lump
			var h := roundi(
				RES * 1.6 * (1.0 - across * across) + step + float(absi(hash(Vector2i(t, s))) % 2)
			)
			var p := from + dir * (t / float(RES)) + side * (s / float(RES))
			var base := Vector3i((p / BuildingVoxels.VOXEL).round())
			for y: int in maxi(1, h):
				var block := Vector3i(slab.x, floori(y / by), slab.y)
				vox.put(base + Vector3i(0, y, 0), keys[absi(hash(block)) % keys.size()])
	vox.salt = 57
	var palette := rubble_palette(voxels)
	if cfg.has("rubble_tint"):
		var tint := Color(str(cfg["rubble_tint"]))
		for key: String in palette:
			var c: Color = palette[key]
			palette[key] = Color(c.lerp(tint, Num.f(cfg["rubble_tint_mix"])), c.a)
	return vox.build(palette, BuildingVoxels.VOXEL, 1.0, Vector3.ZERO)


## One big wall chunk thrown from a toppled tower: a lump of the building's own facade voxels
## (its wall and window colours, shaded like every other voxel), `size` sim units wide, centred
## on the node's origin. Replaces the flat-coloured boxes that read as untextured placeholders.
static func chunk(voxels: BuildingVoxels, size: Vector3, salt: int) -> MultiMeshInstance3D:
	var vox := VoxelBuilder.new()
	var palette := rubble_palette(voxels)
	var n := Vector3i((size * RES).round())
	var keys: Array[String] = []
	for key: String in ["stub_wall", "stub_wall", "stub_wall", "stub_pillar", "stub_trim"]:
		if palette.has(key):
			keys.append(key)  # a landmark's palette has its own key names
	var windows := palette.has("stub_window")
	if keys.is_empty():
		keys.append(str(palette.keys()[0]))
	for x: int in n.x:
		for y: int in n.y:
			for z: int in n.z:
				var key := keys[absi(hash(Vector3i(x / 3, y / 2, z / 3))) % keys.size()]
				if windows and x % 6 > 1 and y % RES in [2, 3, 4, 5]:
					key = "stub_window"
				vox.put(Vector3i(x, y, z), key)
	vox.salt = salt
	var centre := -Vector3(n) * 0.5 * BuildingVoxels.VOXEL
	return vox.build(palette, BuildingVoxels.VOXEL, 1.0, centre)
