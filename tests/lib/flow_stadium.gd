extends RefCounted
## D-078 for the flow suite: a match plays in the stadium (one sport of four, players of two
## kits and a ball kicked about), and the moment the stadium loses its first chunk every player
## runs for the tunnels; once out (or crushed) they are gone from the pitch. The stands are full
## of seated fans (director 2026-10-18) who stand and stream out of the exits with the players,
## and every section it sheds bursts where it stands, never swinging over the pitch. The run
## plays the stage-2 city: the stadium stands past the young city's edge, reachable from stage 2
## (D-271 "The stage-2 stadium bar stands"), so a young croc can never walk into it.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const PLAY_FRAMES := 240
const BREAK_FRAMES := 900
const STADIUM_STAGE := 2  # the first stage whose city holds the stadium (D-271)
const FLEE_FRAMES := 240
## Director playtest (2026-10-19): "stadium audience shouldnt disappear so suddenly, let us kill
## them". This long after the panic at least half the fans are still in view, on their way out.
const VISIBLE_FRAMES := 120


static func run(tree: SceneTree, check: Callable) -> void:
	var rampage := Rampage.new()
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	stats["size"] = float(STADIUM_STAGE)  # the run's city and arena are the stage's (for_stats)
	var layout := CityGrowth.layout(Content.tuning(), STADIUM_STAGE, Seeds.make("city", 0))
	rampage.setup(species, stats, layout, 0)
	tree.root.add_child(rampage)
	await tree.process_frame
	var game: StadiumMatch = GuiInput.find_script(rampage, StadiumMatch)
	var start := game.on_pitch() if game != null else 0
	var crowd: StadiumCrowd = GuiInput.find_script(rampage, StadiumCrowd)
	var seated := crowd.in_stands() if crowd != null else 0
	check.call(
		crowd != null and seated >= 500 and crowd.running() == 0,
		"the stands are full: %d fans seated to watch" % seated
	)
	for _i: int in PLAY_FRAMES:
		await tree.physics_frame
	check.call(
		game != null and start >= 20 and not game.fleeing and game.kicks > 0,
		(
			(
				"a %s match plays in the stadium: %d players, the ball kicked %d times"
				% [game.sport["id"], start, game.kicks]
			)
			if game != null
			else "no match in the stadium"
		)
	)
	if game == null:
		rampage.queue_free()
		return
	# Into the stadium: the kaiju starts at its kerb on the bay's side and autoplay takes it to the nearest
	# standing building, the stadium.
	var sim := rampage.sim
	var stadium: RampageSim.Building = null
	for b: RampageSim.Building in sim.buildings:
		if b.landmark == str(Content.sports()["pitch"]["landmark"]):
			stadium = b
	var whole := stadium.frame.alive_count
	sim.kaiju_pos = Vector2(stadium.x, stadium.z + stadium.d * 0.5 + 1.0)
	rampage.set_autoplay(true)
	var frames := 0
	while frames < BREAK_FRAMES and not game.fleeing:
		await tree.physics_frame
		frames += 1
	var broke_at := whole - stadium.frame.alive_count
	check.call(
		game.fleeing and broke_at > 0 and game.on_pitch() + game.killed == start,
		(
			"its first broken chunk sends every player running (frame %d, %d chunks)"
			% [frames, broke_at]
		)
	)
	await tree.physics_frame
	check.call(
		crowd != null and crowd.fleeing and crowd.running() > seated / 2,
		(
			"and the crowd with them: %d fans up and running"
			% (crowd.running() if crowd != null else 0)
		)
	)
	var view: CityView = GuiInput.find_script(rampage, CityView)
	var falls := {"burst": 0, "over": 0}
	for i: int in FLEE_FRAMES:
		await tree.physics_frame
		_watch_falls(view, stadium, falls)
		if i == VISIBLE_FRAMES and crowd != null:
			_check_crowd_kill(check, rampage, crowd, seated)
	check.call(
		falls["burst"] > 0 and falls["over"] == 0,
		(
			"its sections burst in place: %d burst, %d swung over the pitch"
			% [falls["burst"], falls["over"]]
		)
	)
	check.call(
		game.escaped > 0 and game.on_pitch() < start,
		(
			"the players flee the pitch: %d out through the tunnels, %d crushed, %d left"
			% [game.escaped, game.killed, game.on_pitch()]
		)
	)
	check.call(
		crowd != null and crowd.escaped > 0 and crowd.in_stands() < seated,
		(
			"fans stream out of the exits: %d out, %d gone with the fallen seats, %d crushed"
			% ([crowd.escaped, crowd.fallen, crowd.killed] if crowd != null else [0, 0, 0])
		)
	)
	rampage.queue_free()
	await tree.process_frame


