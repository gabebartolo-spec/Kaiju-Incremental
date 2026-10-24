extends SceneTree
## Where each stomp's ring (the delivering foot) lands against the sim's kaiju_pos and heading, per
## growth step: prints ahead and across (left is positive), in body-scale-1 units, and how far the ring is from the sim's nearer foot point (BodyContact.stomp_foot), taken when the ring lands. Headless.
##
##   godot --path . --headless --script tools/capture/probe_stomp_foot.gd -- <size 1..3> <walk 0|1>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var size := int(args[0]) if args.size() > 0 else 1
	var walk := args.size() > 1 and args[1] == "1"
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	stats["size"] = float(size)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(walk)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	var seen := 0
	var kaiju: KaijuModel = rampage._kaiju
	for _i: int in 60 * 30:
		await process_frame
		if rampage.stomp_ring_at.size() > seen:
			seen = rampage.stomp_ring_at.size()
			var sim := rampage.sim
			var ring := rampage.stomp_ring_at[-1]
			var rel := Vector2(ring.x, ring.z) - sim.kaiju_pos
			var h := sim.body.heading
			var s := sim.body_scale()
			var ring2 := Vector2(ring.x, ring.z)
			var near := minf(
				ring2.distance_to(sim.body.stomp_foot(true)),
				ring2.distance_to(sim.body.stomp_foot(false))
			)
			print(
				(
					"size %d walk %s stomp %d: ahead %.2f across %.2f (units at scale 1), "
					+ "scale %.2f, ring to the sim's nearer foot point %.2f"
				)
				% [size, walk, seen, rel.dot(h) / s, rel.dot(h.orthogonal()) / s, s, near]
			)
	kaiju.queue_free()
	quit()
