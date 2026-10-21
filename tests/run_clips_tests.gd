extends "res://tests/lib/runner.gd"
## Clips suite (D-047): the croc titan moves by its baked Blender clips (KaijuClips, ClipGait) at
## every stage (baby, adolescent, adult).
## The clip file loads and fits the rig it was baked for (same bones and order as the skin), a
## file for another skeleton is refused, the walk's phase follows the distance travelled, a
## standing heading change turns on the spot, the roar opens the jaw and ends, no bone goes NaN,
## a curve while walking swings the tail out and it settles, the clips (not the procedural tail)
## own the tail bones, the roar's tail slam lands as one footfall, and every other kaiju keeps its
## procedural gait. Fixed 60 Hz steps, no
## clock, no randomness.
##   godot --headless --path . --script tests/run_clips_tests.gd
## Seeded by design: nothing here draws random numbers (the gaits seed their own twitches).

const CLIPS := "res://assets/kaiju/reptilian_adult.kclip"
## Each croc titan stage and its Blender skin export (assets/kaiju/test/<name>.skin.json).
const STAGES := {
	"baby": "croctitan_baby", "adolescent": "croctitan_adolescent", "adult": "croctitan"
}
const DT := 1.0 / 60.0


func suite_name() -> String:
	return "Clips"


func run_checks() -> void:
	await _t("_check_file")
	await _t("_check_who_uses_clips")
	await _t("_check_walk_phase")
	await _t("_check_turn_and_roar")
	await _t("_check_tail_lag")
	await _t("_check_tail_owner")
	await _t("_check_tail_slam")


func _model(species: String, stage: String) -> KaijuModel:
	var def: Dictionary = Content.species_def(species)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(species, colors, stage)
	root.add_child(kaiju)
	return kaiju


func _rig_of(kaiju: KaijuModel) -> KaijuRig:
	return kaiju.find_children("*", "KaijuRig", true, false)[0]


## Every croc titan stage's clips list one track per game bone in its rig's order, each gathering
## its skin export's bones of that game name, and every clip the gait plays is there.
func _check_file() -> void:
	var tracks_ok := true
	var all_ok := true
	var report := ""
	for stage: String in STAGES:
		var clips := KaijuClips.read("res://assets/kaiju/reptilian_%s.kclip" % stage)
		if clips == null:
			tracks_ok = false
			report += " %s: missing" % stage
			continue
		var skin: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/kaiju/test/%s.skin.json" % STAGES[stage])
		)
		var games: Array[String] = []
		for b: Dictionary in skin["bones"]:
			if not games.has(str(b["game"])):
				games.append(str(b["game"]))
		var same := games.size() == clips.bones.size() and clips.bones.size() == 27
		for g: String in games:
			same = same and clips.bones.has(g)
		tracks_ok = tracks_ok and same
		report += " %s %d" % [stage, clips.bones.size()]
		for clip: String in ["idle", "walk", "turn_left", "turn_right", "roar"]:
			all_ok = all_ok and clips.has_clip(clip)
		all_ok = all_ok and clips.loops("walk") and not clips.loops("roar")
	check(tracks_ok, "each stage's clips have one track per game bone of its skin (%s)" % report)
	check(all_ok, "every stage has idle, walk, both turns and the roar baked")


## The croc titan moves by clips at every stage; the other species keep their procedural gaits;
## clips baked for one skeleton are refused by another.
func _check_who_uses_clips() -> void:
	var adult := _model("reptilian", "adult")
	var rig := _rig_of(adult)
	check(rig.gait is ClipGait, "the croc titan adult moves by its clips")
	var baby := _model("reptilian", "baby")
	var young := _model("reptilian", "adolescent")
	check(
		_rig_of(baby).gait is ClipGait and _rig_of(young).gait is ClipGait,
		"the croc titan baby and adolescent move by their clips"
	)
	var mantis := _model("insectoid", "adult")
	var octopus := _model("cephalopod", "adult")
	check(
		_rig_of(mantis).gait is HexapodGait and _rig_of(octopus).gait is RadialGait,
		"the mantis and the octopus keep their procedural gaits"
	)
	var clips := KaijuClips.read(CLIPS)
	var bones_match := clips.fit(rig).is_empty()
	var refused := not clips.fit(_rig_of(baby)).is_empty()
	check(
		bones_match and refused,
		"the clips fit the croc titan's rig and are refused by another skeleton"
	)
	for kaiju: KaijuModel in [adult, baby, young, mantis, octopus]:
		kaiju.queue_free()
	await process_frame


## Walking a known distance advances the walk by distance / stride cycles, whatever the speed,
## and planted feet hold.
func _check_walk_phase() -> void:
	var kaiju := _model("reptilian", "adult")
	var gait: ClipGait = _rig_of(kaiju).gait
	var speeds: Array[float] = [3.0, 6.0]
	var ok := true
	var report := ""
	for v: float in speeds:
		var start_cycles := gait.walk_cycles
		var start := kaiju.position
		for frame: int in 240:
			kaiju.position += Vector3(0, 0, -v * DT)
			kaiju.animate(DT, 1.0)
		var walked := (kaiju.position - start).length()
		var want := walked / gait.stride()
		var got := gait.walk_cycles - start_cycles
		ok = ok and absf(got - want) < 0.1 * want
		report += " %.2f/%.2f" % [got, want]
	check(
		gait.state == "walk" and ok,
		"the walk advances one cycle per stride travelled (got/want%s)" % report
	)
	var hip := kaiju.hip_height()
	check(
		kaiju.foot_drift() <= 0.05 * hip,
		"planted feet hold on the clip walk (drift %.3f <= %.3f)" % [kaiju.foot_drift(), 0.05 * hip]
	)
	kaiju.queue_free()
	await process_frame


