extends RefCounted
## The flow suite's mass-collapse checks (rooftops #63 CI run 39109733215, a Behemoth city: 133
## "axis must be normalized" errors from CityView._animate_falls and 171 collapse sounds in two
## frames). A topple whose direction came out zero (the sim rounds a tiny overhang to none) still
## turns over, and a burst of landings plays at most tuning "sfx" "collapse_per_frame" collapse
## sounds a frame. A dropped part that lands crumbles into the street over "topple_fx"
## drop_crumble_s instead of vanishing on the landing frame (PR #89 review, capture 39277970463).
## A falling part is never see-through, however long it hides the kaiju (D-326: "NEVER FADE OUT THE
## DESTRUCTION").

const LANDINGS := 171  # as many landings in one frame as that collapse had
const ID := 900001  # a fall id the sim never hands out in a flow run
const SOLID_FRAMES := 30  # city frames a part hangs across the line (the old fade took 15)


static func check_all(check: Callable, rampage: Rampage) -> void:
	_check_still_topple(check, rampage)
	_check_sound_cap(check, rampage.sfx)
	_check_drop_crumbles(check, rampage)
	_check_falls_solid(check, rampage)


static func _check_still_topple(check: Callable, rampage: Rampage) -> void:
	var sim := rampage.sim
	var index := -1
	var near := INF
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var far := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if b.frame.h > 2 and far < near:
			near = far
			index = i
	var building := sim.buildings[index]
	var cells: Array[Vector3i] = []
	for y: int in range(1, building.frame.h):
		for x: int in building.frame.w:
			for z: int in building.frame.d:
				if building.frame.alive(Vector3i(x, y, z)):
					cells.append(Vector3i(x, y, z))
	var pivot := building.local_to_world(Vector3(0, 1, 0))
	var city := rampage._city
	(
		city
		. fall_start(
			{
				"id": ID,
				"building": index,
				"cells": cells,
				"kind": "topple",
				"pivot": pivot,
				"dir": Vector2.ZERO,
				"drop": 0.0,
				"duration": 1.0,
			}
		)
	)
	var fall: Dictionary = city._falling[ID]
	var piece: Node3D = fall["node"]
	city._animate_falls(0.5)
	var turned := piece.basis.get_rotation_quaternion().get_angle()
	check.call(
		turned > 0.1 and piece.basis.is_conformal(),
		"a topple with no direction still turns over (%.2f rad at half its fall)" % turned
	)
	var at := Vector2(pivot.x, pivot.z)
	city.fall_land(
		{"id": ID, "kind": "topple", "building": index, "from": at, "to": at, "width": 1.0}
	)


static func _check_drop_crumbles(check: Callable, rampage: Rampage) -> void:
	var sim := rampage.sim
	var index := -1
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.landmark == "" and b.frame.h > 3 and b.frame.alive_count > 0:
			index = i
			break
	var building := sim.buildings[index]
	var cells: Array[Vector3i] = []
	for y: int in range(1, building.frame.h):
		for x: int in building.frame.w:
			for z: int in building.frame.d:
				if building.frame.alive(Vector3i(x, y, z)):
					cells.append(Vector3i(x, y, z))
	var city := rampage._city
	var start := {
		"id": ID + 1,
		"building": index,
		"cells": cells,
		"kind": "drop",
		"pivot": building.local_to_world(Vector3(building.w * 0.5, 1, building.d * 0.5)),
		"dir": Vector2.ZERO,
		"drop": 1.0,
		"duration": 0.2,
	}
	city.fall_start(start)
	var piece: Node3D = city._falling[ID + 1]["node"]
	city._animate_falls(0.2)
	city.fall_land({"id": ID + 1, "kind": "drop", "building": index})
	var landed := is_instance_valid(piece) and not piece.is_queued_for_deletion()
	var span := Num.f(Content.section("topple_fx")["drop_crumble_s"])
	city._topple._process(span * 0.5)
	var half := piece.global_transform.basis.get_scale().y if landed else 0.0
	city._topple._process(span)
	var gone := not is_instance_valid(piece) or piece.is_queued_for_deletion()
	check.call(
		landed and half < 0.99 and gone,
		(
			(
				"a dropped %d-chunk part crumbles over %.1f s, not a one-frame pop: there after"
				+ " landing %s, squashed to %.2f half way, gone after %s"
			)
			% [cells.size(), span, landed, half, gone]
		)
	)


