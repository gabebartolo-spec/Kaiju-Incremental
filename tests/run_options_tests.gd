extends "res://tests/lib/runner.gd"
## Options suite (director 2026-10-26, D-259): Settings > CONTROLS rebinds a key and a pad button
## by real presses (a conflict moves, Esc keeps the old one, RESET restores, settings.cfg keeps
## them) and the new key plays in a rampage; Settings > ACCESSIBILITY steps held moves, reduce
## flashing, rumble and gore by real clicks, each saved; held moves on TOGGLE latch the held
## button; Reduce flashing dims every flash reader and hides the fringe; the rumble thuds per
## growth stage, jolts on stomps and collapses and buzzes on the breath, and the toggle silences it;
## both pages fit the 4K TV at every UI scale; the graphics preview beside Settings redraws at each
## GRAPHICS level clicked, at the player's frame cap, and the card with it fits the TV.
## Seeded by design: city seed 0, time stepped by frames; no random draw is read.
##   godot --headless --path . --script tests/run_options_tests.gd

const GuiInput := preload("res://tests/lib/gui_input.gd")
const FlowLayout := preload("res://tests/lib/flow_layout.gd")
const OptionsPlay := preload("res://tests/lib/options_play.gd")

var _menu: SettingsMenu
## The shipped bindings' text by "action/slot", read after KeyBinds.reset() (D-385: no key names).
var _defaults := {}


func suite_name() -> String:
	return "Options"


func run_checks() -> void:
	KeyBinds.reset()
	for entry: Array in KeyBinds.actions():
		for slot: String in [KeyBinds.KEYS, KeyBinds.PAD]:
			_defaults["%s/%s" % [entry[0], slot]] = KeyBinds.text(str(entry[0]), slot)
	await _t("_check_rebind_keys")
	await _t("_check_rebind_pad_and_reset")
	await _t("_check_bindings_saved")
	await _t("_check_access_page")
	await _t("_check_held_toggle")
	await _t("_check_rumble_rows")
	await _t("_check_pages_fit")
	await _t("_check_graphics_preview")
	await _h("Options in play", func() -> void: await OptionsPlay.new(self, check).run())
	KeyBinds.reset()


func _default(action: String, slot: String) -> String:
	return str(_defaults.get("%s/%s" % [action, slot], ""))


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


## Opens Settings, then the page whose button reads `button`, by real clicks.
func _open(button: String) -> OptionsPage:
	if is_instance_valid(_menu):
		_menu.queue_free()
		await _frames(1)
	_menu = SettingsMenu.new()
	root.add_child(_menu)
	await _frames(3)
	var b := GuiInput.button(_menu, button)
	if b == null:
		return null
	await GuiInput.click(self, b)
	await _frames(2)
	return _menu.page


## Clicks the binding button of `action`'s `slot`, then sends `press` (a key or pad button press).
func _bind(page: ControlsMenu, action: String, slot: String, press: Callable) -> void:
	var b: Button = page.binds[action][slot]
	await GuiInput.click(self, b)
	await _frames(1)
	await press.call()
	await _frames(2)


func _check_rebind_keys() -> void:
	var page := await _open("CONTROLS") as ControlsMenu
	check(page != null, "clicking CONTROLS in Settings opens the Controls page")
	if page == null:
		return
	var sig: Button = page.binds["signature"][KeyBinds.KEYS]
	var first := _default("signature", KeyBinds.KEYS)
	check(
		first not in ["", "-"] and sig.text == first,
		"the signature attack starts on its default key ('%s', default '%s')" % [sig.text, first]
	)
	await GuiInput.click(self, sig)
	await _frames(1)
	check(sig.text == ControlsMenu.WAIT_KEYS, "a clicked binding waits for a key ('%s')" % sig.text)
	await GuiInput.key(self, KEY_R)
	await _frames(2)
	check(
		sig.text == "R" and InputMap.action_has_event("signature", _key(KEY_R)),
		"pressing R binds the signature attack to R ('%s')" % sig.text
	)
	check(
		KeyBinds.events("signature", KeyBinds.KEYS).size() == 1,
		"the default key no longer fires the signature attack, R alone does"
	)
	await _bind(page, "dash", KeyBinds.KEYS, func() -> void: await GuiInput.key(self, KEY_ESCAPE))
	check(
		(
			KeyBinds.text("dash", KeyBinds.KEYS) == _default("dash", KeyBinds.KEYS)
			and is_instance_valid(page)
		),
		"Esc while a binding waits keeps the old key and the page open"
	)
	await _bind(page, "dash", KeyBinds.KEYS, func() -> void: await GuiInput.key(self, KEY_W))
	check(
		(
			KeyBinds.text("dash", KeyBinds.KEYS) == "W"
			and not KeyBinds.text("move_up", KeyBinds.KEYS).split(" / ").has("W")
		),
		(
			"W on dash takes W off move up (dash '%s', move up '%s')"
			% [KeyBinds.text("dash", KeyBinds.KEYS), KeyBinds.text("move_up", KeyBinds.KEYS)]
		)
	)
	var row: Array = ControlsCard.rows()[1]
	check(str(row[1]) == "R", "the controls card shows the player's key (%s)" % [row])


