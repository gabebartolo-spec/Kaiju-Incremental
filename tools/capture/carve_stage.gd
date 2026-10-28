extends RefCounted
## The capture stage for capture_carve_physics.gd: sky, light, road and the blow marker.


static func environment(world: Node3D) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	world.add_child(sun)


static func ground(world: Node3D) -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	shape.shape = box
	shape.position.y = -1.0
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4a4d50")
	plane.material = mat
	mesh.mesh = plane
	ground.add_child(mesh)
	world.add_child(ground)


static func sphere(world: Node3D, radius: float) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.2, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	s.mesh = sm
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.visible = false
	world.add_child(s)
	return s


static func print_holds(holds_list: Array[Dictionary]) -> void:
	for h: Dictionary in holds_list:
		var held: Array = h["holds"]
		var worst := 0.0
		var at := 0.0
		for pair: Array in held:
			var gap := Num.f(pair[1]) - Num.f(pair[0])
			if gap > worst:
				worst = gap
				at = Num.f(pair[1])
		print(
			(
				(
					"  HOLD building %d: %d break steps, longest wait from release or the last"
					+ " break %.2f s (at t=%.2f)"
				)
				% [h["n"], held.size(), worst, at]
			)
		)


static func print_stats(stats: Dictionary) -> void:
	for key: String in stats:
		var a: Array = stats[key]
		if a.is_empty():
			continue
		var sorted := a.duplicate()
		sorted.sort()
		var total := 0.0
		for x: float in a:
			total += x
		print(
			(
				"  %-5s avg %7.2f  p95 %7.2f  max %7.2f"
				% [key, total / maxi(1, a.size()), sorted[int(sorted.size() * 0.95)], sorted[-1]]
			)
		)


## Render plan items 10 and 11, into `stats`: the last frame's draw calls (every frame, and the
## frames an island falls) and each island remesh's main-thread swap (IslandMesh.last_swap_us).
static func record_render(phys: CarvePhysics, stats: Dictionary) -> void:
	var draws := float(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	)
	var all: Array = stats["draws"]
	all.append(draws)
	var islands := phys.islands()
	if not islands.is_empty():
		var falling: Array = stats["isl_draws"]
		falling.append(draws)
	var swaps: Array = stats["swap"]
	for island: IslandBody in islands:
		for child: Node in island.get_children():
			if child is IslandMesh:
				var view: IslandMesh = child
				if view.last_swap_us > 0:
					swaps.append(view.last_swap_us / 1000.0)
					view.last_swap_us = 0


## The worst collider rebuild of any building so far, in ms (CarveCollider.worst_usec).
static func worst_collider_ms(phys: CarvePhysics) -> float:
	var worst := 0
	for child: Node in phys.get_children():
		if child is CarveCollider:
			var collider: CarveCollider = child
			worst = maxi(worst, collider.worst_usec)
	return worst / 1000.0


## The slow frames of `wall` (ms per frame): over 16.7 and over 33.4 ms, of all.
static func print_slow(wall: Array) -> void:
	var over := [0, 0]
	for ms: float in wall:
		over[0] += 1 if ms > 16.7 else 0
		over[1] += 1 if ms > 33.4 else 0
	print("  SLOW frames over 16.7 ms %d, over 33.4 ms %d, of %d" % [over[0], over[1], wall.size()])


## A digest of where every physics piece is (live debris, rubble, falling islands), rounded to
## 0.1 mm: two runs of the same scene that agree here simulated the same thing (the A/B's
## determinism check; no clock goes in).
static func state_digest(phys: CarvePhysics) -> String:
	var parts := PackedStringArray()
	for child: Node in phys.get_children():
		if child is CarveDebris:
			var debris: CarveDebris = child
			for rid: RID in debris.body_rids():
				var xf: Transform3D = PhysicsServer3D.body_get_state(
					rid, PhysicsServer3D.BODY_STATE_TRANSFORM
				)
				parts.append(_rounded(xf))
	for island: IslandBody in phys.islands():
		parts.append(_rounded(island.global_transform))
	return "%d pieces %s" % [parts.size(), "|".join(parts).md5_text().substr(0, 12)]


static func _rounded(xf: Transform3D) -> String:
	var o := (xf.origin * 10000.0).round()
	var x := (xf.basis.x * 10000.0).round()
	return "%d,%d,%d;%d,%d,%d" % [o.x, o.y, o.z, x.x, x.y, x.z]


## The A/B's settled frame: the tree pauses (no physics tick, no clock), every island's remesh is
## drawn, then `frames` frames render so temporal effects converge, and one still is saved. Two
## runs of one scene simulate the same pieces (state_digest), so their settled stills compare
## pixel for pixel: what differs is how the pieces are drawn, nothing else.
static func settled_shot(tree: SceneTree, phys: CarvePhysics, path: String, frames: int) -> void:
	tree.paused = true
	for island: IslandBody in phys.islands():
		island.finish_mesh()
	for _k: int in frames:
		await RenderingServer.frame_post_draw
	tree.root.get_viewport().get_texture().get_image().save_png(path)
	print("SETTLED %s %s" % [path, state_digest(phys)])


## Building n's footprint centre, size in units, and its blow's path (a centre at time t, or
## null when the blow is done).
static func layout(scene: String) -> Array[Dictionary]:
	match scene:
		"swipe":
			return [{"at": Vector3.ZERO, "units": Vector3i(6, 12, 6), "radius": 1.3, "delay": 0.0}]
		"block":
			var out: Array[Dictionary] = []
			for n: int in 6:
				@warning_ignore("integer_division")
				var at := Vector3((n % 3 - 1) * 9.0, 0.0, (n / 3 - 0.5) * 10.0)
				var units := Vector3i(6, 12 + (n * 5) % 9, 6)
				out.append({"at": at, "units": units, "radius": 2.4, "delay": n * 0.3, "n": n})
			return out
	return [{"at": Vector3.ZERO, "units": Vector3i(6, 16, 6), "radius": 2.4, "delay": 0.0}]


static func path(scene: String, b: Dictionary, t: float) -> Variant:
	var c: Vector3 = b["at"]
	if scene == "swipe":
		if t < 2.0:
			return c + Vector3(lerpf(-5.0, 5.0, t / 2.0), 7.0, -3.3)
		if t < 4.0:
			var k := (t - 2.0) / 2.0
			return c + Vector3(lerpf(5.0, -5.0, k), lerpf(9.5, 4.0, k), -3.2)
		return null
	# A base cut in two passes; the second stops short on towers that should topple.
	var stop := 1.0 if scene == "tower" or Num.i(b.get("n", 0)) % 2 == 1 else 6.0
	if t < 1.6:
		return c + Vector3(lerpf(-6.0, 1.0, t / 1.6), 1.6, -1.6)
	if t < 3.2:
		return c + Vector3(lerpf(-6.0, stop, (t - 1.6) / 1.6), 1.6, 1.6)
	return null
