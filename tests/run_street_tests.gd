extends "res://tests/lib/runner.gd"
## Street suite: StreetLife's people (civilians and police officers; presentation only), kept as
## packed arrays (perf study 2026-10-21). Every frame each person is drawn in its pose's MultiMesh
## at its own transform, and a seeded run repeats its pinned state exactly.
## Seeded by design: Seeds "city", "army" and "civilians" 0, a scripted kaiju line and a fixed
## frame step (tests/lib/street_replay.gd).
##   godot --headless --path . --script tests/run_street_tests.gd

const Replay := preload("res://tests/lib/street_replay.gd")
const FRAMES := 600
## Replay.digest() after FRAMES frames at stage 1, High (first 16 hex digits). The packed-array
## StreetLife drew every MultiMesh buffer bit for bit as the Person objects it replaced, over
## 600 frames at the then-biggest stage on Medium, High and Max (to-kaiju/014). A deliberate
## change to street life, its tuning or the city plan re-pins it (3ce3931c7b6a5cdc ->
## 1532d9c3297b48fe, D-135: the cities are wider, so the plan and the people on it changed;
## -> e6dc7d4d2660f21f, road network: no alleys on the river banks, so the plan's streets, and the
## pavements the people walk, differ at stage 1).
const PINNED := "e6dc7d4d2660f21f"
## Frames of the buffer tests: five seconds of the street, with stomps, a brace and a blockade.
const BUFFER_FRAMES := 300
const STRIDE := 12  # floats of a 3D transform in a MultiMesh buffer
## Frames of the native walk check: long enough for officers to hold, flee and leave.
const WALK_FRAMES := 1500


func suite_name() -> String:
	return "Street"


func run_checks() -> void:
	await _t("_check_draw_counts")
	await _t("_check_replay_pinned")
	await _t("_check_native_loaded")
	await _t("_check_buffers_byte_equal")
	await _t("_check_buckets_resize")
	await _t("_check_people_bounds")
	await _t("_check_walk_native")


## The buffer checks run the native buckets (KaijuBuckets, item 7): without the library they skip,
## unless KAIJU_NATIVE_REQUIRED=1 (CI), where a missing library fails.
func _check_native_loaded() -> void:
	if StreetDraw.available():
		check(true, "the KaijuBuckets class is registered by the extension")
	elif OS.get_environment("KAIJU_NATIVE_REQUIRED") == "1":
		check(false, "KAIJU_NATIVE_REQUIRED=1 but KaijuBuckets is not registered")
	else:
		print("SKIP: KaijuBuckets is not registered; build native/ to run the buffer checks")
		check(true, "native library not built: buffer checks skipped on purpose")


## Every frame, every person is in the MultiMesh of its outfit and pose, at the next free slot in
## array order, with its heading's turn and its side step, and each MultiMesh shows exactly its
## people; the run takes in fleeing, crushing, a brace and a police blockade.
func _check_draw_counts() -> void:
	var replay := Replay.new(self, 1, "high")
	var street := replay.street
	var wrong := 0
	var first := ""
	var officers := 0
	for f: int in FRAMES:
		replay.step()
		officers = maxi(officers, street.cop.count(1))
		var why := _misdrawn(street)
		if why != "":
			wrong += 1
			first = "frame %d: %s" % [f, why] if first == "" else first
	check(
		wrong == 0,
		(
			"every frame each MultiMesh shows its outfit and pose's people (%d wrong, %s)"
			% [wrong, first]
		)
	)
	check(
		street.fled > 0 and street.killed > 0 and officers > 0,
		(
			"the run has people fleeing (%d), crushed (%d) and officers out (%d)"
			% [street.fled, street.killed, officers]
		)
	)
	replay.finish()


## The first MultiMesh that shows a different number of people than are in its outfit and pose,
## or "". (Headless Godot keeps no instance transforms, so the transforms themselves are proved
## on the GPU: to-kaiju/014.)
func _misdrawn(street: StreetLife) -> String:
	var counts := PackedInt32Array()
	counts.resize(street._mms.size())
	for i: int in street.pos.size():
		counts[street.outfit[i] * VoxelPerson.POSES + _pose(street, i)] += 1
	for b: int in counts.size():
		var shown := street._mms[b].visible_instance_count
		if shown != mini(counts[b], street._mms[b].instance_count):
			return "MultiMesh %d shows %d of %d" % [b, shown, counts[b]]
	return ""


