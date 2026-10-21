extends SceneTree
## Stills of the upgrade cues on a clear street at the gameplay camera (the autoplayed run in
## capture_powers.gd often catches them inside fire smoke): plain, Regeneration healing, an
## Armoured Scales glance and the signature-ready pulse. Needs a window and the no-focus
## override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_cues.gd -- <dir>/cue_

var _out := ""


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_out + name + ".png")


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var levels := {"evolve1": 1, "hide": 1, "regen": 2, "scales": 2}
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var r := Rampage.new()
	r.setup(species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1)
	r.autoplay_signature = false
	root.add_child(r)
	for _i: int in 40:
		await process_frame
	_shot("plain")
	r.sim.hp -= 40.0
	for _i: int in 25:
		await process_frame
	_shot("regen")
	r.sim.hp = r.sim.max_hp
	for _i: int in 10:
		await process_frame
	var at := Vector3(r.sim.kaiju_pos.x, 4.0 * r.sim.body_scale(), r.sim.kaiju_pos.y)
	r.ability_fx.deflect(at + Vector3(0.8, 0, 0.8), Vector3(1, 0.5, 1))
	for _i: int in 3:
		await process_frame
	_shot("deflect")
	for _i: int in 30:
		await process_frame
	var feet := Vector3(r.sim.kaiju_pos.x, 0, r.sim.kaiju_pos.y)
	r.ability_fx.ready_pulse(feet, feet + Vector3(0, 6.0 * r.sim.body_scale(), 0))
	for _i: int in 6:
		await process_frame
	_shot("ready")
	quit()
