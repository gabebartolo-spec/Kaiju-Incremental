extends RefCounted
## The slowmo suite's whole-rampage checks (tests/run_slowmo_tests.gd): the same seeded, autoplayed
## Behemoth rampage twice, a landmark felled at the same step in both, once with the landmark slow
## motion on and once with it off. The sim must take the same steps and end in the same state
## (D-259: slow motion is presentation only); the world must really slow in the "on" run and come
## back to full speed; and in both runs the rooftop squads' rounds land on the hide the way a tank
## shell does (HideHit, D-245), with nothing in the rooftop view drawn over the body.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const SEED := 0
## Behemoth levels: the stage with rooftop squads and landmarks standing.
const LEVELS := {"claws": 3, "hide": 3, "rage": 3, "evolve1": 1}
## Rampage's own sim step count at which the rooftop squads fire a volley (after the rise from the
## river, before any tank can reach the kaiju), a landmark is felled, and both runs stop.
const ROOF_STEP := 170
const FELL_STEP := 330
const END_STEP := 700
## Physics frames to wait for a slowdown to start, and for a volley's rounds to land.
const SLOW_WAIT_FRAMES := 12
const LAND_WAIT_FRAMES := 90

var t: SceneTree
var check: Callable
## The run being played, and what it has seen so far.
var _rampage: Rampage
var _seen := {}
var _last_events: Array[Dictionary] = []
var _trace := PackedStringArray()
## Whether this run's checks count (the "on" run's); the "off" run only has to match it.
var _judge := false


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func run() -> void:
	var on := await _play(true)
	var off := await _play(false)
	_compare(on, off)
	Engine.time_scale = 1.0


## Plays one rampage up to END_STEP sim steps and answers what it saw: the sim's end state and
## event trace, the slowest the world got, and how many physics frames it took.
func _play(slowmo_on: bool) -> Dictionary:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(
		Content.tuning(), Num.i(stats["size"]), Seeds.make("city", SEED)
	)
	_rampage = Rampage.new()
	_rampage.setup(species, stats, layout, SEED)
	_rampage.set_autoplay(true)
	t.root.add_child(_rampage)
	await _rampage.wait_loaded()
	var slowmo: Node = _rampage.get("_slowmo")  # null before the slow motion existed
	if slowmo != null:
		slowmo.set("enabled", slowmo_on)
	_judge = slowmo_on
	_seen = {"slowest": 1.0, "frames": 0, "slowed_at": -1}
	_last_events = []
	_trace = PackedStringArray()
	var roofs: RooftopView = GuiInput.find_script(_rampage, RooftopView)
	var shot := false
	var fell := false
	while _steps() < END_STEP and not _rampage.sim.over:
		await _frame()
		if not shot and _steps() >= ROOF_STEP:
			shot = true
			await _rooftop_hits(roofs)
		if not fell and _steps() >= FELL_STEP:
			fell = true
			_fell_landmark(_rampage.sim)
			if slowmo_on:
				await _slows_and_restores()
	var out := _seen
	out["trace"] = _trace
	out["digest"] = _digest(_rampage.sim)
	out["steps"] = _steps()
	out["fell"] = fell
	out["shot"] = shot
	_rampage.free()
	Engine.time_scale = 1.0
	await t.process_frame
	return out


func _steps() -> int:
	return Num.i(_rampage.get("_steps"))


## One physics frame of the run, noting the slowest the world got and every event the sim reported.
func _frame() -> void:
	await t.physics_frame
	_seen["frames"] = Num.i(_seen["frames"]) + 1
	if Engine.time_scale < Num.f(_seen["slowest"]):
		_seen["slowest"] = Engine.time_scale
	if Engine.time_scale < 1.0 and Num.i(_seen["slowed_at"]) < 0:
		_seen["slowed_at"] = _steps()
	var events := _rampage.sim.events
	if not is_same(events, _last_events):
		_last_events = events
		for event: Dictionary in events:
			_trace.append(str(event["type"]))


## The landmark's chunks removed up to the felled share, so the sim reports landmark_felled itself.
func _fell_landmark(sim: RampageSim) -> void:
	var share := Num.f(Content.section("results")["landmark_felled_share"])
	for b: RampageSim.Building in sim.buildings:
		if b.landmark == "":
			continue
		var live: Array[Vector3i] = []
		for x: int in b.w:
			for z: int in b.d:
				for y: int in b.height:
					if b.frame.alive(Vector3i(x, y, z)):
						live.append(Vector3i(x, y, z))
		for c: Vector3i in live.slice(0, ceili(share * live.size())):
			b.frame.remove(c)
		return