func _check_rebind_pad_and_reset() -> void:
	var page := _menu.page as ControlsMenu
	check(page != null, "the Controls page is still open")
	if page == null:
		return
	var pad_x := func() -> void: await GuiInput.pad(self, JOY_BUTTON_X)
	await _bind(page, "ultimate", KeyBinds.PAD, pad_x)
	check(
		KeyBinds.text("ultimate", KeyBinds.PAD) == "X",
		"pressing pad X binds the ultimate to X ('%s')" % KeyBinds.text("ultimate", KeyBinds.PAD)
	)
	var saved := ConfigFile.new()
	saved.load(PlayerSettings.PATH)
	check(
		saved.has_section_key("bindings", "signature"),
		"settings.cfg keeps the rebound keys under [bindings]"
	)
	await GuiInput.click(self, GuiInput.button(page, "RESET"))
	await _frames(2)
	check(
		(
			KeyBinds.text("signature", KeyBinds.KEYS) == _default("signature", KeyBinds.KEYS)
			and KeyBinds.text("ultimate", KeyBinds.PAD) == _default("ultimate", KeyBinds.PAD)
			and KeyBinds.text("move_up", KeyBinds.KEYS) == _default("move_up", KeyBinds.KEYS)
		),
		"RESET brings back the default signature key, pad ultimate and move up"
	)
	# Leave R on the signature attack for the next checks and the rampage.
	var press_r := func() -> void: await GuiInput.key(self, KEY_R)
	await _bind(page, "signature", KeyBinds.KEYS, press_r)


## A restart: the defaults back on the InputMap, then settings.cfg read as at start.
func _check_bindings_saved() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PlayerSettings.PATH)
	KeyBinds.reset()
	check(
		KeyBinds.text("signature", KeyBinds.KEYS) == _default("signature", KeyBinds.KEYS),
		"the defaults are back before loading"
	)
	cfg.save(PlayerSettings.PATH)
	PlayerSettings.load_saved(false)
	check(
		KeyBinds.text("signature", KeyBinds.KEYS) == "R",
		"settings.cfg brings R back at the next start"
	)
	var broken := ConfigFile.new()
	broken.set_value("bindings", "signature", {"keys": ["key:nonsense"]})
	broken.set_value("bindings", "no_such_action", {"keys": ["key:82"]})
	broken.save(PlayerSettings.PATH)
	PlayerSettings.load_saved(false)
	check(
		KeyBinds.text("signature", KeyBinds.KEYS) == "-",
		"a damaged binding loads as unbound, never a crash"
	)
	cfg.save(PlayerSettings.PATH)
	PlayerSettings.load_saved(false)


