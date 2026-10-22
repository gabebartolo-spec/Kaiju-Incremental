extends SceneTree
## Where a sim step's time goes, per growth step: seeded scripted rampages (tools/sim_probe.gd's
## player, the one tools/pacing.gd uses) are played plain, then again with a stopwatch round each
## sub-system (tools/sim_timed.gd). Prints, per growth step, ms per step plain and timed, whether
## the fingerprints of the two agree (the stopwatch changes nothing) and the spans by exclusive
## time (ms per step, share, calls per step). Headless, seeded; a probe, nothing in sim/ reads a
## clock.
##   godot --headless --path . --script tools/sim_profile.gd -- [--runs=3] [--tiers=1,2,3,4]
##     [--species=reptilian] [--top=16] [--gd] [--drill] [--micro]
##     (--gd: the GDScript path, VoxelSupport.use_native off; --drill: time the tanks' convoy down
##     to its road graph, search, posts and spacing, and the body's volume; --micro: instead of a
##     profile, the plain cost of one call of the hot helpers, a stopwatch-free check of the spans)

const Probe := preload("res://tools/sim_probe.gd")
const Prof := preload("res://tools/sim_prof.gd")
const Timed := preload("res://tools/sim_timed.gd")
## --micro: steps played before the helpers are timed (tanks are in), calls timed per helper.
const MICRO_WARM := 300
const MICRO_CALLS := 20000


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads and the native extension are up after the first frame
	var args := OS.get_cmdline_user_args()
	var runs := Probe.option(args, "runs", "3").to_int()
	var species := Probe.option(args, "species", "reptilian")
	var top := Probe.option(args, "top", "16").to_int()
	Prof.drill = "--drill" in args
	if "--gd" in args:
		VoxelSupport.use_native = false
	print(
		(
			"native path: %s, species %s, %d runs per growth step"
			% [VoxelSupport.native() != null, species, runs]
		)
	)
	for tier: int in Probe.tiers_from(args):
		if "--micro" in args:
			_micro(tier, species)
		else:
			_tier(tier, species, runs, top)
	quit()


func _tier(tier: int, species: String, runs: int, top: int) -> void:
	Probe.layout_for(tier)  # the city is made once, outside both timings
	var plain_us := 0
	var plain_steps := 0
	var plain_digests := ""
	for run: int in runs:
		var sim := Probe.new_sim(tier, species, run, Probe.plain)
		var from := Time.get_ticks_usec()
		var steps := Probe.play(sim)
		plain_us += Time.get_ticks_usec() - from
		plain_steps += steps
		plain_digests += Probe.digest(sim, steps)
	Prof.reset()
	var timed_us := 0
	var timed_steps := 0
	var timed_digests := ""
	for run: int in runs:
		var sim := Probe.new_sim(tier, species, run, Timed.make)
		var from := Time.get_ticks_usec()
		var steps := Probe.play(sim)
		timed_us += Time.get_ticks_usec() - from
		timed_steps += steps
		timed_digests += Probe.digest(sim, steps)
	print(
		(
			"== growth step %d: %d steps; plain %.3f ms/step, timed %.3f ms/step; fingerprints agree: %s"
			% [
				tier,
				plain_steps,
				plain_us / 1000.0 / plain_steps,
				timed_us / 1000.0 / timed_steps,
				plain_digests == timed_digests,
			]
		)
	)
	_table(timed_us, timed_steps, top)


## The spans by exclusive time; what no span covers (the player's own loop, the sim's untimed code)
## is the last row.
func _table(total_us: int, steps: int, top: int) -> void:
	var labels: Array = Prof.exclusive.keys()
	labels.sort_custom(
		func(a: String, b: String) -> bool: return Prof.exclusive[a] > Prof.exclusive[b]
	)
	var covered := 0
	print("  %-28s %9s %6s %9s %8s" % ["span", "excl ms/st", "share", "incl ms/st", "calls/st"])
	for i: int in labels.size():
		var label: String = labels[i]
		covered += Num.i(Prof.exclusive[label])
		if i < top:
			print(
				(
					"  %-28s %9.4f %5.1f%% %9.4f %8.2f"
					% [
						label,
						Num.i(Prof.exclusive[label]) / 1000.0 / steps,
						100.0 * Num.i(Prof.exclusive[label]) / total_us,
						Num.i(Prof.inclusive[label]) / 1000.0 / steps,
						Num.f(Prof.calls[label]) / steps,
					]
				)
			)
	var rest := total_us - covered
	print(
		(
			"  %-28s %9.4f %5.1f%%"
			% ["(no span: player loop, glue)", rest / 1000.0 / steps, 100.0 * rest / total_us]
		)
	)


## The plain cost of one call of the helpers a step calls most, µs, with no stopwatch round them:
## the tanks are in and the kaiju has walked a while (MICRO_WARM steps).
func _micro(tier: int, species: String) -> void:
	var sim := Probe.new_sim(tier, species, 0, Probe.plain)
	Probe.play(sim, MICRO_WARM)
	var convoy := sim.army_units.convoy
	var at := sim.kaiju_pos + Vector2(12.0, 7.0)
	var to := at + Vector2(8.0, 0.0)
	var heading := sim.body.heading
	var reach := sim.body.length()
	print(
		(
			"== growth step %d, %d tanks after %d steps (µs per call)"
			% [tier, sim.tanks.size(), MICRO_WARM]
		)
	)
	var empty := _bench(func() -> void: pass)
	print("  %-26s %8.2f" % ["(empty call)", empty])
	var calls := {
		"posts.body": func() -> void: convoy.posts.body(),
		"posts.to_body": func() -> void: convoy.posts.to_body(at),
		"posts.near_body": func() -> void: convoy.posts.near_body(at, to),
		"graph.drivable": func() -> void: convoy.graph.drivable(at, Vector2.RIGHT),
		"body.inside": func() -> void: sim.body.inside(sim.kaiju_pos, heading),
		"powers.blocked": func() -> void: sim.powers.blocked(sim.kaiju_pos, reach),
		"sim.nearest_standing": func() -> void: sim.nearest_standing(sim.kaiju_pos),
	}
	for label: String in calls:
		var each: Callable = calls[label]
		print("  %-26s %8.2f" % [label, _bench(each) - empty])


func _bench(call: Callable) -> float:
	var from := Time.get_ticks_usec()
	for i: int in MICRO_CALLS:
		call.call()
	return float(Time.get_ticks_usec() - from) / MICRO_CALLS