## The fall slows the world within a few frames and the world is back at full speed once the
## tuned time has gone (counted in physics frames: 60 a second whatever the time scale).
func _slows_and_restores() -> void:
	var cfg: Dictionary = Content.section("slowmo")
	var frames := 0
	while Engine.time_scale >= 1.0 and frames < SLOW_WAIT_FRAMES:
		await _frame()
		frames += 1
	check.call(
		is_equal_approx(Engine.time_scale, Num.f(cfg["scale"])),
		(
			"a landmark fall slows the world to the tuned %s (it is %.3f)"
			% [cfg["scale"], Engine.time_scale]
		)
	)
	var total := Num.f(cfg["hold_s"]) + Num.f(cfg["ease_s"])
	var ticks := 0
	var budget := ceili(total * 60.0) + SLOW_WAIT_FRAMES
	while Engine.time_scale < 1.0 and ticks < budget:
		await _frame()
		ticks += 1
	check.call(
		Engine.time_scale == 1.0 and ticks <= ceili(total * 60.0) + 2,
		"and back to full speed within the tuned %.2f s (%d ticks)" % [total, ticks]
	)
	check.call(not _rampage.sim.over, "the rampage went on through it")


## Rooftop rounds land on the hide: the rooftop view holds no material drawn over everything, and
## for the rounds that land a flash quad lies on the hide (depth-tested) and the hide keeps a
## wound. Both runs wait the same frames, so the sim stays in step; only the "on" run's count.
func _rooftop_hits(roofs: RooftopView) -> void:
	var hide: HideHit = _rampage._city.fx.get("_hide_hit")
	var kaiju: KaijuModel = _rampage._kaiju
	var squads := _rampage.sim.army_units.squads.slice(0, 3)
	var wounds := kaiju.hide_hits().live()
	var logged := roofs.spark_log.size()
	for squad: Army.Squad in squads:
		roofs.fired(squad.id, _rampage._kaiju_at)
	var most := 0
	var depth_tested := true
	for _i: int in LAND_WAIT_FRAMES:
		await _frame()
		var quads := _quads(hide)
		most = maxi(most, quads.size())
		for quad: MeshInstance3D in quads:
			var mat := quad.material_override as ShaderMaterial
			depth_tested = depth_tested and not mat.shader.code.contains("depth_test_disabled")
	if not _judge:
		return
	var landed := roofs.spark_log.size() - logged
	check.call(not squads.is_empty(), "rooftop squads stand on the roofs (%d)" % squads.size())
	for mmi: Node in roofs.find_children("*", "MultiMeshInstance3D", true, false):
		var mesh := (mmi as MultiMeshInstance3D).multimesh.mesh
		for i: int in mesh.get_surface_count():
			var drawn := mesh.surface_get_material(i) as BaseMaterial3D
			check.call(
				drawn == null or not drawn.no_depth_test,
				"nothing in the rooftop view is drawn over the body (%s)" % mesh
			)
	check.call(landed > 0, "rooftop rounds land on the hide (%d landed)" % landed)
	check.call(most > 0, "and each lands a HideHit flash quad on it (%d at once)" % most)
	check.call(depth_tested, "the hit is depth-tested, so a body in front hides it")
	check.call(
		kaiju.hide_hits().live() > wounds,
		"and the hide keeps a faint wound (%d)" % kaiju.hide_hits().live()
	)


## HideHit's live flash quads (not the prewarm's, which sits far below the world).
func _quads(hide: HideHit) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in hide.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).global_position.y > -10.0:
			out.append(c)
	return out


## The sim's state as text: every number that a different step size or order would change.
func _digest(sim: RampageSim) -> String:
	var alive := 0
	for b: RampageSim.Building in sim.buildings:
		alive += b.frame.alive_count
	return (
		"elapsed %.9f left %.9f pos %s rubble %.9f hp %.9f chunks %d alive %d tanks %d"
		% [
			sim.elapsed,
			sim.time_left,
			sim.kaiju_pos,
			sim.rubble,
			sim.hp,
			sim.chunks_destroyed,
			alive,
			sim.tanks.size(),
		]
	)


## The two runs took the same sim steps and reached the same state; only the "on" run slowed.
func _compare(on: Dictionary, off: Dictionary) -> void:
	check.call(
		on["fell"] == true and off["fell"] == true and on["shot"] == true and off["shot"] == true,
		"both runs shot at the kaiju and felled the landmark"
	)
	check.call(
		Num.f(off["slowest"]) == 1.0, "with it off the world never slows (%s)" % off["slowest"]
	)
	check.call(
		Num.f(on["slowest"]) < 1.0 and Num.i(on["slowed_at"]) >= FELL_STEP,
		(
			"with it on the world slows only after the fall (slowest %s, from step %s)"
			% [on["slowest"], on["slowed_at"]]
		)
	)
	check.call(
		Num.i(on["frames"]) > Num.i(off["frames"]),
		"slowed, the same sim steps take more frames (%d vs %d)" % [on["frames"], off["frames"]]
	)
	check.call(
		Num.i(on["steps"]) == Num.i(off["steps"]),
		"the sim took the same number of steps (%d vs %d)" % [on["steps"], off["steps"]]
	)
	check.call(
		on["digest"] == off["digest"],
		"and ended in the same state:\n  on  %s\n  off %s" % [on["digest"], off["digest"]]
	)
	var trace_on: PackedStringArray = on["trace"]
	var trace_off: PackedStringArray = off["trace"]
	check.call(
		trace_on == trace_off and trace_on.has("landmark_felled"),
		"and reported the same events in the same order (%d)" % trace_on.size()
	)
