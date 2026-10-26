extends SceneTree
## Logs every Decal and glowing mark that appears in the reptilian signature capture sequence
## (capture_powers.gd: 90 settle frames, then the signature): frame, kind, position and glow, and
## its distance from the kaiju; and every node new on the signature's frames. Headless:
##   godot --headless --path . --script tools/capture/probe_decals.gd

const SETTLE := 90
const FRAMES := 140
const SHOWN := {
	"claws": 2,
	"hide": 1,
	"scales": 2,
	"evolve1": 1,
	"rage": 1,
	"regen": 2,
	"sig_power": 2,
	"sig_recharge": 4,
}


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), SHOWN)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	var seen := {}
	var before := {}
	for frame: int in FRAMES:
		if frame == SETTLE - 1:
			for n: Node in rampage.find_children("*", "Node3D", true, false):
				before[n.get_instance_id()] = true
		if frame == SETTLE + 3:
			var feet3 := Vector3(rampage.sim.kaiju_pos.x, 0, rampage.sim.kaiju_pos.y)
			for n: Node in rampage.find_children("*", "Node3D", true, false):
				if before.has(n.get_instance_id()):
					continue
				var n3: Node3D = n
				var off := n3.global_position - feet3
				print(
					"new ",
					n.get_class(),
					" ",
					n.name,
					" parent ",
					n.get_parent().name,
					" off ",
					off
				)
		if frame == SETTLE:
			rampage.autoplay_signature = true
		if frame == SETTLE + 2:
			rampage.autoplay_signature = false
		await process_frame
		for node: Node in rampage.find_children("*", "Decal", true, false):
			if seen.has(node.get_instance_id()):
				continue
			seen[node.get_instance_id()] = true
			var d: Decal = node
			var feet := Vector3(rampage.sim.kaiju_pos.x, 0, rampage.sim.kaiju_pos.y)
			print(
				(
					"frame %d decal size %.1f at %s glow %.2f mix %.2f from kaiju %s played %s"
					% [
						frame,
						d.size.x,
						d.global_position,
						d.emission_energy,
						d.albedo_mix,
						d.global_position - feet,
						rampage.ability_fx.played
					]
				)
			)
	quit()
