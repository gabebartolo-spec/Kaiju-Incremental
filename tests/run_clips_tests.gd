extends "res://tests/lib/runner.gd"
## Clips suite (D-047): the croc titan moves by its baked clips (KaijuClips, ClipGait) at every
## stage, Blender clips, plus the adult's approved Cascadeur keys (rig r11): roar, rise, death.
## The clip file loads and fits the rig it was baked for (same bones and order as the skin), a
## file for another skeleton is refused, the adult's keyed clips are all there (the rise ends on
## the roar's start, the death stagger holds its stone pose), the walk's phase follows the distance
## travelled, a standing heading change turns on the spot, the roar opens the jaw and ends, no bone
## goes NaN, a curve while walking swings the tail out and it settles, the clips (not the
## procedural tail) own the tail bones, a roar keyed with a tail slam lands it as one footfall,
## and every other kaiju keeps its procedural gait. Fixed 60 Hz steps, no clock, no randomness.
##   godot --headless --path . --script tests/run_clips_tests.gd
## Seeded by design: nothing here draws random numbers (the gaits seed their own twitches).

const CLIPS := "res://assets/kaiju/reptilian_adult.kclip"
## Each croc titan stage and its Blender skin export (assets/kaiju/test/<name>.skin.json).
const STAGES := {
	"baby": "croctitan_baby", "adolescent": "croctitan_adolescent", "adult": "croc_adult3"
}
const DT := 1.0 / 60.0
## The adult's clips keyed in Cascadeur on rig r11 that the director approved (D-199, D-216;
## rise and roar D-274, the death stagger locked 2026-10-26): keyed at 30 fps, resampled to the
## file's 24 fps (frames each). His idle, walk and turns stay the Blender clips until he approves
## keyed ones (D-302).
const ADULT_KEYED := {"roar": 99, "rise_bay": 96, "death_stagger": 33}
## The death stagger's last frames are the stone pose (keyed still for its last 5 keyed frames).
const STONE_FRAMES := 4


func suite_name() -> String:
	return "Clips"


func run_checks() -> void:
	await _t("_check_file")
	await _t("_check_adult_keyed")
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
		var rig: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/kaiju/reptilian_%s.rig.json" % stage)
		)
		var order: Array[String] = []
		for r: Dictionary in rig["bones"]:
			order.append(str(r["name"]))
		var same := games.size() == clips.bones.size() and clips.bones == order
		for g: String in games:
			same = same and clips.bones.has(g)
		tracks_ok = tracks_ok and same
		report += " %s %d" % [stage, clips.bones.size()]
		for clip: String in ["idle", "walk", "turn_left", "turn_right", "roar"]:
			all_ok = all_ok and clips.has_clip(clip)
		all_ok = all_ok and clips.loops("walk") and not clips.loops("roar")
	check(tracks_ok, "each stage's clips have one track per game bone of its skin (%s)" % report)
	check(all_ok, "every stage has idle, walk, both turns and the roar baked")


