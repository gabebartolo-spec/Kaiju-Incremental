extends SceneTree
## Records the kaiju zigzagging left and right in the real rampage (the flow test's city and seed)
## at the gameplay camera, for turning-with-weight before/after clips (director comments #16).
## After the rise from the river the stick swings hard right and left every --every seconds,
## pushing --ahead up the screen too so the zigzag stays off the arena's edge.
## Prints, per flip, how far the body travelled sideways to its heading (0 = no slide).
##
##   godot --path . --resolution 1280x720 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_turns.gd -- --species=reptilian --seconds=10 --every=1.6

var _species := "reptilian"
var _seconds := 10.0
var _every := 1.6
var _ahead := 0.4  # how much the stick also pushes up the screen, away from the arena's edge
var _since := -1.0
var _slide := 0.0
var _last := Vector2(INF, INF)


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--every="):
			_every = float(arg.substr(8))
		elif arg.begins_with("--ahead="):
			_ahead = float(arg.substr(8))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rampage := Rampage.new()
	var species := Content.species_def(_species)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	rampage.scripted = _input
	root.add_child(rampage)
	var frames := 0
	while frames < int(_seconds * 60.0) and not rampage.sim.over:
		await physics_frame
		frames += 1
	print("sideways travel against the heading over the zigzag: %.2f m" % _slide)
	quit()


## Right, left, right... once the kaiju stands on the bank; tracks the sideways slide.
func _input(sim: RampageSim) -> Dictionary:
	if sim.emerge.active:
		return {"move": Vector2.ZERO}
	if _since < 0.0:
		_since = 0.0
		print("the zigzag starts at frame %d" % Engine.get_physics_frames())
	if _last.x != INF:
		_slide += absf((sim.kaiju_pos - _last).dot(sim.body.heading.orthogonal()))
	_last = sim.kaiju_pos
	_since += 1.0 / 60.0
	var right := int(_since / _every) % 2 == 0
	return {"move": Vector2(1 if right else -1, -_ahead).normalized()}
