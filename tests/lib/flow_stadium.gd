extends RefCounted
## D-078 for the flow suite: a match plays in the stadium (one sport of four, players of two
## kits and a ball kicked about), and the moment the stadium loses its first chunk every player
## runs for the tunnels; once out (or crushed) they are gone from the pitch. The stands are full
## of seated fans (director 2026-10-18) who stand and stream out of the exits with the players,
## and every section it sheds bursts where it stands, never swinging over the pitch.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const PLAY_FRAMES := 240
const BREAK_FRAMES := 900
const FLEE_FRAMES := 240


static func run(tree: SceneTree, check: Callable) -> void:
	var rampage := Rampage.new()
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
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
	# Into the stadium: the kaiju starts at its south kerb and autoplay takes it to the nearest
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
	for _i: int in FLEE_FRAMES:
		await tree.physics_frame
		_watch_falls(view, stadium, falls)
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