## The pose the street should draw: standing while gawking or frozen, aiming while an officer
## holds, else a two-frame walk or run (officers and runners at RUN_HZ).
func _pose(street: StreetLife, i: int) -> int:
	var clock := street._clock
	var officer: Police.Officer = street.officers[i]
	if officer == null and street.pinned_until[i] > clock:
		return VoxelPerson.Pose.WALK_A
	if officer != null and officer.state == 1:
		return VoxelPerson.Pose.AIM
	var running := street.fleeing[i] == 1 or (officer != null and officer.state == 2)
	var hz := StreetLife.RUN_HZ if running or officer != null else StreetLife.WALK_HZ
	var stride := int(clock * hz + street.phase[i] * 2.0) % 2
	return (VoxelPerson.Pose.RUN_A if running else VoxelPerson.Pose.WALK_A) + stride


## The same seeded run twice gives the same people, random streams and totals, and they are the
## pinned ones.
func _check_replay_pinned() -> void:
	var got: Array[String] = []
	for _run: int in 2:
		var replay := Replay.new(self, 1, "high")
		for _f: int in FRAMES:
			replay.step()
		got.append(replay.digest().left(16))
		replay.finish()
	check(
		got[0] == got[1] and got[0] == PINNED,
		"a seeded street replays exactly and matches the pinned %s (got %s)" % [PINNED, got]
	)


## The floats the engine's per-instance setter writes for a transform (a MultiMesh keeps the 3x4
## row by row, the origin in each row's fourth place), written out here from the basis columns.
func _floats(t: Transform3D) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for row: int in 3:
		out.append(t.basis.x[row])
		out.append(t.basis.y[row])
		out.append(t.basis.z[row])
		out.append(t.origin[row])
	return out


## The buffers each MultiMesh should hold: every person's transform in array order, by bucket.
func _expected(street: StreetLife) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	out.resize(street._mms.size())
	for i: int in street.pos.size():
		var look := street.heading[i]
		var at := street.pos[i] + Vector2(-look.y, look.x) * street.side[i]
		var basis := Basis(Vector3.UP, atan2(-look.x, -look.y))
		var t := Transform3D(basis, Vector3(at.x, 0, at.y))
		out[street.outfit[i] * VoxelPerson.POSES + _pose(street, i)].append_array(_floats(t))
	return out


## Over 300 frames of the seeded walk (stomps, a brace, a blockade) the people's buffers equal,
## byte for byte, what the per-instance setters write, bucket by bucket (item 7). The same run
## with the flag off keeps every MultiMesh at full size, has no buffers and ends in the same
## people. Headless Godot keeps no instance data to read back, so the reference is the setters'
## layout written out above.
func _check_buffers_byte_equal() -> void:
	if not StreetDraw.available():
		check(true, "skipped: no native library")
		return
	var on := Replay.new(self, 1, "high", true)
	var off := Replay.new(self, 1, "high", false)
	var wrong := 0
	var first := ""
	for f: int in BUFFER_FRAMES:
		on.step()
		off.step()
		var want := _expected(on.street)
		for b: int in want.size():
			var mm := on.street._mms[b]
			var got := on.street._draw.buckets.buffer(b)
			var n := want[b].size()
			var same := got.size() == mm.instance_count * STRIDE
			same = same and mm.visible_instance_count * STRIDE == n
			same = same and got.slice(0, n).to_byte_array() == want[b].to_byte_array()
			if not same:
				wrong += 1
				first = "frame %d bucket %d" % [f, b] if first == "" else first
	check(wrong == 0, "every bucket's buffer is the setters' bytes (%d wrong, %s)" % [wrong, first])
	var full := true
	for mm: MultiMesh in off.street._mms:
		full = full and mm.instance_count == off.street._capacity
	check(off.street._draw == null and full, "flag off: no buffers, full-size MultiMeshes")
	check(
		on.digest() == off.digest() and on.street.killed > 0,
		"the people's state is the same with buffers on and off (and the run crushed some)"
	)
	on.finish()
	off.finish()


