extends RefCounted
## A dropped rampage is freed (D-179, the pacing run's memory leak). The sim and its parts point at
## each other, and Godot never frees a ring of reference-counted objects, so every RampageSim a
## tool or the game dropped stayed in memory for good (about 240 MB a rampage in tools/pacing.gd).
## RampageSim.dispose() (SimTeardown) breaks the rings. Per species, after a played rampage:
## without dispose() the dropped sim is still alive (the check has teeth: the rings are real), and
## after it the sim is freed. In the game, leaving a Rampage frees its sim (Rampage._exit_tree
## calls the same dispose).
## Seeded and clock-free: the scripted player of the sim suites, fixed steps.

## Steps the scripted player plays before the sim is dropped: tanks, helicopters, carving and falls
## are all running by then.
const STEPS := 450
const FRAMES := 20

var _runner: SceneTree
var _check: Callable
var _make: Callable
var _autoplay: Callable


## runner: the suite (its root hosts the Rampage); make(species, levels, run_index) -> RampageSim;
## autoplay(sim, steps) plays it.
func _init(runner: SceneTree, check: Callable, make: Callable, autoplay: Callable) -> void:
	_runner = runner
	_check = check
	_make = make
	_autoplay = autoplay


func run() -> void:
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		_sim_is_freed(species_id)
	await _game_frees_its_rampage()


func _sim_is_freed(species_id: String) -> void:
	var sim: RampageSim = _make.call(species_id, {}, 0)
	_autoplay.call(sim, STEPS)
	var ref := weakref(sim)
	sim = null
	var kept: RampageSim = ref.get_ref()
	_check.call(
		kept != null,
		"%s: a dropped sim lives on while its parts point back (the leak)" % species_id
	)
	if kept == null:
		return
	kept.dispose()
	kept = null
	_check.call(ref.get_ref() == null, "%s: the sim is freed once dispose has run" % species_id)


## A Rampage as the game makes one (Main._start_rampage), played a few frames, then left.
func _game_frees_its_rampage() -> void:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, 0)
	_runner.root.add_child(rampage)
	for i: int in FRAMES:
		await _runner.physics_frame
	var ref := weakref(rampage.sim)
	_check.call(ref.get_ref() != null, "the game's rampage has a sim to free")
	rampage.queue_free()
	for i: int in 2:
		await _runner.process_frame
	_check.call(ref.get_ref() == null, "leaving a Rampage frees its sim")
