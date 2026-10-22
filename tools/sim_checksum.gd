extends SceneTree
## Proof that a sim speed-up changed nothing: for each growth step, N seeded scripted rampages
## (tools/sim_probe.gd's player) each end in a fingerprint of result(), chunks_destroyed and the
## kaiju's final state; the per-step and overall checksums must be identical before and after.
## Run it on a clean tree and on the change, with and without the native extension:
##   godot --headless --path . --script tools/sim_checksum.gd -- [--runs=10] [--tiers=1,2,3,4]
##     [--species=reptilian] [--gd]   (--gd: the GDScript path, VoxelSupport.use_native off)
## Prints "CHECKSUM <overall>" last; add --verbose for every run's line.

const Probe := preload("res://tools/sim_probe.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads and the native extension are up after the first frame
	var args := OS.get_cmdline_user_args()
	var runs := Probe.option(args, "runs", "10").to_int()
	var species := Probe.option(args, "species", "reptilian")
	var verbose := "--verbose" in args
	if "--gd" in args:
		VoxelSupport.use_native = false
	print("native path: %s" % (VoxelSupport.native() != null))
	var overall := ""
	var started := Time.get_ticks_msec()
	for tier: int in Probe.tiers_from(args):
		var lines := ""
		var total_steps := 0
		for run: int in runs:
			var sim := Probe.new_sim(tier, species, run, Probe.plain)
			var steps := Probe.play(sim)
			var fingerprint := Probe.digest(sim, steps)
			lines += fingerprint
			total_steps += steps
			if verbose:
				print(
					(
						"  tier %d run %d: %s steps %d (%s)"
						% [tier, run, fingerprint, steps, sim.end_reason]
					)
				)
		var tier_sum := lines.sha256_text().substr(0, 16)
		overall += tier_sum
		print("tier %d: %d runs, %d steps, checksum %s" % [tier, runs, total_steps, tier_sum])
	print("wall %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	print("CHECKSUM %s" % overall.sha256_text().substr(0, 16))
	quit()