## A buffered bucket is sized to its people: it grows past its first size, shrinks once under half
## full, keeps buffer length = instance_count * stride, and a coloured one keeps each colour after
## its transform (the rooftop's flashes and tracers).
func _check_buckets_resize() -> void:
	if not StreetDraw.available():
		check(true, "skipped: no native library")
		return
	for colored: bool in [false, true]:
		var stride := STRIDE + (4 if colored else 0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = colored
		mm.mesh = BoxMesh.new()
		var mms: Array[MultiMesh] = [mm]
		var buckets := MultiMeshBuckets.new(mms, true, 8, colored)
		for count: int in [5, 40, 1000, 30, 8]:
			buckets.begin()
			var want := PackedFloat32Array()
			for k: int in count:
				var t := Transform3D(Basis(Vector3.UP, k * 0.1), Vector3(k, 2.0 * k, -k))
				var c := Color(k, 0.5, 4.0, 1.0)
				buckets.add(0, t, c)
				want.append_array(_floats(t))
				if colored:
					want.append_array(PackedFloat32Array([c.r, c.g, c.b, c.a]))
			buckets.commit()
			var got := buckets.buffer(0)
			var sized := got.size() == mm.instance_count * stride
			check(
				sized and mm.visible_instance_count == count,
				(
					"%d shown: %d floats for %d slots, stride %d"
					% [count, got.size(), mm.instance_count, stride]
				)
			)
			var held := got.slice(0, count * stride).to_byte_array() == want.to_byte_array()
			check(held, "%d shown (colours %s): the buffer holds them in order" % [count, colored])
		check(mm.instance_count <= 16, "back to 8 shown, %d slots" % mm.instance_count)


## The fixed culling box holds every person, feet and head, so culling never hides one: the
## pavements' bounds plus the margin, on every MultiMesh, every frame.
func _check_people_bounds() -> void:
	if not StreetDraw.available():
		check(true, "skipped: no native library")
		return
	var replay := Replay.new(self, 1, "high", true)
	var outside := 0
	for mm: MultiMesh in replay.street._mms:
		outside += 0 if mm.custom_aabb == replay.street._mms[0].custom_aabb else 1
	for _f: int in BUFFER_FRAMES:
		replay.step()
		var street := replay.street
		for i: int in street.pos.size():
			var look := street.heading[i]
			var at := street.pos[i] + Vector2(-look.y, look.x) * street.side[i]
			var box := street._mms[0].custom_aabb
			if not (
				box.has_point(Vector3(at.x, 0, at.y)) and box.has_point(Vector3(at.x, 1, at.y))
			):
				outside += 1
	check(outside == 0, "every person is inside every MultiMesh's box (%d outside)" % outside)
	replay.finish()


## With the extension the civilians walk natively (KaijuWalk, item 7), and every frame the street
## is the GDScript loop's: people, random streams and totals, through stomps, braces, a blockade
## and officers that run far enough to leave (WALK_FRAMES covers their COP_FLEE_SECONDS).
func _check_walk_native() -> void:
	if not StreetDraw.available():
		check(true, "skipped: no native library")
		return
	var on := Replay.new(self, 1, "high", true)
	var off := Replay.new(self, 1, "high", false)
	check(on.street._walker != null, "the extension walks the street (KaijuWalk is registered)")
	var differ := -1
	var seen := {}
	for f: int in WALK_FRAMES:
		on.step()
		off.step()
		var i := on.street.cop.find(1)
		while i >= 0:
			seen[on.street.officers[i]] = true
			i = on.street.cop.find(1, i + 1)
		if differ < 0 and on.digest() != off.digest():
			differ = f
	var left := 0
	for officer: Police.Officer in seen:
		left += 1 if officer.timer > Police.COP_FLEE_SECONDS else 0
	check(differ < 0, "native and GDScript walks match every frame (first differs: %d)" % differ)
	check(
		on.street.fled > 0 and on.street.killed > 0 and left > 0,
		(
			"the run has people fleeing (%d), crushed (%d) and officers leaving (%d)"
			% [on.street.fled, on.street.killed, left]
		)
	)
	on.finish()
	off.finish()
