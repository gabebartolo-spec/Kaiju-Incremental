class_name Ruin
extends RefCounted
## What is left when a building is gone: a heap of its own voxels spilling past the footprint,
## with ragged wall stubs still standing on a couple of sides. Cosmetic, seeded, built once.

const RES := BuildingVoxels.RES


## Builds the ruin for a building whose palette and footprint come from `voxels`.
static func build(voxels: BuildingVoxels, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var b := voxels.b
	var w := b.w * RES
	var d := b.d * RES
	var vox := VoxelBuilder.new()
	var keys: Array[String] = ["wall", "wall", "wall", "wall", "pillar", "trim", "slab", "window"]
	var peak := RES * (2.4 + b.tier * 0.9)
	var spill := RES + 2
	var hot := Vector2(w * rng.randf_range(0.35, 0.65), d * rng.randf_range(0.35, 0.65))
	for x: int in range(-spill, w + spill):
		for z: int in range(-spill, d + spill):
			var cx := (x - w * 0.5) / (w * 0.5 + spill)
			var cz := (z - d * 0.5) / (d * 0.5 + spill)
			# A lumpy outline: the radius wobbles with direction, so the heap is no rectangle.
			var wobble := (
				0.75 + 0.25 * sin(atan2(cz, cx) * 3.0 + b.x) + rng.randf_range(-0.12, 0.12)
			)
			var fall := 1.0 - sqrt(cx * cx + cz * cz) / wobble
			if fall <= 0.0:
				continue
			var h := maxi(1, roundi(peak * pow(fall, 0.8) + rng.randf_range(-1.5, 1.5)))
			var near_core := Vector2(x, z).distance_to(hot) < RES * 0.8
			for y: int in maxi(0, h):
				# Rubble comes down in chunks: one key per 2-4 cell block, not per voxel.
				var block := Vector3i(floori(x / 3.0), floori(y / 2.0), floori(z / 3.0))
				var key := keys[absi(hash(block + Vector3i(b.style, 0, 0))) % keys.size()]
				if y == h - 1 and near_core and rng.randf() < 0.55:
					key = "ember"  # one concentrated bed of glowing coals
				elif y >= h - 1 and absi(hash(block)) % 3 == 0:
					key = "char"  # scorched patches
				vox.put(Vector3i(x, y, z), key)
	for side: int in 2:  # ragged wall stubs on two faces
		var along_x := rng.randf() < 0.5
		var fixed := 0 if side == 0 else (d - 1 if along_x else w - 1)
		var length := w if along_x else d
		for p: int in length:
			var top := (
				rng.randi_range(RES, RES * (1 + mini(b.height - 1, 3))) - absi(p - (length >> 1))
			)
			for y: int in maxi(0, top):
				var cell := Vector3i(p, y, fixed) if along_x else Vector3i(fixed, y, p)
				var key := "window" if y % RES in [1, 2] and p % 3 != 0 else "wall"
				vox.put(cell, key)
	for slab_n: int in 3:  # broken floor slabs leaning against the heap
		var sx := rng.randi_range(0, w - 1)
		var sz := rng.randi_range(0, d - 1)
		var tilt := rng.randf_range(0.4, 0.9)
		for t: int in RES * 3:
			for side: int in RES:
				var cell := Vector3i(sx + t, roundi(t * tilt) + 1, sz + side)
				vox.put(cell, "slab")
	vox.salt = b.style + 91
	return vox.build(rubble_palette(voxels), BuildingVoxels.VOXEL, 2.0, voxels.origin())


## The building's colours dulled to dusty, broken rubble, plus coals and scorch.
static func rubble_palette(voxels: BuildingVoxels) -> Dictionary:
	var palette := {}
	for key: String in voxels.palette:
		var c: Color = voxels.palette[key]
		palette[key] = Color(c.darkened(0.35).lerp(Color("4a4a48"), 0.35), 1.0)
	palette["ember"] = Color(1.0, 0.45, 0.12, 0.0)
	palette["char"] = Color("201c1a")
	return palette


## The pile a toppled tower leaves along the street: chunky voxels in its own colours, a floor or
## two high along the middle of the strip, thinning at the edges.
static func strip(
	voxels: BuildingVoxels, from: Vector3, to: Vector3, width: float
) -> MultiMeshInstance3D:
	var vox := VoxelBuilder.new()
	var keys: Array[String] = ["wall", "wall", "wall", "pillar", "trim", "slab", "window", "char"]
	var along := to - from
	var length := along.length()
	var dir := along / maxf(0.001, length)
	var side := Vector3(-dir.z, 0, dir.x)
	var cells := roundi(length * RES)
	var half := roundi(width * 0.5 * RES) + 1
	for t: int in cells:
		for s: int in range(-half, half + 1):
			var across := absf(float(s)) / half
			var h := roundi(
				RES * 1.6 * (1.0 - across * across) + float(absi(hash(Vector2i(t, s))) % 3)
			)
			var p := from + dir * (t / float(RES)) + side * (s / float(RES))
			var base := Vector3i((p / BuildingVoxels.VOXEL).round())
			for y: int in maxi(1, h):
				var block := Vector3i(floori(t / 3.0), floori(y / 2.0), floori(s / 3.0))
				vox.put(base + Vector3i(0, y, 0), keys[absi(hash(block)) % keys.size()])
	vox.salt = 57
	return vox.build(rubble_palette(voxels), BuildingVoxels.VOXEL, 1.0, Vector3.ZERO)
