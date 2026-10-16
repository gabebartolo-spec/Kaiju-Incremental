extends SceneTree
## Captures every power's VFX in a real, autoplayed rampage for review: each species fires its
## signature once (stills along the way), and the upgraded reptilian is kept going long enough
## to show cracking stomps, glancing shells, healing motes and the ready pulse. Pair with
## --write-movie for the clip. Needs a window (no --headless) and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/powers.avi --script tools/capture/capture_powers.gd -- --out=<dir>

const SETTLE := 90
const AFTER: Array[int] = [6, 14, 26, 40, 90]
const UPGRADES_FRAMES := 60 * 30
const SHOWN := {
	"reptilian":
	{
		"claws": 3,
		"hide": 1,
		"scales": 2,
		"evolve1": 1,
		"rage": 1,
		"regen": 2,
		"sig_power": 2,
		"sig_recharge": 4
	},
	"insectoid": {"claws": 1, "hide": 1, "rage": 1, "evolve1": 1, "sig_power": 2},
	"cephalopod": {"claws": 1, "hide": 1, "rage": 1, "evolve1": 1, "sig_power": 2},
}

var _out := "user://powers"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		await _species_shots(species_id)
	quit()


func _species_shots(species_id: String) -> void:
	var species := Content.species_def(species_id)
	var levels: Dictionary = SHOWN[species_id]
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	rampage.sim.ability_ready_in = 999.0
	await _frames(SETTLE)
	rampage.sim.ability_ready_in = 0.0
	var waited := 0
	for at: int in AFTER:
		await _frames(at - waited)
		waited = at
		_shot("%s_signature_%02d" % [species_id, at])
	rampage.sim.ability_ready_in = 999.0
	if species_id == "reptilian":
		await _upgrade_shots(rampage)
	rampage.queue_free()
	await _frames(2)


## Stills two frames after each upgrade effect first plays.
func _upgrade_shots(rampage: Rampage) -> void:
	rampage.sim.ability_ready_in = 3.0
	var seen: Array[String] = []
	for _i: int in UPGRADES_FRAMES:
		await physics_frame
		if rampage.sim.ability_ready_in <= 0.0:
			rampage.sim.ability_ready_in = 999.0
		for k: String in ["cracks", "ready", "deflect", "regen"]:
			if not seen.has(k) and rampage.ability_fx.played.has(k):
				seen.append(k)
				await _frames(30 if k == "regen" else 3)
				_shot("reptilian_upgrade_" + k)
		if seen.size() == 4:
			return


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame
