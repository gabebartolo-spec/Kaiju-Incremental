extends "res://tests/lib/runner.gd"
## Flow suite: every screen builds headless and is driven by real input (tests/lib/
## flow_screens.gd), and the rampage presentation survives a played rampage through its end
## beat without a script error.
##   godot --headless --path . --script tests/run_flow_tests.gd

const FlowScreens := preload("res://tests/lib/flow_screens.gd")
const FlowDemo := preload("res://tests/lib/flow_demo.gd")
const FlowLayout := preload("res://tests/lib/flow_layout.gd")
const FlowBreath := preload("res://tests/lib/flow_breath.gd")
const FlowTanks := preload("res://tests/lib/flow_tanks.gd")
const GuiInput := preload("res://tests/lib/gui_input.gd")
const FlowHeliSounds := preload("res://tests/lib/flow_heli_sounds.gd")
const FlowRifleSounds := preload("res://tests/lib/flow_rifle_sounds.gd")
const FlowSfx := preload("res://tests/lib/flow_sfx.gd")
const FlowCollapse := preload("res://tests/lib/flow_collapse.gd")
const FlowStadium := preload("res://tests/lib/flow_stadium.gd")
const FlowStagedStart := preload("res://tests/lib/flow_staged_start.gd")
const RAMPAGE_FRAMES := 60 * 75
const POWER_FRAMES := 60 * 45
## An armoured kaiju with no shell glanced off by now is walked to the nearest tank: a shell hits by
## chance, and in city seed 0 all four missed (D-166; 4 of 5 seeds deflect, foot or not).
const TANK_WALK_FRAMES := 60 * 30
const SIGNATURE_SOUND := {"breath": "breath", "leap": "leap_land", "lash": "lash"}
## Upgrades whose look the power checks prove: heavy stomps, recharge, scales, regeneration.
const UPGRADED := {
	"claws": 3,
	"hide": 1,
	"scales": 2,
	"evolve1": 1,
	"rage": 1,
	"regen": 2,
	"sig_power": 2,
	"sig_recharge": 4
}


func suite_name() -> String:
	return "Flow"


func run_checks() -> void:
	var demo := FlowDemo.new(self, check)
	await _h("FlowDemo", func() -> void: await demo.run())
	# The full game (every species, every evolution) with the demo switched off.
	demo.demo_off()
	await _h("FlowScreens", func() -> void: await FlowScreens.new(self, check).run())
	await _t("_check_display_font")
	await _t("_check_species_select")
	await _t("_check_upgrade_screen")
	await _t("_check_rampage")
	await _h("FlowSfx.run", func() -> void: FlowSfx.run(root, check))
	await _h("FlowSfx.gate", func() -> void: await FlowSfx.gate(root, check))
	await _h("FlowSfx.gate_timeout", func() -> void: FlowSfx.gate_timeout(root, check))
	await _h("FlowStadium", func() -> void: await FlowStadium.run(self, check))
	await _h("FlowStagedStart", func() -> void: await FlowStagedStart.run(self, check))
	await _t("_check_warm_start")
	await _t("_check_powers", ["reptilian", "breath", UPGRADED])
	await _t("_check_powers", ["insectoid", "leap", {}])
	await _t("_check_powers", ["cephalopod", "lash", {}])
	await _t(
		"_check_branch_view",
		[
			"reptilian",
			{"r_tail": 2, "r_momentum": 2, "r_beam": 1},
			["tail_sweep", "beam_start", "coated", "heli_spawned", "heli_fired"] as Array[String],
		]
	)
	await _t(
		"_check_branch_view",
		[
			"insectoid",
			{"i_glide": 1, "i_climb": 1, "i_brood": 1},
			["glide_start", "eggs_laid", "brood_hatched", "brood_bite"] as Array[String],
		]
	)
	await _t(
		"_check_branch_view",
		[
			"cephalopod",
			{"c_hydra": 2, "c_grab": 1, "c_ink": 1},
			["limb", "grab", "throw_land", "ink"] as Array[String],
		]
	)
	demo.demo_restore()


