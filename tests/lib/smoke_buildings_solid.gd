extends RefCounted
## The camera bubble in the real game (D-326, D-350; director 2026-10-27: "as long as the bubble
## isnt going to be inside buildings adjacent to the kaiju ... its the ones that the camera itself
## phases through"): a seeded rampage (city seed 0, run 1) has the kaiju stand just behind a small
## building on the camera's side, so inside his destruction field. Every frame, every built
## building whose footprint lies in the field (CameraBubble.in_field) is read off the shader the
## game draws it with (bubble_cut on its BuildingView's materials) and must be 0, drawn whole; the
## sphere's far edge stays the field short of him. A cut forced open on that building is whole the
## next frame (the field is never cut, not even while a cut closes), and one forced open on a
## building the sphere does not reach eases closed on its view over camera.bubble_seconds.
## Seeded by design: city seed 0, run 1; the kaiju is put by hand and no check reads a clock.

## Physics frames the kaiju and the camera get to arrive after the kaiju is put behind the building.
const SETTLE := 120
## Frames read, and the seconds handed to each city _process (half of camera.bubble_seconds, so a
## cut opening would show on two frames).
const FRAMES := 40
const STEP := 0.05
## How far behind the building's wall the kaiju stands (m), and the least floors the building has.
const BEHIND := 6.0
const MIN_FLOORS := 4
## How much farther than the sphere a building must be to count as out of its reach (m).
const CLEAR := 5.0


## What the frames showed.
class Seen:
	extends RefCounted
	var in_field := 0  # frames the building he stands behind was in his field
	var most := 0.0  # the most any building in the field was cut
	var bad: Array[String] = []
	var edge := INF  # the least gap from the sphere's far edge to the field (m)


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
	var passed := {}
	var index := _stand_behind(rampage, passed)
	check.call(
		index >= 0,
		(
			"the kaiju can stand behind a small building (building %d; passed over %s)"
			% [index, passed]
		)
	)
	if index < 0:
		rampage.queue_free()
		await tree.process_frame
		return
	for i: int in SETTLE:
		sim.stomp._timer = 9.0  # the kaiju stands still: nothing it does breaks the building
		await tree.physics_frame
	var seen := Seen.new()
	for i: int in FRAMES:
		sim.stomp._timer = 9.0
		await tree.physics_frame
		rampage._city._process(STEP)
		_scan(rampage, index, seen)
	check.call(
		seen.in_field == FRAMES,
		"the building he stands behind is in his field (%d of %d frames)" % [seen.in_field, FRAMES]
	)
	check.call(
		seen.most == 0.0 and seen.bad.is_empty(),
		(
			"every building in his field draws whole on every frame (most cut %.2f, %s)"
			% [seen.most, seen.bad.slice(0, 3)]
		)
	)
	check.call(seen.edge >= -0.01, "the sphere stays the field short of him (%.2f m)" % seen.edge)
	_check_forced(check, rampage, index)
	rampage.queue_free()
	await tree.process_frame


## Puts the kaiju just behind the first small, built building (on the camera's side of it) that
## stands on the camera's line to him; the building's index, or -1. `passed` counts the buildings
## ruled out and why.
static func _stand_behind(rampage: Rampage, passed: Dictionary) -> int:
	var sim := rampage.sim
	var rest := CameraTuning.offset() * CameraTuning.zoom(sim.body_scale())
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if b.landmark != "" or b.w < 4 or b.d < 4 or b.height < MIN_FLOORS:
			passed["unfit"] = Num.i(passed.get("unfit", 0)) + 1
			continue
		if rampage._city._stream.built(n) == null:
			passed["unbuilt"] = Num.i(passed.get("unbuilt", 0)) + 1
			continue
		var spot := Vector2(b.x, b.z - b.d * 0.5 - BEHIND)
		if sim.clamp_to_arena(spot) != spot or _inside_another(sim, spot, n):
			passed["no_room"] = Num.i(passed.get("no_room", 0)) + 1
			continue
		sim.kaiju_pos = spot
		var at := Vector3(spot.x, sim.stand_y, spot.y)
		var chest := at + Vector3(0, sim.reach_height() * 0.5, 0)
		if _box(b).intersects_segment(at + rest, chest) == null:
			passed["no_line"] = Num.i(passed.get("no_line", 0)) + 1
			continue
		return n
	return -1


