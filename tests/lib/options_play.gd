extends RefCounted
## The options suite's rampage checks (tests/run_options_tests.gd): with the signature attack
## rebound to R, Space no longer breathes and R does (a real key press through Input); held moves
## on TOGGLE latch on that press; the pad rumble thuds on footfalls at the kaiju's growth stage,
## jolts on a stomp and a collapse, buzzes on the breath, and stays silent when switched off;
## Reduce flashing dims the city's flash lights, the helicopter flare, the far flashes and the end
## beat's screen flash, and hides the colour fringe. City seed 0, reptilian.

const FRAME := 1.0 / 60.0

var t: SceneTree
var check: Callable
var rampage: Rampage
var sent: Array[Vector3] = []


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func run() -> void:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage = Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	t.root.add_child(rampage)
	await rampage.wait_loaded()
	rampage.rumble.sink = func(r: Vector3) -> void: sent.append(r)
	PlayerSettings.rumble = true
	PlayerSettings.hold_toggle = true
	var frames := 0
	while rampage.sim.emerge.active and frames < 1200:
		await t.physics_frame
		frames += 1
	await _rebound_key()
	await _rumble()
	await _flashes()
	PlayerSettings.hold_toggle = false
	PlayerSettings.reduce_flashing = false
	rampage.free()
	Engine.time_scale = 1.0


func _press(code: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		for _i: int in 3:
			await t.physics_frame


func _rebound_key() -> void:
	var sim := rampage.sim
	var ready := sim.ability_ready_in <= 0.0
	await _press(KEY_SPACE)
	var after_space := sim.ability_ready_in
	await _press(KEY_R)
	check.call(
		ready and after_space <= 0.0 and sim.ability_ready_in > 0.0,
		(
			"in play Space no longer breathes and the rebound R does (ready %s, %.2f then %.2f)"
			% [ready, after_space, sim.ability_ready_in]
		)
	)
	check.call(
		rampage._reader.held_button.read(false, false),
		"held moves on TOGGLE: after R is let go the held move stays on"
	)
	var waited := 0
	while not sent.has(_row(Content.section("rumble")["breath"])) and waited < 240:
		await t.physics_frame  # the breath lands after its wind-up (Strikes), then it buzzes
		waited += 1
	check.call(
		sent.has(_row(Content.section("rumble")["breath"])),
		"the breath buzzes the pad (%d rumbles)" % sent.size()
	)


func _rumble() -> void:
	var cfg := Content.section("rumble")
	var tier := clampi(rampage.sim.size_tier() - 1, 0, 2)
	var foot := _row(cfg["footfall"][tier])
	sent.clear()
	rampage.set_autoplay(true)
	for _i: int in 180:
		await t.physics_frame
	rampage.set_autoplay(false)
	check.call(
		sent.has(foot),
		"walking thuds the pad at stage %d's footfall %s (%s)" % [tier + 1, foot, sent]
	)
	var size: Variant = rampage.sim.stats["size"]
	rampage.sim.stats["size"] = 3.0  # an adult's feet
	rampage.rumble.footfall("left", 1.0, Vector3.ZERO)
	rampage.sim.stats["size"] = size
	check.call(
		sent[-1] == _row(cfg["footfall"][2]) and sent[-1].y > foot.y,
		"an adult's footfall thuds harder than a baby's (%s vs %s)" % [sent[-1], foot]
	)
	rampage._land_stomp("left", rampage._kaiju_at)
	rampage.rumble.on_event({"type": "fall_land", "kind": "topple"})
	check.call(
		sent.slice(-2) == [_row(cfg["stomp"][tier]), _row(cfg["collapse"])],
		"a stomp and a toppled building jolt the pad %s" % [sent.slice(-2)]
	)
	PlayerSettings.rumble = false
	var count := sent.size()
	rampage.rumble.footfall("left", 1.0, Vector3.ZERO)
	rampage.rumble.stomp()
	check.call(sent.size() == count, "with Rumble OFF nothing reaches the pad")


func _flashes() -> void:
	var lit: Array[float] = []
	var fringe: Array[bool] = []
	var far: Array[float] = []
	var flare: Array[float] = []
	for reduce: bool in [false, true]:
		PlayerSettings.reduce_flashing = reduce
		rampage._city.flash(Vector3.ZERO, Color.WHITE, 7.0, 0.5)
		var lights := rampage._city.find_children("*", "OmniLight3D", false, false)
		lit.append((lights[-1] as OmniLight3D).light_energy)
		var fx: PostFx = rampage.find_children("*", "PostFx", true, false)[0]
		fx.state = PostFxState.new()
		fx.state.stomp(100.0)
		fx.update(FRAME, 1.0, 1.0)
		fringe.append(fx.rects()[1].visible)
		var flash := FarFlash.new({"color": Color.WHITE, "size": 1.0, "life": 1.0})
		far.append(flash._bright)
		flash.free()
		HeliFx.flare(rampage, Vector3.ZERO, 2.0, 1.0)
		var quad: MeshInstance3D = rampage.get_child(rampage.get_child_count() - 1)
		await t.process_frame
		await t.process_frame
		var mat := (quad.mesh as QuadMesh).material as ShaderMaterial
		flare.append(Num.f(mat.get_shader_parameter("fade")))
	var share := Num.f(Content.section("accessibility")["flash_scale"])
	check.call(
		is_equal_approx(lit[1], lit[0] * share) and far[1] == share and flare[1] < flare[0],
		"Reduce flashing dims lights %s, far flashes %s and flares %s" % [lit, far, flare]
	)
	check.call(fringe == [true, false], "Reduce flashing hides the colour fringe %s" % [fringe])
	rampage._hud.show_end_beat("time")
	await t.process_frame
	var alpha := 1.0
	for node: Node in rampage._hud.get_children():
		if node is ColorRect and is_equal_approx((node as ColorRect).color.g, 0.55):
			alpha = (node as ColorRect).color.a
	check.call(alpha <= 0.45 * share + 0.01, "the end beat's screen flash is dimmed (%.2f)" % alpha)


func _row(value: Variant) -> Vector3:
	var row: Dictionary = value
	return Vector3(Num.f(row["weak"]), Num.f(row["strong"]), Num.f(row["seconds"]))
