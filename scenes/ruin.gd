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
	var keys: Array[String] = ["wall", "wall", "wall", "slab", "slab", "trim", "window", "pillar"]
	var peak := 2.0 + b.tier * 1.5
	for x: int in range(-3, w + 3):
		for z: int in range(-3, d + 3):
			var cx := (x - w * 0.5) / (w * 0.5 + 3.0)
			var cz := (z - d * 0.5) / (d * 0.5 + 3.0)
			var fall := 1.0 - sqrt(cx * cx + cz * cz)
			var h := roundi(peak * fall + rng.randf_range(-1.5, 1.5))
			for y: int in maxi(0, h):
				vox.put(Vector3i(x, y, z), keys[rng.randi_range(0, keys.size() - 1)])
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
	vox.salt = b.style + 91
	var glow := Look.value("window_glow")
	return vox.build(voxels.palette, BuildingVoxels.VOXEL, glow, voxels.origin())