## Whether a building other than `except` stands on `spot` (the kaiju must stand in the street).
static func _inside_another(sim: RampageSim, spot: Vector2, except: int) -> bool:
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if n != except and absf(b.x - spot.x) < b.w * 0.5 and absf(b.z - spot.y) < b.d * 0.5:
			return true
	return false


static func _box(b: RampageSim.Building) -> AABB:
	return AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, b.height, b.d))


## Reads this frame: the cut each building in the field is drawn with, and the sphere's far edge.
static func _scan(rampage: Rampage, index: int, seen: Seen) -> void:
	var sim := rampage.sim
	var city := rampage._city
	var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	var field := CameraBubble.field(sim)
	var eye := rampage._camera.global_position
	if city._bubble.radius() > 0.0:
		var flat := Vector2(eye.x, eye.z).distance_to(Vector2(feet.x, feet.z))
		seen.edge = minf(seen.edge, flat - city._bubble.radius() - field)
	seen.in_field += 1 if CameraBubble.in_field(sim.buildings[index], feet, field) else 0
	for n: int in sim.buildings.size():
		if not CameraBubble.in_field(sim.buildings[n], feet, field):
			continue
		var drawn := _drawn(city._stream.built(n))
		seen.most = maxf(seen.most, drawn)
		if drawn > 0.0:
			seen.bad.append("building %d cut %.2f" % [n, drawn])


## The cut a building's view is drawn with now, the most of its materials (0 when not built).
static func _drawn(view: BuildingView) -> float:
	var most := 0.0
	if view == null:
		return most
	for mat: ShaderMaterial in [view._shell_mat, view._slab_mat, view._cells_mat]:
		if mat != null:
			var cut: Variant = mat.get_shader_parameter("bubble_cut")
			most = maxf(most, 0.0 if cut == null else Num.f(cut))
	return most


## A cut forced open on the building next to him is whole the next frame; one forced open on a
## built building out of the sphere's reach eases closed on its view, a step of
## STEP / camera.bubble_seconds.
static func _check_forced(check: Callable, rampage: Rampage, index: int) -> void:
	var city := rampage._city
	var bubble := city._bubble
	bubble._open[index] = 1.0
	city._process(STEP)
	var next := bubble.cut(index)
	var drawn := _drawn(city._stream.built(index))
	check.call(
		next == 0.0 and drawn == 0.0,
		"a cut forced open in his field is whole the next frame (%.2f, drawn %.2f)" % [next, drawn]
	)
	var far := _out_of_reach(rampage)
	if far < 0:
		check.call(false, "a built, whole building out of the sphere's reach exists")
		return
	bubble._open[far] = 1.0
	city._process(STEP)
	var want := 1.0 - STEP / Num.f(Content.section("camera")["bubble_seconds"])
	var eased := bubble.cut(far)
	var shown := _drawn(city._stream.built(far))
	check.call(
		is_equal_approx(eased, want) and is_equal_approx(shown, want),
		(
			"one the sphere does not reach eases closed on its view (%.2f, drawn %.2f, want %.2f)"
			% [eased, shown, want]
		)
	)


## A built, undamaged building outside his field and CLEAR beyond the sphere, or -1.
static func _out_of_reach(rampage: Rampage) -> int:
	var sim := rampage.sim
	var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	var field := CameraBubble.field(sim)
	var eye := rampage._camera.global_position
	var radius := rampage._city._bubble.radius()
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if rampage._city._stream.built(n) == null or b.landmark != "":
			continue
		if CameraBubble.damaged(b) or CameraBubble.in_field(b, feet, field):
			continue
		if CameraBubble.reach(eye, b) > radius + CLEAR:
			return n
	return -1