## The fans stay in view while they run, and the kaiju can kill them where they run: a blow on
## a running fan's spot (not its seat) kills it, and it counts as a civilian crushed.
static func _check_crowd_kill(
	check: Callable, rampage: Rampage, crowd: StadiumCrowd, seated: int
) -> void:
	check.call(
		crowd.in_stands() * 2 >= seated,
		(
			"fans stay in view on their way out: %d of %d in the stands %.0f s after the panic"
			% [crowd.in_stands(), seated, VISIBLE_FRAMES / 60.0]
		)
	)
	var street: StreetLife = GuiInput.find_script(rampage, StreetLife)
	var view: CityView = GuiInput.find_script(rampage, CityView)
	var target: StadiumCrowd.Fan = null
	for fan: StadiumCrowd.Fan in crowd.fans:
		if crowd.running_at(fan).distance_to(fan.pos) > 1.0:
			target = fan
			break
	var before := street.civilians_killed()
	var dead := crowd.killed
	if target != null:
		view.crush(crowd.running_at(target), 0.3)
	(
		check
		. call(
			(
				target != null
				and target.is_dead()
				and crowd.killed > dead
				and street.civilians_killed() > before
			),
			(
				"a blow on a running fan kills it there and counts it: %d fans killed, civilians %d -> %d"
				% [crowd.killed - dead, before, street.civilians_killed()]
			)
		)
	)
	_check_stray_fan(check, street, view, crowd)


## A stray tank shell (CityView.crush by_army) on a running fan kills it too, but the army did
## it: it counts in StreetLife.toll.killed, not as the kaiju's civilian kill (comments #18).
static func _check_stray_fan(
	check: Callable, street: StreetLife, view: CityView, crowd: StadiumCrowd
) -> void:
	var target: StadiumCrowd.Fan = null
	for fan: StadiumCrowd.Fan in crowd.fans:
		if not fan.is_dead() and crowd.running_at(fan).distance_to(fan.pos) > 1.0:
			target = fan
			break
	var before := street.civilians_killed()
	var army := street.toll.killed
	if target != null:
		view.crush(crowd.running_at(target), 0.3, false, true)
	check.call(
		(
			target != null
			and target.is_dead()
			and street.toll.killed > army
			and street.civilians_killed() == before
		),
		(
			"a stray shell on a fan is the army's kill: army %d -> %d, kaiju's civilians %d -> %d"
			% [army, street.toll.killed, before, street.civilians_killed()]
		)
	)


## Each falling piece once: a LandmarkBurst, or (over) a stadium section toppling toward its
## middle, over the pitch.
static func _watch_falls(view: CityView, stadium: RampageSim.Building, seen: Dictionary) -> void:
	var falling: Dictionary = view.get("_falling")
	for id: int in falling:
		if seen.has(id):
			continue
		seen[id] = true
		var f: Dictionary = falling[id]
		var node: Node3D = f["node"]
		if node is LandmarkBurst:
			seen["burst"] += 1
		elif str(f["kind"]) == "topple" and node.has_meta("pivot"):
			var pivot: Vector3 = node.get_meta("pivot")
			var dir: Vector2 = f["dir"]
			var middle := Vector2(stadium.x - pivot.x, stadium.z - pivot.z)
			var inside := absf(middle.x) < stadium.w * 0.5 and absf(middle.y) < stadium.d * 0.5
			seen["over"] += 1 if inside and dir.dot(middle) > 0.0 else 0