func _check_access_page() -> void:
	var page := await _open("ACCESSIBILITY") as AccessMenu
	check(page != null, "clicking ACCESSIBILITY in Settings opens its page")
	if page == null:
		return
	# D-385: no button copy; each click flips its setting, relabels its button and is saved.
	var buttons: Array[Button] = [page.held, page.flashing, page.rumble, page.gore]
	var was := _access()
	var labels: Array[String] = []
	for b: Button in buttons:
		labels.append(b.text)
		await GuiInput.click(self, b)
	await _frames(2)
	var now := _access()
	var relabelled := true
	for i: int in buttons.size():
		relabelled = relabelled and buttons[i].text.strip_edges() != ""
		relabelled = relabelled and buttons[i].text != labels[i]
	var flipped := true
	for i: int in was.size():
		flipped = flipped and now[i] != was[i]
	check(flipped, "each click flips its setting (%s -> %s)" % [was, now])
	check(relabelled, "each click relabels its button (%s -> %s)" % [labels, buttons.map(_text)])
	var cfg := ConfigFile.new()
	cfg.load(PlayerSettings.PATH)
	var saved: Array[bool] = []
	for key: String in ["hold_toggle", "reduce_flashing", "rumble", "gore"]:
		saved.append(cfg.get_value("access", key, null) == true)
	check(
		saved == now and PlayerSettings.gore_on() == PlayerSettings.gore,
		"settings.cfg keeps all four (%s)" % [saved]
	)
	await GuiInput.key(self, KEY_ESCAPE)
	await _frames(2)
	check(not is_instance_valid(page) and is_instance_valid(_menu), "Esc closes only the page")


func _access() -> Array[bool]:
	return [
		PlayerSettings.hold_toggle,
		PlayerSettings.reduce_flashing,
		PlayerSettings.rumble,
		PlayerSettings.gore,
	]


func _text(b: Button) -> String:
	return b.text


func _check_held_toggle() -> void:
	var held := HeldButton.new()
	PlayerSettings.hold_toggle = false
	var hold := [held.read(true, true), held.read(false, false)]
	PlayerSettings.hold_toggle = true
	var toggle := [held.read(true, true), held.read(false, false), held.read(true, true)]
	check(hold == [true, false], "HOLD: the move lasts while the button is down %s" % [hold])
	check(
		toggle == [true, true, false],
		"TOGGLE: a press holds it on, the next lets it go %s" % [toggle]
	)


func _check_rumble_rows() -> void:
	var cfg := Content.section("rumble")
	for key: String in ["footfall", "stomp"]:
		var rows: Array = cfg[key]
		var stages := CityGrowth.stage_count(Content.tuning())
		var grows := rows.size() == stages
		for i: int in range(1, rows.size()):
			grows = grows and Num.f(rows[i]["strong"]) > Num.f(rows[i - 1]["strong"])
		check(
			grows,
			"the %s rumble has a row per growth stage (%d) and grows with each" % [key, stages]
		)


func _check_pages_fit() -> void:
	var layout := FlowLayout.new(self, check)
	for name: String in ["CONTROLS", "ACCESSIBILITY"]:
		var page := await _open(name)
		await layout.fits_at_scales(page, name + " page")
	_menu.queue_free()
	await _frames(1)


## Comment #90: GRAPHICS clicked steps the preview to the new level (its view, its particles), the
## menu runs at the player's own cap while it is open, and Settings with it fits the TV.
func _check_graphics_preview() -> void:
	var before := PlayerSettings.graphics
	_menu = SettingsMenu.new()
	root.add_child(_menu)
	await _frames(3)
	var preview := GuiInput.find_script(_menu, GraphicsPreview) as GraphicsPreview
	check(preview != null, "Settings shows the graphics preview")
	if preview == null:
		return
	check(PlayerSettings.previewing, "the preview lifts the menu frame cap")
	var port := preview.find_children("*", "SubViewport", true, false)[0] as SubViewport
	var levels: Dictionary = Content.section("display")["graphics"]
	for _i: int in levels.size():
		var b := GuiInput.button(_menu, "< %s >" % PlayerSettings.graphics_level().to_upper())
		await GuiInput.click(self, b)
		await _frames(2)
		var row := PlayerSettings.graphics_row()
		var level := PlayerSettings.graphics_level()
		check(
			is_equal_approx(port.scaling_3d_scale, Num.f(row["scale"])),
			"preview renders %s at its scale" % level
		)
		var ratio := Num.f(row["particles"])
		for p: Node in port.find_children("*", "GPUParticles3D", true, false):
			if not is_equal_approx((p as GPUParticles3D).amount_ratio, ratio):
				check(false, "preview particles at %s's ratio" % level)
				break
	await FlowLayout.new(self, check).fits_at_scales(_menu, "Settings with the preview")
	_menu.queue_free()
	await _frames(1)
	check(not PlayerSettings.previewing, "closing Settings restores the menu frame cap")
	PlayerSettings.graphics = before
	PlayerSettings.save()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e