## The display font is a real font, not a Git LFS pointer: without the LFS checkout every
## Kaiju Claw heading, button and results value draws nothing (PR #14's first CI captures).
func _check_display_font() -> void:
	var font := UiKit.font_for(UiKit.SIZE_HEAD) as FontFile
	var bytes := FileAccess.get_file_as_bytes(UiKit.DISPLAY_FONT_PATH).size()
	check(
		font != null and bytes > 1024 and font.has_char("A".unicode_at(0)),
		"the Kaiju Claw display font loads with glyphs (%d bytes on disk)" % bytes
	)


func _check_species_select() -> void:
	var select := SpeciesSelect.new()
	root.add_child(select)
	await process_frame
	var buttons := select.find_children("*", "Button", true, false).filter(
		func(b: Node) -> bool: return (b as Button).text == "CHOOSE"
	)
	check(buttons.size() == 3, "the species screen offers three choices, found %d" % buttons.size())
	var picked: Array[String] = []
	select.chosen.connect(func(id: String) -> void: picked.append(id))
	var second: Button = buttons[1]
	await GuiInput.click(self, second)
	check(picked == ["insectoid"], "choosing the second card picks the insectoid: %s" % [picked])
	select.queue_free()
	await process_frame


func _check_upgrade_screen() -> void:
	var tree := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	var screen := UpgradeScreen.new()
	screen.setup(tree, 30, Content.species_def("reptilian"), Content.section("kaiju"))
	root.add_child(screen)
	await process_frame
	var buttons := screen.find_children("*", "Button", true, false)
	check(
		buttons.size() == tree.order.size() + 2,
		"the tree shows a button per upgrade plus Rampage and Menu"
	)
	var claws: Button = null
	for node: Node in buttons:
		var b: Button = node
		if b.text.begins_with("Sharpened Claws"):
			claws = b
	check(claws != null, "Sharpened Claws is on the tree")
	var texts: Array[String] = []
	for node: Node in buttons:
		var b: Button = node
		texts.append(b.text.get_slice("\n", 0))
	check(
		preload("res://tests/lib/flow_names.gd").own_branch(texts),
		"the reptilian's tree shows its own branch and no other species': %s" % [texts]
	)
	if claws != null:
		Sfx.ui_played.clear()
		await GuiInput.click(self, claws)
		check(Sfx.ui_played == ["ui_confirm"], "a purchase confirms: %s" % [Sfx.ui_played])
		check(  # 15 at the species' price (cost_mult, D-167)
			tree.level("claws") == 1 and screen.rubble == 30 - roundi(15 * tree.cost_mult),
			"pressing Sharpened Claws buys it at its price (rubble %d)" % screen.rubble
		)
		Sfx.ui_played.clear()
		await GuiInput.click(self, claws)  # level 2 costs more than what is left
		check(
			tree.level("claws") == 1 and Sfx.ui_played == ["ui_deny"],
			"a purchase it can't afford buzzes: %s" % [Sfx.ui_played]
		)
	screen.queue_free()
	await process_frame


