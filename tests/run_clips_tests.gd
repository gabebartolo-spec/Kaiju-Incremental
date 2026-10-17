extends "res://tests/lib/runner.gd"
## Clips suite (D-047): the croc titan moves by its baked Blender clips (KaijuClips, ClipGait).
## The clip file loads and fits the rig it was baked for (same bones and order as the skin), a
## file for another skeleton is refused, the walk's phase follows the distance travelled, a
## standing heading change turns on the spot, the roar opens the jaw and ends, no bone goes NaN,
## and every other kaiju keeps its procedural gait. Fixed 60 Hz steps, no clock, no randomness.
##   godot --headless --path . --script tests/run_clips_tests.gd
## Seeded by design: nothing here draws random numbers (the gaits seed their own twitches).

const CLIPS := "res://assets/kaiju/reptilian_adult.kclip"
const DT := 1.0 / 60.0


func suite_name() -> String:
	return "Clips"


func run_checks() -> void:
	_check_file()
	await _check_who_uses_clips()
	await _check_walk_phase()
	await _check_turn_and_roar()


func _model(species: String, stage: String) -> KaijuModel:
	var def: Dictionary = Content.species_def(species)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(species, colors, stage)
	root.add_child(kaiju)
	return kaiju


func _rig_of(kaiju: KaijuModel) -> KaijuRig:
	return kaiju.find_children("*", "KaijuRig", true, false)[0]


## The clips list one track per game bone in the rig's order, each gathering the skin export's
## bones of that game name, and every clip the gait plays is there.
func _check_file() -> void:
	var clips := KaijuClips.read(CLIPS)
	check(clips != null, "the croc titan's clip file loads")
	if clips == null:
		return
	var skin: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/kaiju/test/croctitan.skin.json")
	)
	var games: Array[String] = []
	for b: Dictionary in skin["bones"]:
		if not games.has(str(b["game"])):
			games.append(str(b["game"]))
	var same := games.size() == clips.bones.size()
	for g: String in games:
		same = same and clips.bones.has(g)
	check(
		same and clips.bones.size() == 27,
		"the clips have one track per game bone of the skin export (%d)" % clips.bones.size()
	)
	var all := true
	for clip: String in ["idle", "walk", "turn_left", "turn_right", "roar"]:
		all = all and clips.has_clip(clip)
	check(
		all and clips.loops("walk") and not clips.loops("roar"),
		"idle, walk, both turns and the roar are baked"
	)


## The adult reptilian (the croc titan) walks by clips; its other stages and the other species
## keep their procedural gaits; clips baked for one skeleton are refused by another.
func _check_who_uses_clips() -> void:
	var adult := _model("reptilian", "adult")
	var rig := _rig_of(adult)
	check(rig.gait is ClipGait, "the croc titan adult moves by its clips")
	var young := _model("reptilian", "adolescent")
	var mantis := _model("insectoid", "adult")
	var octopus := _model("cephalopod", "adult")
	check(
		(
			not _rig_of(young).gait is ClipGait
			and _rig_of(young).gait is BipedGait
			and _rig_of(mantis).gait is HexapodGait
			and _rig_of(octopus).gait is RadialGait
		),
		"the adolescent, the mantis and the octopus keep their procedural gaits"
	)
	var clips := KaijuClips.read(CLIPS)
	var bones_match := clips.fit(rig).is_empty()
	var refused := not clips.fit(_rig_of(young)).is_empty()
	check(
		bones_match and refused,
		"the clips fit the croc titan's rig and are refused by another skeleton"
	)
	for kaiju: KaijuModel in [adult, young, mantis, octopus]:
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
