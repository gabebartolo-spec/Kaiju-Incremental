extends SceneTree
## Captures every power's VFX in a real, autoplayed rampage for review: each species fires its
## signature once (stills along the way), and the upgraded reptilian is kept going long enough
## to show cracking stomps, glancing shells, healing motes and the ready pulse. Pair with
## --write-movie for the clip. Needs a window (no --headless) and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/powers.avi --script tools/capture/capture_powers.gd -- --out=<dir>
## --species=reptilian: only that species; --signature-only: skip the upgrade effects after it.
## --side: watch from the kaiju's right side, level with its chest, instead of the game camera.
## --young: the same build before its first evolution (the young stage, not the Behemoth).

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 90
const SIDE_DISTANCE := 26.0
const SIDE_HEIGHT := 9.0
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

var _species: Array[String] = ["reptilian", "insectoid", "cephalopod"]
var _signature_only := false
var _side := false
var _young := false


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args(
		{"out": _out, "species": "", "signature-only": false, "side": false, "young": false}
	)
	_out = str(a["out"])
	if str(a["species"]) != "":
		_species = [str(a["species"])]
	_signature_only = a["signature-only"]
	_side = a["side"]
	_young = a["young"]
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for species_id: String in _species:
		await _species_shots(species_id)
	quit()


func _species_shots(species_id: String) -> void:
	var shown: Dictionary = SHOWN[species_id]
	var levels := shown.duplicate()
	if _young:
		levels.erase("evolve1")
	var rampage := Kit.rampage(species_id, Kit.stats(species_id, levels), 1)
	rampage.set_autoplay(true)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	await _frames(SETTLE)
	if _side:  # side-on: the breath runs across the frame instead of away from the camera
		var cam := Camera3D.new()
		rampage.add_child(cam)
		var at := Vector3(rampage.sim.kaiju_pos.x, 0.0, rampage.sim.kaiju_pos.y)
		var right := Vector3(-rampage.sim.facing.y, 0.0, rampage.sim.facing.x)
		cam.position = at + right * SIDE_DISTANCE + Vector3(0, SIDE_HEIGHT, 0)
		cam.look_at(
			at + Vector3(rampage.sim.facing.x, 0.0, rampage.sim.facing.y) * 5.0 + Vector3.UP * 3.0
		)
		cam.current = true
	rampage.autoplay_signature = true
	await physics_frame
	await physics_frame
	rampage.autoplay_signature = false
	var waited := 0
	for at: int in AFTER:
		await _frames(at - waited)
		waited = at
		_shot("%s_signature_%02d" % [species_id, at])
	if species_id == "reptilian" and not _signature_only:
		await _upgrade_shots(rampage)
	elif _signature_only:
		await _frames(SETTLE)  # a beat after, so the clip shows what the power leaves behind
	rampage.queue_free()
	await _frames(2)


## Stills a few frames after each upgrade effect first plays; the signature is left to recharge
## on its own (the HUD counts down for real), so the ready pulse comes when it is ready.
func _upgrade_shots(rampage: Rampage) -> void:
	var seen: Array[String] = []
	for _i: int in UPGRADES_FRAMES:
		await physics_frame
		for k: String in ["cracks", "ready", "deflect", "regen"]:
			if not seen.has(k) and rampage.ability_fx.played.has(k):
				seen.append(k)
				await _frames(30 if k == "regen" else 3)
				_shot("reptilian_upgrade_" + k)
		if seen.size() == 4:
			return


func _shot(shot_name: String) -> void:
	Kit.still(self, _out, shot_name)


func _frames(n: int) -> void:
	await Kit.frames(self, n)