func _check_rampage() -> void:
	var rampage := Rampage.new()
	var species := Content.species_def("cephalopod")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	rampage.set_autoplay(true)
	var results: Array[Dictionary] = []
	rampage.finished.connect(func(r: Dictionary) -> void: results.append(r))
	root.add_child(rampage)
	await process_frame
	var street := _street_life(rampage)
	check(
		street != null and street.civilians() > 100 and street.traffic.cars.size() > 20,
		"the city fills with civilians and moving cars",
	)
	var frames := 0
	while not rampage.sim.over and frames < RAMPAGE_FRAMES:
		await physics_frame
		frames += 1
	if street != null:
		check(street.fled > 0, "civilians run from the kaiju (%d fled)" % street.fled)
		check(street.traffic.fled > 0, "cars flee the kaiju (%d)" % street.traffic.fled)
		check(
			street.police.blockades_made > 0 and street.police.shots > 0,
			(
				"police blockade a street and open fire (%d, %d shots)"
				% [street.police.blockades_made, street.police.shots]
			),
		)
		check(street.kaiju_killed() > 0, "the kaiju crushes people (%d)" % street.kaiju_killed())
	check(rampage.sim.over, "an autoplayed rampage ends within %d frames" % RAMPAGE_FRAMES)
	# Rooftop defenders (D-063): figures stand on the squads' roofs, at most max_drawn of them,
	# and their volleys draw flashes and tracers and call the rifle cue.
	var roofs: RooftopView = GuiInput.find_script(rampage, RooftopView)
	var cap := Num.i(rampage.sim.army["rooftop"]["max_drawn"])
	check(
		roofs != null and roofs.most_drawn > 0 and roofs.most_drawn <= cap,
		(
			"armed citizens stand on the roofs, at most %d drawn (%d)"
			% [cap, roofs.most_drawn if roofs else -1]
		)
	)
	check(
		roofs != null and roofs.shots > 0 and rampage.sfx.played.has("rifle"),
		"rooftop squads open fire with the rifle cue (%d volleys)" % [roofs.shots if roofs else -1]
	)
	FlowRifleSounds.check_distance(check, rampage.sfx)
	FlowCollapse.check_all(check, rampage)
	check(
		rampage.sim.chunks_destroyed > 0,
		"the autoplayed kaiju destroys buildings (%d chunks)" % rampage.sim.chunks_destroyed
	)
	await process_frame
	var hud: RampageHud = GuiInput.find_script(rampage, RampageHud)
	var reason := rampage.sim.end_reason
	var want: Array = RampageHud.HEADLINES.get(reason, [""])
	check(
		hud.beat_running() and hud.headline.text == str(want[0]),
		"the end beat shows why it ended (%s: %s)" % [reason, hud.headline.text]
	)
	var hints := await FlowLayout.late_hints(self, rampage)
	check(hints == 0, "no world hint shows behind the end beat: %d" % hints)
	for _i: int in RampageHud.BEAT_FRAMES + 2:
		await process_frame
	check(
		results.size() == 1 and Num.i(results[0]["rubble"]) >= 0 and results[0].has("civilians"),
		"after the end beat the rampage reports its result, civilians counted"
	)
	check(
		results.size() == 1 and Num.i(results[0]["toppled"]) > 0,
		"an autoplayed rampage topples buildings: %s" % [results]
	)
	var heard := rampage.sfx.played
	check(
		heard.has("footstep") and heard.has("collapse") and heard.has("crowd_panic"),
		(
			"the kaiju's feet, falling buildings and the fleeing crowd are heard: %s"
			% [heard.slice(0, 12)]
		)
	)
	await preload("res://tests/lib/flow_ruin_fire.gd").run(self, check, rampage)  # #111
	rampage.queue_free()
	await process_frame


## Each signature attack plays its own effect; the upgraded kaiju also shows its upgrades
## (cracking stomps, or the croc's claw swipe (D-095), ready pulse, glancing shells, healing
## motes) and a plain one does not crack the street.
func _check_powers(species_id: String, kind: String, levels: Dictionary) -> void:
	var species := Content.species_def(species_id)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	rampage.sfx.live = true  # past the start gate (FlowSfx.gate checks the gate itself)
	var played := rampage.ability_fx.played
	var heard := rampage.sfx.played
	var swipes := Num.f(stats.get("swipe_damage", 0.0)) > 0.0
	# Claws sounds as the swipe's rake for the croc, as heavier, cracking stomps for the others.
	var cues: Array[String] = ["ready", "deflect", "regen_loop", "tank_fire"]
	cues.append_array(["lash"] if swipes else ["stomp_2", "stomp_crack"])
	var marks: Array[String] = ["swipe" if swipes else "cracks", "ready", "deflect", "regen"]
	var powers: PowersView = rampage.get("_powers")
	var frames := 0
	var want: Array[String] = [kind]
	if not levels.is_empty():
		want.append_array(marks)
	var jets := 0
	var scorch_glow := {}  # the breath scorch's glow on the frame it first appears, and its peak
	var aim := {}  # BreathAim against the sim's cone, every frame
	while frames < POWER_FRAMES and not rampage.sim.over:
		await physics_frame
		frames += 1
		if frames == TANK_WALK_FRAMES and not levels.is_empty() and not played.has("deflect"):
			FlowTanks.walk_to_nearest(rampage.sim)
		jets = maxi(jets, FlowBreath.jets(rampage))
		FlowBreath.track_scorch_glow(rampage, scorch_glow)
		FlowBreath.track_aim(rampage, aim)
		if want.all(func(k: String) -> bool: return played.has(k) or powers.played.has(k)):
			if levels.is_empty() or cues.all(func(c: String) -> bool: return heard.has(c)):
				break
	check(played.has(kind), "%s's signature plays its %s effect: %s" % [species_id, kind, played])
	var sound: String = SIGNATURE_SOUND[kind]
	check(heard.has(sound), "%s's signature sounds its %s: %s" % [species_id, sound, heard])
	if kind == "breath":
		check(jets == 0, "the breath is the beam alone, no pale voxel-cube jet (%d jets)" % jets)
		check(
			Num.i(aim.get("shown", 0)) > 0 and Num.f(aim.get("worst", 1.0)) < 0.001,
			"the ready breath's aim wedge is the cone it burns (%s)" % [aim]
		)
		var first := Num.f(scorch_glow.get("first", -1.0))
		var peak := Num.f(scorch_glow.get("peak", 0.0))
		check(
			first >= 0.0 and first < peak * 0.5,
			(
				"the breath scorch's molten cracks glow in, not at full on frame one (%.2f of %.2f)"
				% [first, peak]
			)
		)
	if levels.is_empty():
		if species_id == "cephalopod":
			check(not played.has("cracks"), "an unupgraded kaiju's stomps do not crack the street")
	else:
		for k: String in marks:
			check(
				played.has(k) or powers.played.has(k),
				"the upgraded %s shows %s: %s" % [species_id, k, played + powers.played]
			)
		check(
			cues.all(func(c: String) -> bool: return heard.has(c)),
			"the upgraded %s's upgrades each have a sound: %s" % [species_id, heard]
		)
	rampage.queue_free()
	await process_frame


