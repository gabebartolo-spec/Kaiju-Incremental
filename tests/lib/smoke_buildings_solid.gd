extends RefCounted
## D-326 (director 2026-10-27, on the toppling clip: "building doesnt look solid to me"; "its ok to
## obscure the kaiju, its not ok to block the camera, please stop making buildings fade out";
## "it may hide the kaiju. Only a wall that fills the frame at the camera is handled"): a standing
## building on the line from the camera to the kaiju draws fully solid unless it covers half the
## screen or more (tuning camera fade_frame_share). A seeded rampage (city seed 0, run 1) has the
## kaiju stand just behind a small building on the camera's side; every frame, every building a
## sight line crosses that covers less than the share is read off the shader the game drew it with
## (the opacity of its BuildingView), and must be 1. A section toppling off a building that is faded
## snaps it solid (the fall is destruction, never see-through).
## Seeded by design: city seed 0, run 1; the kaiju is put by hand and no check reads a clock.

## Physics frames the kaiju and the camera get to arrive after the kaiju is put behind the building.
const SETTLE := 120
## Frames read, and the seconds handed to each city _process (the old fade took 0.25 s to go down,
## so three frames would have shown it).
const FRAMES := 40
const STEP := 0.1
## How far behind the building's wall the kaiju stands (m), the least floors the building has, and
## the most of the screen it may cover for the check to count (well under the fade's share).
const BEHIND := 6.0
const MIN_FLOORS := 4
const SMALL := 0.3
const ID := 900101  # a fall id the sim never hands out in a flow run


## What the frames showed.
class Seen:
	extends RefCounted
	var on_line := 0  # frames a small building was on a sight line
	var worst := 1.0  # the least opacity any of them was drawn at
	var bad: Array[String] = []
	var biggest := 0.0  # the most of the screen any of them covered


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
	var city := rampage._city
	while sim.emerge.active:
		await tree.physics_frame
	sim.time_left = 600.0
	var size := root.get_viewport().get_visible_rect().size
	var index := _stand_behind(rampage, size.x / size.y)
	check.call(index >= 0, "the kaiju can stand behind a small building (building %d)" % index)
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
		city._process(STEP)
		_scan(rampage, size, seen)
	var share := Num.f(Content.section("camera")["fade_frame_share"])
	(
		check
		. call(
			seen.on_line >= FRAMES * 3 / 4 and seen.biggest < share,
			(
				(
					"a building under %.0f%% of the screen stands on the camera-to-kaiju line (%d of %d frames,"
					+ " the most it covered %.1f%%)"
				)
				% [share * 100.0, seen.on_line, FRAMES, seen.biggest * 100.0]
			)
		)
	)
	check.call(
		seen.worst == 1.0 and seen.bad.is_empty(),
		(
			(
				"every building on that line that covers under the share draws solid on every frame"
				+ " (least opacity %.2f, %s)"
			)
			% [seen.worst, seen.bad.slice(0, 3)]
		)
	)
	_check_fall_snaps(check, rampage, index)
	rampage.queue_free()
	await tree.process_frame


## Puts the kaiju just behind the first small, built building (on the camera's side of it) the
## camera's line to the kaiju crosses; the building's index, or -1.
static func _stand_behind(rampage: Rampage, aspect: float) -> int:
	var sim := rampage.sim
	var rest := CameraTuning.offset() * CameraTuning.zoom(sim.body_scale())
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if b.landmark != "" or b.w < 4 or b.d < 4 or b.height < MIN_FLOORS:
			continue
		if rampage._city._stream.built(n) == null:
			continue
		var spot := Vector2(b.x, b.z - b.d * 0.5 - BEHIND)
		if sim.clamp_to_arena(spot) != spot or _crowded(sim, spot, n):
			continue
		sim.kaiju_pos = spot
		var at := Vector3(spot.x, sim.stand_y, spot.y)
		var eye := at + rest
		var sight := BuildingFade.sight_of(sim, eye)
		if not BuildingFade.blocks(eye, sight, b):
			continue
		var look := at + Vector3(0, sim.reach_height() * 0.5, 0)
		var frame := FrameShare.looking(eye, look, CameraTuning.fov(), aspect)
		if frame.share_of(_standing_box(b)) < SMALL:
			return n
	return -1


## Whether another building stands within the kaiju's reach of `spot`.
static func _crowded(sim: RampageSim, spot: Vector2, except: int) -> bool:
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if (
			n != except
			and absf(b.x - spot.x) < b.w * 0.5 + 6.0
			and absf(b.z - spot.y) < b.d * 0.5 + 6.0
		):
			return true
	return false


static func _standing_box(b: RampageSim.Building) -> AABB:
	var top := BuildingFade.standing_top(b)
	return AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, top, b.d))


## Reads this frame: each building a sight line crosses that covers under the fade's share, and the
## opacity its view is drawn with.
static func _scan(rampage: Rampage, size: Vector2, seen: Seen) -> void:
	var sim := rampage.sim
	var city := rampage._city
	var camera := rampage._camera
	var eye := camera.global_position
	var sight := BuildingFade.sight_of(sim, eye) + city.drawn_sight
	var frame := FrameShare.of(camera, size)
	var share := Num.f(Content.section("camera")["fade_frame_share"])
	var any := false
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if not BuildingFade.blocks(eye, sight, b):
			continue
		var covers := frame.share_of(_standing_box(b))
		if covers >= share:
			continue
		any = true
		seen.biggest = maxf(seen.biggest, covers)
		var drawn := _drawn(city._stream.built(n))
		seen.worst = minf(seen.worst, drawn)
		if drawn < 1.0:
			seen.bad.append("building %d covers %.1f%% opacity %.2f" % [n, covers * 100.0, drawn])
	seen.on_line += 1 if any else 0


## The opacity a building's view is drawn with now (1 when it was never faded or is not built).
static func _drawn(view: BuildingView) -> float:
	if view == null or view._shell_mat == null:
		return 1.0
	var share: Variant = view._shell_mat.get_shader_parameter("opacity")
	return 1.0 if share == null else Num.f(share)


## A section toppling off a building that is faded snaps it solid for the fall: the fade is forced
## to its floor, a frame passes (the building is no wall that fills the frame, so it eases back),
## a fall starts, and one frame later the building is drawn at 1.
static func _check_fall_snaps(check: Callable, rampage: Rampage, index: int) -> void:
	var city := rampage._city
	var building := rampage.sim.buildings[index]
	city._fade._faded[index] = 1.0
	city._process(STEP)
	var before := city._fade.opacity(index)
	var cells: Array[Vector3i] = []
	for y: int in range(1, building.frame.h):
		for x: int in building.frame.w:
			for z: int in building.frame.d:
				cells.append(Vector3i(x, y, z))
	(
		city
		. fall_start(
			{
				"id": ID,
				"building": index,
				"cells": cells,
				"kind": "topple",
				"pivot": building.local_to_world(Vector3(0, 1, 0)),
				"dir": Vector2.RIGHT,
				"drop": 1.0,
				"duration": 100.0,
			}
		)
	)
	city._process(STEP)
	var after := city._fade.opacity(index)
	var drawn := _drawn(city._stream.built(index))
	(
		check
		. call(
			before < 1.0 and after == 1.0 and drawn == 1.0,
			(
				(
					"a faded building a section topples off snaps to opacity 1 for the fall (before %.2f,"
					+ " after %.2f, drawn %.2f)"
				)
				% [before, after, drawn]
			)
		)
	)