## A tower toppling and a part dropping, each hung across the line from the camera to the kaiju's
## body (hiding it), stay drawn solid for as long as they hang there: no screen door, no ghosting.
static func _check_falls_solid(check: Callable, rampage: Rampage) -> void:
	var sim := rampage.sim
	var city := rampage._city
	var building := sim.buildings[0]
	for b: RampageSim.Building in sim.buildings:
		if b.landmark == "" and b.frame.h > 3:
			building = b
			break
	var index := sim.buildings.find(building)
	var cells: Array[Vector3i] = []
	for y: int in range(1, building.frame.h):
		for x: int in building.frame.w:
			for z: int in building.frame.d:
				cells.append(Vector3i(x, y, z))
	var eye := rampage._camera.global_position
	var body := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	var sight := PackedVector3Array()
	for share: float in [0.3, 0.6, 0.9]:
		sight.append(body + Vector3.UP * sim.reach_height() * share)
	var kinds := {"topple": ID + 2, "drop": ID + 3}
	for kind: String in kinds:
		var id: int = kinds[kind]
		(
			city
			. fall_start(
				{
					"id": id,
					"building": index,
					"cells": cells,
					"kind": kind,
					"pivot": building.local_to_world(Vector3(0, 1, 0)),
					"dir": Vector2.RIGHT,
					"drop": 1.0,
					"duration": 100.0,  # hangs: the fall barely moves in the frames below
				}
			)
		)
		var piece: Node3D = city._falling[id]["node"]
		var box: AABB = piece.get_meta("box")
		var pivot: Vector3 = piece.get_meta("pivot")
		var middle := eye.lerp(sight[1], 0.5)  # the section's middle on the line to the body
		piece.global_position += middle - piece.global_transform * (box.get_center() - pivot)
		var across := _in_the_way(piece, eye, sight)
		var faintest := 1.0
		for _f: int in SOLID_FRAMES:
			city._process(1.0 / 60.0)
			faintest = minf(faintest, _faintest(piece))
		check.call(
			across and faintest == 1.0,
			(
				(
					"a %s section hung across the camera's line to the kaiju stays solid (in the"
					+ " way %s, faintest %.2f of 1) over %d frames"
				)
				% [kind, across, faintest, SOLID_FRAMES]
			)
		)
		city._falling.erase(id)
		piece.queue_free()


## Whether the segment from `eye` to any of `sight` crosses the part's box (its chunks at rest,
## meta "box", carried to where the part is now).
static func _in_the_way(piece: Node3D, eye: Vector3, sight: PackedVector3Array) -> bool:
	var box: AABB = piece.get_meta("box")
	var pivot: Vector3 = piece.get_meta("pivot")
	var to_rest := piece.global_transform.affine_inverse()
	for target: Vector3 in sight:
		if box.intersects_segment(to_rest * eye + pivot, to_rest * target + pivot) != null:
			return true
	return false


## The lowest opacity any of the part's meshes draws at now (1 = solid; a mesh whose shader has no
## opacity share is solid; one the camera bubble cuts, bubble_cut above 0, counts as 0: D-326).
static func _faintest(piece: Node3D) -> float:
	var low := 1.0
	for mi: Node in piece.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
		if mat == null:
			continue
		if mat.get_shader_parameter("opacity") != null:
			low = minf(low, Num.f(mat.get_shader_parameter("opacity")))
		var cut: Variant = mat.get_shader_parameter("bubble_cut")
		if cut != null and Num.f(cut) > 0.0:
			low = 0.0
	return low


static func _check_sound_cap(check: Callable, sfx: Sfx) -> void:
	sfx._process(1.0)  # last frame's sounds are out of the way
	var before := sfx.played.count("collapse")
	var pool := sfx.voices
	var left := 0.0
	for i: int in pool.players.size():
		if pool._category[i] == "collapse":
			left = maxf(left, pool._until[i] - pool._now)
	var drop0 := pool.dropped
	var diag := "DIAG sound: live %s, collapse busy %d of %d (longest left %.1f s), all busy %d"
	diag = diag % [sfx.live, pool.busy_in("collapse"), pool.cap("collapse"), left, pool.busy_in("")]
	for n: int in LANDINGS:
		sfx.collapse(n % 3 == 0)
	sfx._process(1.0 / 60.0)
	var first := sfx.played.count("collapse") - before
	sfx._process(1.0 / 60.0)
	var later := sfx.played.count("collapse") - before - first
	var cap := Num.i(Content.section("sfx")["collapse_per_frame"])
	check.call(false, diag + ", then dropped %d, played %d" % [pool.dropped - drop0, first])
	check.call(
		first > 0 and first <= cap and later == 0,
		(
			"%d landings in one frame play %d collapse sounds (cap %d), none held over (%d)"
			% [LANDINGS, first, cap, later]
		)
	)