## Nothing a rampage shows for the first time stalls a frame on a build: the scorch Lightning Breath
## leaves is drawn at load for this run's cone, and tanks share their voxels yet fade one by one.
func _check_warm_start() -> void:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	root.add_child(rampage)
	var half := deg_to_rad(Num.f(rampage.sim.city["cone_half_angle_deg"]))
	check(
		FxDecals.is_drawn(FxDecals.Shape.WEDGE, {"half_angle": half}),
		"the breath's scorch for this run's %.2f rad cone is drawn before the first breath" % half
	)
	rampage.queue_free()
	await process_frame
	var a := TankModel.new()
	var b := TankModel.new()
	var hull_a: MultiMeshInstance3D = a.get_child(0)
	var hull_b: MultiMeshInstance3D = b.get_child(0)
	var mat_b := hull_b.material_override as ShaderMaterial
	check(hull_a.multimesh == hull_b.multimesh, "a second tank reuses the first one's voxels")
	check(
		mat_b != null and Num.f(mat_b.get_shader_parameter("bubble_on")) == 1.0
		and hull_a.material_override != hull_b.material_override,
		"each tank's hull has its own material, cut away by the camera bubble"
	)
	a.free()
	b.free()


## An autoplayed rampage with a species branch bought (and a helicopter called in) draws every
## power it fires without a script error.
func _check_branch_view(species_id: String, levels: Dictionary, want: Array[String]) -> void:
	var species := Content.species_def(species_id)
	var tree := UpgradeTree.new(Content.upgrades(), levels, species_id)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	await physics_frame
	# Call the helicopters in the way a rampage does (through step), so the view sees heli_spawned.
	# The young city has no helicopters (D-039 stage 1); this check is about the view, so
	# give this run the base air wing.
	rampage.sim.air.cfg["max"] = Num.i(Content.section("air")["max"])
	rampage.sim.chunks_destroyed = Num.i(Content.section("air")["after_chunks"])
	var view: PowersView = rampage.find_children("*", "PowersView", true, false)[0]
	var frames := 0
	while frames < POWER_FRAMES and not rampage.sim.over:
		await physics_frame
		frames += 1
		if want.all(func(k: String) -> bool: return view.played.has(k)):
			break
	var missing := want.filter(func(k: String) -> bool: return not view.played.has(k))
	check(missing.is_empty(), "the %s's branch powers all show: missing %s" % [species_id, missing])
	FlowHeliSounds.check_heard(check, rampage, view, species_id)
	rampage.queue_free()
	await process_frame


func _street_life(node: Node) -> StreetLife:
	if node is StreetLife:
		var found: StreetLife = node
		return found
	for child: Node in node.get_children():
		var hit := _street_life(child)
		if hit != null:
			return hit
	return null
