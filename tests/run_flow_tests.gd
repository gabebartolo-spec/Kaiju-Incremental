extends "res://tests/lib/runner.gd"
## Flow suite: every screen builds headless and is driven by real input (tests/lib/
## flow_screens.gd), and the rampage presentation survives a played rampage through its end
## beat without a script error.
##   godot --headless --path . --script tests/run_flow_tests.gd

const FlowScreens := preload("res://tests/lib/flow_screens.gd")
const FlowDemo := preload("res://tests/lib/flow_demo.gd")
const GuiInput := preload("res://tests/lib/gui_input.gd")
const RAMPAGE_FRAMES := 60 * 75
const POWER_FRAMES := 60 * 45
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
	await demo.run()
	# The full game (every species, every evolution) with the demo switched off.
	demo.demo_off()
	await FlowScreens.new(self, check).run()
	_check_display_font()
	await _check_species_select()
	await _check_upgrade_screen()
	await _check_rampage()
	_check_stomp_timing()
	await _check_warm_start()
	await _check_powers("reptilian", "breath", UPGRADED)
	await _check_powers("insectoid", "leap", {})
	await _check_powers("cephalopod", "lash", {})
	await _check_branch_view(
		"reptilian",
		{"r_tail": 2, "r_momentum": 2, "r_beam": 1},
		["tail_sweep", "beam_start", "coated", "heli_spawned", "heli_fired"]
	)
	await _check_branch_view(
		"insectoid",
		{"i_glide": 1, "i_climb": 1, "i_brood": 1},
		["glide_start", "eggs_laid", "brood_hatched", "brood_bite"]
	)
	await _check_branch_view(
		"cephalopod", {"c_hydra": 2, "c_grab": 1, "c_ink": 1}, ["limb", "grab", "throw_land", "ink"]
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
	var buttons := select.find_children("*", "Button", true, false)
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
		texts.has("Tail Sweep") and texts.has("ULTIMATE: Atomic Beam") and not texts.has("Scuttle"),
		"the reptilian's tree shows its own branch and no other species': %s" % [texts]
	)
	if claws != null:
		Sfx.ui_played.clear()
		await GuiInput.click(self, claws)
		check(Sfx.ui_played == ["ui_confirm"], "a purchase confirms: %s" % [Sfx.ui_played])
		check(
			tree.level("claws") == 1 and screen.rubble == 15,
			"pressing Sharpened Claws buys it for 15 (rubble %d)" % screen.rubble
		)
		Sfx.ui_played.clear()
		await GuiInput.click(self, claws)  # level 2 costs more than the 15 left
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
		check(street.killed > 0, "stomps and falls crush people (%d)" % street.killed)
	check(rampage.sim.over, "an autoplayed rampage ends within %d frames" % RAMPAGE_FRAMES)
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
	# A world hint that pops during the end beat must not show behind the headline.
	var city: CityView = GuiInput.find_script(rampage, CityView)
	var at := rampage.sim.kaiju_pos
	city.float_text("LATE HINT", Vector3(at.x, 4.0, at.y), Color.WHITE)
	await process_frame
	await process_frame
	var hints := city.find_children("*", "Label3D", true, false).filter(
		func(n: Node) -> bool: return (n as Label3D).visible and (n as Label3D).text != ""
	)
	check(hints.is_empty(), "no world hint shows behind the end beat: %d" % hints.size())
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
		heard.has("footstep") and heard.has("collapse"),
		"the kaiju's feet and falling buildings make sounds: %s" % [heard.slice(0, 12)]
	)
	rampage.queue_free()
	await process_frame