## The adult plays his approved Cascadeur keys: each clip at its keyed length (played once), the
## rise from the bay ends on the pose the roar starts from, and the death stagger ends in the stone
## pose: its last frames are still and it holds that frame.
func _check_adult_keyed() -> void:
	var clips := KaijuClips.read(CLIPS)
	var ok := true
	var report := "fps %.0f" % clips.fps
	for clip: String in ADULT_KEYED:
		var n := clips.frames_of(clip) if clips.has_clip(clip) else 0
		ok = ok and n == ADULT_KEYED[clip] and not clips.loops(clip)
		report += ", %s %d" % [clip, n]
	check(ok, "the adult's Cascadeur clips load with their keyed lengths (%s)" % report)
	if not (clips.has_clip("rise_bay") and clips.has_clip("death_stagger")):
		check(false, "the adult has the rise from the bay and the death stagger")
		return
	var rise_end := float(clips.frames_of("rise_bay") - 1)
	var seam := _pose_gap(clips.pose_at("rise_bay", rise_end), clips.pose_at("roar", 0.0))
	check(
		seam.x < 0.02 and seam.y < 0.2,
		"the rise from the bay ends on the roar's first pose (%.4f rad, %.3f m)" % [seam.x, seam.y]
	)
	var last := float(clips.frames_of("death_stagger") - 1)
	var still := _pose_gap(
		clips.pose_at("death_stagger", last - STONE_FRAMES), clips.pose_at("death_stagger", last)
	)
	var held := _pose_gap(
		clips.pose_at("death_stagger", last), clips.pose_at("death_stagger", last + 120.0)
	)
	check(
		# held: the same frame, so only float noise (angle_to of a turn with itself reads ~0.001 rad)
		still.x < 0.01 and still.y < 0.1 and held.x < 0.002 and held.y < 0.001,
		(
			"the death stagger ends in the held stone pose (last %d frames %.4f rad, %.3f m; held %.4f)"
			% [STONE_FRAMES, still.x, still.y, held.x]
		)
	)


## The widest bone turn between two poses (rad) and the furthest pelvis or toe tip (m).
func _pose_gap(a: KaijuClips.Pose, b: KaijuClips.Pose) -> Vector2:
	var turn := 0.0
	for i: int in a.turns.size():
		turn = maxf(turn, a.turns[i].angle_to(b.turns[i]))
	var move := (a.offset - b.offset).length()
	for i: int in 2:
		move = maxf(move, (a.feet[i] - b.feet[i]).length())
	return Vector2(turn, move)


## The croc titan moves by clips at every stage; clips baked for one skeleton are refused by
## another.
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
	var clips := KaijuClips.read(CLIPS)
	var bones_match := clips.fit(rig).is_empty()
	var refused := not clips.fit(_rig_of(baby)).is_empty()
	check(
		bones_match and refused,
		"the clips fit the croc titan's rig and are refused by another skeleton"
	)
	for kaiju: KaijuModel in [adult, baby, young]:
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


## The sim eases a standing kaiju round 90 deg left (like the capture, rotation.y at dt x 10): the
## turn clip it starts, "" when the body only slid round.
func _eased_turn(stage: String) -> String:
	var kaiju := _model("reptilian", stage)
	kaiju.scale = Vector3.ONE * (0.5 if stage == "baby" else 1.3)
	var rig := _rig_of(kaiju)
	var gait: ClipGait = rig.gait
	var turned := ""
	for frame: int in 30:
		_step(kaiju, rig)
	for frame: int in 240:
		kaiju.rotation.y = lerpf(kaiju.rotation.y, PI * 0.5, minf(1.0, DT * 10.0))
		_step(kaiju, rig)
		if gait.state.begins_with("turn") and turned.is_empty():
			turned = gait.state
	kaiju.queue_free()
	return turned


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
	for stage: String in ["baby", "adult"]:
		turned = _eased_turn(stage)
		check(
			turned == "turn_left",
			(
				"standing, a %s eased round 90 deg left by the sim plays the left turn clip (%s)"
				% [stage, turned]
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
## dust, ring and camera dip), not as damage, for a roar keyed with one (the adolescent's Blender
## roar); the adult's Cascadeur roar arches its tail up and lands no slam.
func _check_tail_slam() -> void:
	var counts: Dictionary[String, int] = {}
	var behind := true
	for stage: String in ["adolescent", "adult"]:
		var kaiju := _model("reptilian", stage)
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
		counts[stage] = slams.size()
		for at: Vector3 in slams:
			behind = behind and (at - rig.global_position).length() > kaiju.hip_height()
		kaiju.queue_free()
		await process_frame
	check(
		counts["adolescent"] == 1 and behind,
		(
			"the Blender roar's tail slam lands once, behind the kaiju (%d slams)"
			% counts["adolescent"]
		)
	)
	check(counts["adult"] == 0, "the adult's keyed roar lands no slam (%d slams)" % counts["adult"])


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
