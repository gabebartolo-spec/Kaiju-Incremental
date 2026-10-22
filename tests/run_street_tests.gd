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
## 1532d9c3297b48fe, D-135: the cities are wider, so the plan and the people on it changed).
const PINNED := "1532d9c3297b48fe"


func suite_name() -> String:
	return "Street"


func run_checks() -> void:
	await _t("_check_draw_counts")
	await _t("_check_replay_pinned")


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
	var officer: Police.Officer = street._officers[i]
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
