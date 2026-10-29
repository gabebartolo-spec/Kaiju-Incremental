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
## Steps played before the registry check drops its sim (the rings exist from construction, a few
## steps add the parts a rampage makes as it goes).
const REGISTRY_STEPS := 60

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
	for species_id: String in ["reptilian"]:
		_sim_is_freed(species_id)
	_registry_frees_a_dropped_sim()
	await _game_frees_its_rampage()


func _sim_is_freed(species_id: String) -> void:
	var sim: RampageSim = _make.call(species_id, {}, 0)
	_autoplay.call(sim, STEPS)
	var ref: WeakRef = weakref(sim)
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


## Every RampageSim registers as it is built, so the run's exit can cut the rings of one nobody
## disposed (SimTeardown.cut_all, QuitGame.release_sims_at_exit: a test or capture that drops a sim
## no longer leaks it at the exit, debt row 2). The check cuts a registry of its own, never the
## suite's, so no sim the suite still holds is touched.
func _registry_frees_a_dropped_sim() -> void:
	var before := SimTeardown.alive()
	var sim: RampageSim = _make.call("reptilian", {}, 0)
	_autoplay.call(sim, REGISTRY_STEPS)
	_check.call(SimTeardown.alive() == before + 1, "a new RampageSim registers itself")
	var mine: Array[WeakRef] = [weakref(sim)]
	sim = null
	_check.call(mine[0].get_ref() != null, "the dropped sim lives on (the registry holds no count)")
	_check.call(SimTeardown.cut_built(mine) == 1, "the registry cuts the one sim still alive")
	_check.call(mine.is_empty(), "the registry is empty once it is cut")
	_check.call(
		SimTeardown.alive() == before, "a sim cut from the registry is freed, so it is not alive"
	)


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
	var ref: WeakRef = weakref(rampage.sim)
	_check.call(ref.get_ref() != null, "the game's rampage has a sim to free")
	rampage.queue_free()
	for i: int in 2:
		await _runner.process_frame
	_check.call(ref.get_ref() == null, "leaving a Rampage frees its sim")
