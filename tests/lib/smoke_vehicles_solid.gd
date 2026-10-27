extends RefCounted
## D-290 (director 2026-10-27: "the governers heli sometimes blends into the buildings, as if it
## is translucent", then "why would any vehicle ever go see through?"): every tank and helicopter,
## the governor's included, always draws solid, even straight between the camera and the kaiju
## (smoke keeps clearing over the kaiju, D-025; buildings keep their own fade, D-283). A seeded
## rampage (city seed 0, run 1) has a gunship, the governor's helicopter and a tank put on the
## line from the camera to the kaiju's body; every frame, every drawn part of every vehicle is
## scanned for a screen-door share below 1 or a transparency above 0.
## Seeded by design: city seed 0, run 1; the vehicles are placed by hand and no check reads a clock.

## Frames the vehicles sit on the line, and the seconds handed to each _process (the old fade took
## 0.25 s to go down, so a few frames would have shown it).
const FRAMES := 24
const STEP := 0.1
## How near the line a vehicle must be (m from the camera-to-body segment, past the body's radius):
## inside what the old fade cleared for a tank (2; for a helicopter it was 5), so the old fade would
## have taken every one of them down.
const NEAR := 2.0
## Where along the segment (0 the camera, 1 the kaiju's body) a vehicle is put, at least and at
## most: its own height picks the point when it can.
const T_RANGE := Vector2(0.4, 0.9)


## What the scan found over all frames.
class Seen:
	extends RefCounted
	var parts := 0
	var worst := 1.0
	var bad: Array[String] = []
	var on_line := 0
	var gaps: Array[String] = []  # the last frame's: each vehicle's place and distance from the line


static func check(check: Callable, root: Node) -> void:
	var tree := root.get_tree()
	var def := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), def, UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(def, stats, layout, 1)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var sim := rampage.sim
	while sim.emerge.active:
		await tree.physics_frame
	sim.time_left = 600.0
	var heli := sim.air.spawn()
	rampage._on_event({"type": "heli_spawned", "heli": heli.id})
	rampage._on_event({"type": "vip_spawned", "rank": "GOVERNOR"})
	var vip: Node3D = rampage._powers._vip.nodes()[0]
	var waited := 0
	while sim.tanks.is_empty() and waited < 60 * 40:  # the army's own first tank, through its events
		sim.stomp._timer = 9.0
		await tree.physics_frame
		waited += 1
	check.call(
		not sim.tanks.is_empty(), "the army sends a tank in the seeded rampage (%d frames)" % waited
	)
	var tank: RampageSim.Tank = sim.tanks[0]
	var seen := Seen.new()
	for i: int in FRAMES:
		sim.stomp._timer = 9.0  # the kaiju stands still: nothing it does removes a vehicle
		var eye: Vector3 = rampage._camera.global_position
		var body: Vector3 = rampage._kaiju_at + Vector3(0, 3.5 * sim.body_scale(), 0)
		heli.pos = _on_line(eye, body, sim.air.altitude())
		tank.pos = _on_line(eye, body, 0.0)
		vip.position = Vector3(heli.pos.x, sim.air.altitude(), heli.pos.y) + Vector3(2.0, 0.0, 0.0)
		await tree.physics_frame
		rampage._process(STEP)
		var near := NEAR + Num.f(Content.section("powers")["body_radius"]) * sim.body_scale()
		var in_line := 0
		seen.gaps.clear()
		for node: Node3D in _vehicles(rampage):
			var gap := _line_gap(node.global_position, eye, body)
			seen.gaps.append("%s %s gap %.1f" % [node.get_class(), node.global_position, gap])
			in_line += 1 if gap < near else 0
			_scan(node, seen)
		seen.on_line += 1 if in_line == _vehicles(rampage).size() else 0
	var count := _vehicles(rampage).size()
	check.call(
		count >= 3 and seen.on_line >= FRAMES * 3 / 4,
		(
			(
				"a gunship, the governor's helicopter and a tank sit on the camera-to-kaiju line"
				+ " (%d vehicles, %d of %d frames, within %.1f m: %s)"
			)
			% [
				count,
				seen.on_line,
				FRAMES,
				NEAR + Num.f(Content.section("powers")["body_radius"]) * sim.body_scale(),
				seen.gaps
			]
		)
	)
	(
		check
		. call(
			seen.parts > 0 and seen.bad.is_empty() and seen.worst == 1.0,
			(
				"every vehicle part on that line draws solid on every frame (%d parts, least opacity %.2f, %s)"
				% [seen.parts, seen.worst, seen.bad.slice(0, 3)]
			)
		)
	)
	rampage.queue_free()
	await tree.process_frame


## Every tank and helicopter node the rampage now draws (the governor's included).
static func _vehicles(rampage: Rampage) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Node3D in rampage._tank_nodes.values():
		out.append(node)
	out.append_array(rampage._powers.helis())
	return out


## Where on the ground plane (x, z) the segment from `eye` to `body` is at height `y`; the whole
## segment's end nearest the body when `y` is out of its range.
static func _on_line(eye: Vector3, body: Vector3, y: float) -> Vector2:
	var t := clampf((y - eye.y) / minf(body.y - eye.y, -0.001), 0.0, 1.0)
	t = clampf(t, T_RANGE.x, T_RANGE.y)
	var p := eye.lerp(body, t)
	return Vector2(p.x, p.z)


## Distance from `p` to the segment eye-body.
static func _line_gap(p: Vector3, eye: Vector3, body: Vector3) -> float:
	var t := clampf(
		(p - eye).dot(body - eye) / maxf((body - eye).length_squared(), 0.001), 0.0, 1.0
	)
	return p.distance_to(eye.lerp(body, t))


## Adds `node`'s drawn parts to `seen`: the least screen-door share, and any part that is not solid.
static func _scan(node: Node3D, seen: Seen) -> void:
	for part: Node in node.find_children("*", "GeometryInstance3D", true, false):
		var g := part as GeometryInstance3D
		if g.transparency > 0.0:
			seen.bad.append("%s transparency %.2f" % [g.name, g.transparency])
		if not g is MultiMeshInstance3D:
			continue
		var mmi := g as MultiMeshInstance3D
		var mat := mmi.material_override as ShaderMaterial
		if mat == null:
			mat = (mmi.multimesh.mesh as PrimitiveMesh).material as ShaderMaterial
		seen.parts += 1
		var share: Variant = mat.get_shader_parameter("opacity") if mat != null else null
		var opacity := 1.0 if share == null else Num.f(share)
		seen.worst = minf(seen.worst, opacity)
		if opacity < 1.0:
			seen.bad.append("%s opacity %.2f" % [g.name, opacity])
