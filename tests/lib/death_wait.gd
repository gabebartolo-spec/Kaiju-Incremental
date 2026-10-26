extends RefCounted
## A death no longer ends the run on the frame it happens: his overload plays first (stagger,
## stone, shatter; DeathOverload, director 2026-10-26), and the sim's run_over comes once the last
## shard is down. Flow suites that end a run wait here instead of a fixed number of frames.

## Frames a death may take at 60 fps (about 6 s in data, with room).
const FRAMES := 600


## Waits (bounded) for `sim` to end.
static func until_over(tree: SceneTree, sim: RampageSim) -> void:
	for _i: int in FRAMES:
		if sim.over:
			return
		await tree.process_frame


## End Rampage's YES was just clicked: he dies first (D-265), no end beat yet; then waits for the
## run to end and checks every shard was down by then.
static func end_rampage_dies(
	tree: SceneTree, check: Callable, rampage: Rampage, hud: RampageHud
) -> void:
	var sim := rampage.sim
	check.call(
		sim.death.active() and not sim.over and not hud.beat_running(),
		"End Rampage is his death: the overload plays before the end beat (D-265)"
	)
	await until_over(tree, sim)
	check.call(
		sim.death.shards.all(func(s: DeathOverload.Shard) -> bool: return s.landed),
		"the run ends once every shard is down"
	)
