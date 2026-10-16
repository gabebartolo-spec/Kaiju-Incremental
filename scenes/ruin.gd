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
			var wobble := 0.9 + 0.1 * sin(atan2(cz, cx) * 3.0 + b.x) + rng.randf_range(-0.04, 0.04)
			var fall := 1.0 - sqrt(cx * cx + cz * cz) / wobble
			if fall <= 0.0:
				continue
			var h := maxi(1, roundi(peak * pow(fall, 0.8) + rng.randf_range(-1.5, 1.5)))
			var near_core := Vector2(x, z).distance_to(hot) < RES * 1.2
			for y: int in maxi(0, h):
				# Rubble comes down in chunks: one key per 2-4 cell block, not per voxel.
				var block := Vector3i(floori(x / 3.0), floori(y / 2.0), floori(z / 3.0))
				var key := keys[absi(hash(block + Vector3i(b.style, 0, 0))) % keys.size()]
				if y == h - 1 and near_core and rng.randf() < 0.55:
					key = "ember"  # one concentrated bed of glowing coals
				elif y >= h - 1 and near_core and absi(hash(block)) % 2 == 0:
					key = "char"  # scorch around the fire only
				vox.put(Vector3i(x, y, z), key)
	for corner: int in 2:  # standing stumps: two corners keep 1-3 floors of wall
		var cx0 := 0 if corner == 0 else w - RES * 2
		var cz0 := 0 if corner == 0 else d - RES * 2
		var floors := rng.randi_range(1, 2)
		for x: int in range(cx0, mini(w, cx0 + RES * 2)):
			for z: int in range(cz0, mini(d, cz0 + RES * 2)):
				var edge := x == 0 or z == 0 or x == w - 1 or z == d - 1 or x == cx0 or z == cz0
				if not edge:
					continue
				var top := roundi(peak) + RES * floors - rng.randi_range(0, RES)  # above the pile
				for y: int in maxi(RES, top):
					var key := (
						"stub_window" if y % RES in [1, 2] and (x + z) % 3 != 0 else "stub_wall"
					)
					vox.put(Vector3i(x, y, z), key)
	for slab_n: int in 3:  # big wall panels with window frames lying on the pile
		var sx := rng.randi_range(0, maxi(0, w - RES * 2))
		var sz := rng.randi_range(0, maxi(0, d - RES * 2))
		var lift := roundi(peak * 0.6)
		for px: int in RES * 2:
			for pz: int in roundi(RES * 1.5):
				var key := "stub_window" if px % 3 != 0 and pz % 4 in [1, 2] else "stub_wall"
				vox.put(Vector3i(sx + px, lift + roundi(pz * 0.3), sz + pz), key)
	vox.salt = b.style + 91
	return vox.build(rubble_palette(voxels), BuildingVoxels.VOXEL, 2.0, voxels.origin())


## Rubble is mostly pale broken concrete with a little of the building's own colour; the stubs
## keep the facade colours (keys starting "stub_"); coals and scorch only near the fire.
static func rubble_palette(voxels: BuildingVoxels) -> Dictionary:
	var palette := {}
	for key: String in voxels.palette:
		var c: Color = voxels.palette[key]
		palette[key] = Color(c.lerp(Color("6e706e"), 0.8), 1.0)
		palette["stub_" + key] = c
	palette["ember"] = Color(1.0, 0.45, 0.12, 0.0)
	palette["char"] = Color("2a2624")
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
