extends SceneTree
## Captures the rampage HUD alone and measures how much of the screen it covers: a mid-run still
## (the city meter part-filled, the controls card gone unless --first-run), the same frame with
## the HUD hidden (their pixel difference over the noise of two identical frames is the HUD's
## share of the screen), and the last-10-seconds still with the red timer. Local GPU only:
##   godot --path . --windowed --resolution 3840x2160 --fixed-fps 60 --script \
##     tools/capture/capture_hud.gd -- --out=<dir> [--first-run] [--ui-scale=1.25]
## Prints "HUD share <percent>" (pixels that differ by more than DIFF_MIN in any channel,
## measured at half resolution).

const MAIN_SCENE := "res://scenes/main.tscn"
const SETTLE := 12
const FIGHT_FRAMES := 45
const RISE_STEPS := 1200
const METER_SHARE := 0.4
const DIFF_MIN := 24
const LAST_SECONDS := 8.5
## Frames the last-seconds timer runs before its still (the pulse has settled).
const LAST_FRAMES := 20

var _out := "user://hud"
var _first_run := false
var _ui_scale := 1.0
var _main: Node


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--first-run":
			_first_run = true
		elif arg.begins_with("--ui-scale="):
			_ui_scale = float(arg.substr(11))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Engine.max_physics_steps_per_frame = 1
	for _i: int in PlayerSettings.UI_SCALES.size():
		if not is_equal_approx(PlayerSettings.ui_scale, _ui_scale):
			PlayerSettings.next_ui_scale()
	PlayerSettings.controls_seen = not _first_run
	var save := SaveFile.new_save("reptilian")
	save["runs"] = 3
	SaveFile.save_game(save)
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(SETTLE)
	var title := _screen()
	_press(title, "CONTINUE")
	await _frames(SETTLE)
	var tree := _screen() as UpgradeScreen
	tree.start_pressed.emit()
	await _frames(2)
	var rampage := _screen() as Rampage
	await rampage.wait_loaded()
	rampage.set_autoplay(true)
	var steps := 0
	while rampage.sim.emerge.active and steps < RISE_STEPS:
		rampage.sim.emerge.step(rampage.sim, 1.0 / 60.0)
		steps += 1
	rampage.sim.chunks_destroyed = roundi(rampage.sim.chunks_total * METER_SHARE)
	await _frames(FIGHT_FRAMES)
	var hud: RampageHud = rampage.find_children("*", "RampageHud", true, false)[0]
	if not _first_run:
		hud.dismiss_controls()
	rampage.sim.hp = rampage.sim.max_hp
	await _frames(SETTLE * 4)
	# The same frame twice with the HUD on, then off: the world holds still (paused).
	paused = true
	await _frames(2)
	root.get_texture().get_image().save_png(_out.path_join("04_rampage.png"))
	var with_hud := _grab()
	var widgets: Control = hud.get("_widgets")
	widgets.visible = false
	await _frames(2)
	var without := _grab()
	await _frames(2)
	var again := _grab()
	widgets.visible = true
	paused = false
	var noise := _differing(without, again)
	var share := _differing(with_hud, without)
	print("HUD share ", snappedf(100.0 * maxf(0.0, share - noise) / (without.get_width() * without.get_height()), 0.001), " percent (diff ", share, " noise ", noise, " of ", without.get_width() * without.get_height(), ")")
	rampage.sim.time_left = LAST_SECONDS
	await _frames(LAST_FRAMES)
	root.get_texture().get_image().save_png(_out.path_join("04d_last_seconds.png"))
	SaveFile.delete_save()
	quit()


## The screen at half size (nearest), so the comparison stays quick.
func _grab() -> Image:
	var image := root.get_texture().get_image()
	image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_NEAREST)
	image.convert(Image.FORMAT_RGBA8)
	return image


## How many pixels differ between two frames by more than DIFF_MIN in any channel.
func _differing(a: Image, b: Image) -> int:
	var da := a.get_data()
	var db := b.get_data()
	var count := 0
	for i: int in range(0, da.size(), 4):
		if (
			absi(da[i] - db[i]) > DIFF_MIN
			or absi(da[i + 1] - db[i + 1]) > DIFF_MIN
			or absi(da[i + 2] - db[i + 2]) > DIFF_MIN
		):
			count += 1
	return count


func _screen() -> Node:
	return _main.call("screen")


func _press(node: Node, prefix: String) -> void:
	for found: Node in node.find_children("*", "Button", true, false):
		var b: Button = found
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			b.pressed.emit()
			return
	push_error("capture_hud: no button %s" % prefix)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame
