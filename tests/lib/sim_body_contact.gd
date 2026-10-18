extends RefCounted
## The sim suite's body-contact checks (playtest note 2), split out to keep the runner small:
## the young reptilian walks into the nearest building, turns inside it and walks out, and after
## every step no standing chunk sits inside its body volume. Includes the player-effect fixture
## "kaiju.contact": the same seeded walk with the body volume off leaves chunks inside the body
## (the model phased through them) and breaks fewer.

const DT := 1.0 / 30.0
## The scripted walk: forward into the building, a hard turn, then back out (steps).
const FORWARD_STEPS := 90
const TURN_STEPS := 30
const BACK_STEPS := 45

var _check: Callable
var _make: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim.
func _init(p_check: Callable, make: Callable) -> void:
	_check = p_check
	_make = make


func run() -> void:
	var on := _walk(true)
	var off := _walk(false)
	(
		_check
		. call(
			Num.i(off["worst"]) > 0,
			(
				"without the body volume the walk leaves chunks inside the body (%d at worst): it phases"
				% Num.i(off["worst"])
			)
		)
	)
	(
		_check
		. call(
			Num.i(on["worst"]) == 0 and Num.i(on["broken"]) > 0,
			(
				(
					"with it, no standing chunk is inside the body after any step (%d at worst, step %d);"
					+ " the body broke %d chunks"
				)
				% [Num.i(on["worst"]), Num.i(on["worst_step"]), Num.i(on["broken"])]
			)
		)
	)
	_check.call(
		Num.i(on["chunks"]) > Num.i(off["chunks"]),
		(
			"the body's own breaks add to the walk's damage (%d chunks vs %d without)"
			% [Num.i(on["chunks"]), Num.i(off["chunks"])]
		)
	)
	var again := _walk(true)
	_check.call(on == again, "the walk through a building replays identically")


## One seeded walk; with `body` off the volume is only measured (a probe), never applied.
func _walk(body: bool) -> Dictionary:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	var probe := sim.body
	if body:
		sim.body.use_species("reptilian")
	else:
		probe = BodyContact.new(sim, Content.section("contact"))
		probe.use_species("reptilian")
	var target := sim.nearest_standing(sim.kaiju_pos)
	var dir := (target - sim.kaiju_pos).normalized()
	var worst := 0
	var worst_step := -1
	for n: int in FORWARD_STEPS + TURN_STEPS + BACK_STEPS:
		var move := dir
		if n >= FORWARD_STEPS + TURN_STEPS:
			move = -dir
		elif n >= FORWARD_STEPS:
			move = dir.orthogonal()
		sim.step(DT, move, false)
		var count := 0
		var inside := probe.inside(sim.kaiju_pos, sim.body.heading)
		for index: int in inside:
			var cells: Dictionary = inside[index]
			count += cells.size()
		if count > worst:
			worst = count
			worst_step = n
	return {
		"worst": worst,
		"worst_step": worst_step,
		"broken": sim.body.broken,
		"chunks": sim.chunks_destroyed,
		"pos": sim.kaiju_pos,
	}
