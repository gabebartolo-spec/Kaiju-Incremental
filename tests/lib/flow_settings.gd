extends RefCounted
## FlowScreens' settings check (split out of flow_screens.gd to keep files small): from the title,
## the fullscreen toggle and the UI scale step by click and stick; the controls list covers keyboard
## and pad; Esc goes back. `main` is a fresh main scene; it is freed at the end.

const FlowLayout := preload("res://tests/lib/flow_layout.gd")
const FlowSettingsRows := preload("res://tests/lib/flow_settings_rows.gd")
const GuiInput := preload("res://tests/lib/gui_input.gd")


static func run(t: SceneTree, check: Callable, layout: FlowLayout, main: Node) -> void:
	var title: Node = main.call("screen")
	Sfx.ui_played.clear()
	await GuiInput.click(t, title.find_child("Gear", true, false) as Button)
	var menu := GuiInput.find_script(title, SettingsMenu) as SettingsMenu
	check.call(menu != null, "clicking the title gear opens the settings")
	check.call(Sfx.ui_played == ["ui_click"], "a menu button clicks: %s" % [Sfx.ui_played])
	if menu == null:
		main.queue_free()
		return
	await layout.fits_at_scales(menu, "settings")
	await FlowSettingsRows.run(t, check, menu)
	var was_full: bool = PlayerSettings.fullscreen
	var full_button := GuiInput.button(menu, "< ON >" if was_full else "< OFF >")
	check.call(full_button != null, "settings: the fullscreen switch is on the card")
	if full_button != null:
		await GuiInput.click(t, full_button)
	check.call(PlayerSettings.fullscreen != was_full, "clicking the fullscreen switch flips it")
	PlayerSettings.set_fullscreen(was_full)
	# D-385: the step is the game's own UI_SCALES, whatever they are.
	var scales := PlayerSettings.UI_SCALES
	var before := PlayerSettings.ui_scale
	var want := scales[(scales.find(before) + 1) % scales.size()]
	var step := GuiInput.button(menu, "< %d%%" % roundi(before * 100.0))
	check.call(step != null, "settings: the UI scale button is on the card")
	if step != null:
		await GuiInput.click(t, step)
	check.call(
		(
			want != before
			and is_equal_approx(PlayerSettings.ui_scale, want)
			and is_equal_approx(t.root.content_scale_factor, want)
		),
		(
			"clicking UI scale steps it %s -> %s and scales the UI (%s)"
			% [before, want, t.root.content_scale_factor]
		)
	)
	var was_sfx := PlayerSettings.sfx()
	await GuiInput.drag(t, menu.effects, 0.5, 0.1 if was_sfx > 0.5 else 0.9)
	var sfx := PlayerSettings.sfx_volume
	var sfx_db := AudioServer.get_bus_volume_db(PlayerSettings.bus("SFX"))
	check.call(
		(
			not is_equal_approx(sfx, was_sfx)
			and is_equal_approx(sfx, menu.effects.value / 100.0)
			and is_equal_approx(sfx_db, linear_to_db(sfx))
		),
		(
			"dragging Sound effects moves it (%s -> %s) and sets the SFX bus (%.1f dB)"
			% [was_sfx, sfx, sfx_db]
		)
	)
	await GuiInput.click(t, GuiInput.button(menu, "CONTROLS"))  # its own page (D-259)
	var texts: Array[String] = []
	for node: Node in menu.find_children("*", "Control", true, false):  # labels and buttons
		texts.append(str(node.get("text")))
	menu.page.close()
	check.call(
		texts.has("Ultimate") and texts.has("E") and texts.has("Y") and texts.has("Start"),
		"the controls list shows keyboard and pad"
	)
	await GuiInput.key(t, KEY_ESCAPE)
	check.call(not is_instance_valid(menu), "Esc closes the settings")
	var cfg := ConfigFile.new()
	check.call(
		(
			cfg.load(PlayerSettings.PATH) == OK
			and is_equal_approx(Num.f(cfg.get_value("display", "ui_scale")), want)
		),
		"the UI scale is saved to settings.cfg"
	)
	PlayerSettings.sfx_volume = -1.0
	PlayerSettings.load_saved(false)
	check.call(
		is_equal_approx(PlayerSettings.sfx_volume, sfx),
		"the sound-effects volume comes back after a reload (%s)" % PlayerSettings.sfx_volume
	)
	PlayerSettings.set_sfx_volume(Num.f(Content.section("sfx")["default_volume"]))
	var walked: Array[float] = []
	for _i: int in scales.size():
		PlayerSettings.next_ui_scale()
		walked.append(PlayerSettings.ui_scale)
	check.call(
		walked.back() == want and scales.all(func(s: float) -> bool: return walked.has(s)),
		"UI scale steps through every scale and wraps round (%s)" % [walked]
	)
	PlayerSettings.ui_scale = scales[scales.size() - 1]
	PlayerSettings.next_ui_scale()
	check.call(PlayerSettings.ui_scale == scales[0], "UI scale wraps from the last to the first")
	main.queue_free()
	for _i: int in 2:
		await t.process_frame