## Each signature attack plays its own effect; the upgraded kaiju also shows its upgrades
## (cracking stomps, ready pulse, glancing shells, healing motes) and a plain one does not crack
## the street.
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
	var played := rampage.ability_fx.played
	var heard := rampage.sfx.played
	var cues: Array[String] = [
		"stomp_2", "stomp_crack", "ready", "deflect", "regen_loop", "tank_fire"
	]
	var frames := 0
	var want: Array[String] = [kind]
	if not levels.is_empty():
		want.append_array(["cracks", "ready", "deflect", "regen"])
	while frames < POWER_FRAMES and not rampage.sim.over:
		await physics_frame
		frames += 1
		if want.all(func(k: String) -> bool: return played.has(k)):
			if levels.is_empty() or cues.all(func(c: String) -> bool: return heard.has(c)):
				break
	check(played.has(kind), "%s's signature plays its %s effect: %s" % [species_id, kind, played])
	var sound: String = SIGNATURE_SOUND[kind]
	check(heard.has(sound), "%s's signature sounds its %s: %s" % [species_id, sound, heard])
	if levels.is_empty():
		if species_id == "cephalopod":
			check(not played.has("cracks"), "an unupgraded kaiju's stomps do not crack the street")
	else:
		for k: String in ["cracks", "ready", "deflect", "regen"]:
			check(played.has(k), "the upgraded %s shows %s: %s" % [species_id, k, played])
		check(
			cues.all(func(c: String) -> bool: return heard.has(c)),
			"the upgraded %s's upgrades each have a sound: %s" % [species_id, heard]
		)
	rampage.queue_free()
	await process_frame


## A sim stomp waits for the next foot plant to sound (so the thump lands on a foot), then
## plays its tier and the ground crack instead of a footstep; steps pitch by size tier.
func _check_stomp_timing() -> void:
	var sfx := Sfx.new(Seeds.make("sfx", 0))
	root.add_child(sfx)
	sfx.stomp(2.0, true)
	var dynamics: Dictionary = Content.section("sfx")["dynamics"]
	var ceiling := INF
	for i: int in AudioServer.get_bus_effect_count(0):
		var effect := AudioServer.get_bus_effect(0, i)
		if effect is AudioEffectHardLimiter:
			ceiling = (effect as AudioEffectHardLimiter).ceiling_db
	check(
		is_equal_approx(ceiling, Num.f(dynamics["ceiling_db"])),
		"a hard limiter holds Master under %s dBFS (found %s)" % [dynamics["ceiling_db"], ceiling]
	)
	var early := sfx.played.duplicate()
	var buses: Array[String] = []
	for player: Node in sfx.get_children():
		buses.append((player as AudioStreamPlayer).bus)
	check(
		buses.all(func(b: String) -> bool: return b == "SFX"),
		"every power sound plays on the SFX bus: %s" % [buses]
	)
	sfx.footstep(0.7)
	check(
		early.is_empty() and sfx.played == ["stomp_2", "stomp_crack"],
		"a stomp sounds on the next foot plant, not before: %s then %s" % [early, sfx.played]
	)
	var pitches: Array[float] = []
	for tier: int in [1, 4]:
		sfx.set_size_tier(tier)
		sfx._process(1.0)  # past footstep_min_interval
		sfx.footstep(1.0)
		pitches.append(sfx.last_pitch())
	check(
		pitches[0] > pitches[1] * 1.2,
		"a baby's steps sound higher than a Behemoth's (pitch %s)" % [pitches]
	)
	sfx.free()


## Nothing a rampage shows for the first time stalls a frame on a build: the scorch Atomic Breath
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
	VehicleParts.set_opacity(a, 0.3)
	var mat_b := hull_b.material_override as ShaderMaterial
	if mat_b == null:
		mat_b = (hull_b.multimesh.mesh as PrimitiveMesh).material as ShaderMaterial
	var faded_b: Variant = mat_b.get_shader_parameter("opacity")
	check(
		hull_a.multimesh == hull_b.multimesh and (faded_b == null or Num.f(faded_b) >= 1.0),
		"a second tank reuses the first one's voxels, and fading one leaves the other solid"
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
	check(
		rampage.sfx.played.has("heli_rotor"),
		"the %s's helicopters are heard: %s" % [species_id, rampage.sfx.played.slice(-8)]
	)
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