## Standing, a 90 deg heading change plays the turn clip to that side and ends facing the new
## heading; a roar plays, drops the jaw (the skin shows the mouth) and settles back to idle. No
## bone transform goes NaN or infinite at any frame.
func _check_turn_and_roar() -> void:
	var kaiju := _model("reptilian", "adult")
	var rig := _rig_of(kaiju)
	var gait: ClipGait = rig.gait
	var skin: VoxelSkin = kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)[0]
	var finite := true
	var turned := ""
	for frame: int in 30:
		finite = finite and _step(kaiju, rig)
	kaiju.rotation.y = PI * 0.5  # the sim turns the kaiju left
	for frame: int in 300:
		finite = finite and _step(kaiju, rig)
		if gait.state.begins_with("turn"):
			turned = gait.state
	var facing := absf(wrapf(rig.global_rotation.y - PI * 0.5, -PI, PI))
	check(
		turned == "turn_left" and facing < 0.05 and gait.state == "idle",
		(
			"standing, a left heading change plays the left turn and ends facing it (%s, off %.3f)"
			% [turned, facing]
		)
	)
	kaiju.roar()
	var opened := false
	for frame: int in 420:
		finite = finite and _step(kaiju, rig)
		opened = opened or skin.mouth_open
	check(
		opened and gait.state == "idle",
		"the roar drops the jaw (mouth shows) and settles back to idle"
	)
	check(finite, "no bone turns NaN or infinite through idle, turn and roar")
	kaiju.queue_free()
	await process_frame


## Curving while walking (no turn clip plays) swings the tail out against the turn, and once the
## walk straightens the swing dies away within a second.
func _check_tail_lag() -> void:
	var kaiju := _model("reptilian", "adult")
	var gait: ClipGait = _rig_of(kaiju).gait
	var biggest := 0.0
	for frame: int in 180:
		if frame >= 30 and frame < 120:
			kaiju.rotation.y += 0.8 * DT  # the sim steers left
		kaiju.position += kaiju.basis * Vector3(0, 0, -4.0 * DT)
		kaiju.animate(DT, 1.0)
		biggest = maxf(biggest, absf(gait.tail_shown))
	var left := absf(gait.tail_shown)
	check(
		gait.state == "walk" and biggest > 0.002 and left < 0.1 * biggest,
		(
			"a curve while walking swings the tail out and it settles (peak %.4f, left %.4f)"
			% [biggest, left]
		)
	)
	kaiju.queue_free()
	await process_frame


## The clips own the tail: walking straight, every tail bone shows the clip's turn (within 0.01
## rad, the turn-lag spring settling from the first frames; BipedSwing's sway alone is 0.03: the
## procedural tail and the spring chains don't run), and a standing turn's whip
## bends a tail joint past the procedural tail's clamp (BipedSwing.TAIL_BEND_MAX).
func _check_tail_owner() -> void:
	var kaiju := _model("reptilian", "adult")
	var rig := _rig_of(kaiju)
	var gait: ClipGait = rig.gait
	for frame: int in 120:
		kaiju.position += Vector3(0, 0, -4.0 * DT)
		kaiju.animate(DT, 1.0)
	var pose := gait.clips.pose_at("walk", gait.clip_time)
	var worst := 0.0
	for i: int in gait.clips.bones.size():
		if gait.clips.bones[i].begins_with("tail"):
			var shown := rig.bone(gait.clips.bones[i]).transform.basis.get_rotation_quaternion()
			worst = maxf(worst, shown.angle_to(pose.turns[i]))
	var most := 0.0
	for frame: int in 30:
		kaiju.animate(DT, 0.0)  # stand
	kaiju.rotation.y += PI * 0.5
	for frame: int in 300:
		kaiju.animate(DT, 0.0)
		for n: String in gait.clips.bones:
			if n.begins_with("tail"):
				most = maxf(most, rig.bone(n).transform.basis.get_rotation_quaternion().get_angle())
	check(
		worst < 0.01 and most > BipedSwing.TAIL_BEND_MAX,
		(
			"the clips own the tail (off the clip %.4f rad; turn bends %.3f > clamp %.2f)"
			% [worst, most, BipedSwing.TAIL_BEND_MAX]
		)
	)
	kaiju.queue_free()
	await process_frame


## The roar's tail slam lands once, as a heavy footfall at the tail tip on the street (the scene's
## dust, ring and camera dip), not as damage.
func _check_tail_slam() -> void:
	var kaiju := _model("reptilian", "adult")
	var rig := _rig_of(kaiju)
	var slams: Array[Vector3] = []
	rig.foot_planted.connect(
		func(side: String, _strength: float, at: Vector3) -> void:
			if side == "tail":
				slams.append(at)
	)
	for frame: int in 30:
		kaiju.animate(DT, 0.0)
	kaiju.roar()
	for frame: int in 420:
		kaiju.animate(DT, 0.0)
	var behind := (
		slams.size() == 1 and (slams[0] - rig.global_position).length() > kaiju.hip_height()
	)
	check(behind, "the roar's tail slam lands once, behind the kaiju (%d slams)" % slams.size())
	kaiju.queue_free()
	await process_frame


func _step(kaiju: KaijuModel, rig: KaijuRig) -> bool:
	kaiju.animate(DT, 0.0)
	for bone_name: String in rig.bone_names():
		var t := rig.bone(bone_name).global_transform
		if not (
			t.basis.x.is_finite()
			and t.basis.y.is_finite()
			and t.basis.z.is_finite()
			and t.origin.is_finite()
		):
			return false
	return true
