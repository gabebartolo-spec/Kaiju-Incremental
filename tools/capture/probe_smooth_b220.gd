extends SceneTree
## Phase B (b2-20 round 2), never merged: headless numbers for the smooth meshes. A car's size
## (its AABB, voxel vs smooth) and its vertex count per --smooth-up; the kaiju skin's build time.

func _initialize() -> void:
	var palette := {"glass": Color("2b3640"), "wheel": Color("1a1a1a"), "tail": Color("6a1a1a"),
		"car0": Color("8a2a2a")}
	var v := VoxelBuilder.new()
	CityDecor.car(v, "car0", false)
	var box := AABB()
	var first := true
	for c: Vector3i in v.cells:
		var b := AABB(Vector3(c) - Vector3.ONE * 0.5, Vector3.ONE)
		box = b if first else box.merge(b)
		first = false
	print("CAR cells=%d voxel box size=%s" % [v.cells.size(), box.size])
	for up: int in [1, 2, 3]:
		VoxelBuilder.smooth_up = up
		var t := Time.get_ticks_msec()
		var m := v.smooth_mesh(palette, 1.0, Vector3.ZERO, 1.0)
		var a := m.get_aabb()
		print("CAR up=%d smooth box size=%s verts=%d ms=%d" % [up, a.size,
			m.surface_get_array_len(0), Time.get_ticks_msec() - t])
	quit()
