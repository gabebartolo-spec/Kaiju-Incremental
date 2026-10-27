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
	FlowSettingsRows.run(check, menu)
	var was_full: bool = PlayerSettings.fullscreen
	await GuiInput.click(t, GuiInput.button(menu, "< ON >" if was_full else "< OFF >"))
	check.call(PlayerSettings.fullscreen != was_full, "clicking the fullscreen switch flips it")
	PlayerSettings.set_fullscreen(was_full)
	await GuiInput.click(t, GuiInput.button(menu, "< 100% >"))
	check.call(
		(
			is_equal_approx(PlayerSettings.ui_scale, 1.15)
			and is_equal_approx(t.root.content_scale_factor, 1.15)
		),
		"clicking UI scale steps it to 115%% and scales the UI (%s)" % t.root.content_scale_factor
	)
	await GuiInput.drag(t, menu.effects, 0.1, 0.7)
	var sfx_db := AudioServer.get_bus_volume_db(PlayerSettings.bus("SFX"))
	check.call(
		(
			is_equal_approx(PlayerSettings.sfx_volume, 0.7)
			and is_equal_approx(sfx_db, linear_to_db(0.7))
		),
		(
			"dragging Sound effects to 70%% sets the SFX bus (%s, %.1f dB)"
			% [PlayerSettings.sfx_volume, sfx_db]
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
			and is_equal_approx(Num.f(cfg.get_value("display", "ui_scale")), 1.15)
		),
		"the UI scale is saved to settings.cfg"
	)
	PlayerSettings.sfx_volume = -1.0
	PlayerSettings.load_saved(false)
	check.call(
		is_equal_approx(PlayerSettings.sfx_volume, 0.7),
		"the sound-effects volume comes back after a reload (%s)" % PlayerSettings.sfx_volume
	)
	PlayerSettings.set_sfx_volume(Num.f(Content.section("sfx")["default_volume"]))
	PlayerSettings.next_ui_scale()
	PlayerSettings.next_ui_scale()
	check.call(PlayerSettings.ui_scale == 1.0, "UI scale wraps back to 100%")
	main.queue_free()
	for _i: int in 2:
		await t.process_frame
