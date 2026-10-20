extends SceneTree
## Where a stomp's ring lands against the body root, each foot and the tail tip, for the young
## reptilian: prints one line per stomp. Headless is fine (no rendering needed).
##
##   godot --path . --headless --script tools/capture/probe_stomp_ring.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	var kaiju: KaijuModel = rampage._kaiju
	var seen: Array[int] = [0]  # an array: a lambda copies plain ints
	var feet := {}
	kaiju.foot_planted.connect(
		func(side: String, _s: float, at: Vector3) -> void:
			feet[side] = at
			if rampage.stomp_ring_at.size() > seen[0]:
				seen[0] = rampage.stomp_ring_at.size()
				var ring := rampage.stomp_ring_at[-1]
				var gait: ClipGait = kaiju._rig.gait
				var tip: Vector3 = kaiju._rig.tail_world(gait._tail_tip)
				var rt: Vector3 = rampage._kaiju_at
				print(
					"stomp %d: ring-to-foot %.2f  ring-to-root %.2f  ring-to-tailtip %.2f  (old ring was at root: root-to-foot %.2f, root-to-tailtip %.2f, root-to-other-foot %.2f)"
					% [
						seen[0],
						ring.distance_to(at),
						ring.distance_to(rt),
						ring.distance_to(Vector3(tip.x, ring.y, tip.z)),
						rt.distance_to(at),
						rt.distance_to(Vector3(tip.x, rt.y, tip.z)),
						_other(feet, side, rt),
					]
				)
	)
	for _i: int in 60 * 25:
		await process_frame
	print("stomps landed on a foot: %d" % seen[0])
	quit()


func _other(feet: Dictionary, side: String, root_at: Vector3) -> float:
	for k: String in feet:
		if k != side:
			var f: Vector3 = feet[k]
			return root_at.distance_to(f)
	return -1.0
