extends "res://tests/lib/runner.gd"
## Options suite (director 2026-10-26, D-259): Settings > CONTROLS rebinds a key and a pad button
## by real presses (a conflict moves, Esc keeps the old one, RESET restores, settings.cfg keeps
## them) and the new key plays in a rampage; Settings > ACCESSIBILITY steps held moves, reduce
## flashing, rumble and gore by real clicks, each saved; held moves on TOGGLE latch the held
## button; Reduce flashing dims every flash reader and hides the fringe; the rumble thuds per
## growth stage, jolts on stomps and collapses and buzzes on the breath, and the toggle silences it;
## both pages fit the 4K TV at every UI scale.
## Seeded by design: city seed 0, time stepped by frames; no random draw is read.
##   godot --headless --path . --script tests/run_options_tests.gd

const GuiInput := preload("res://tests/lib/gui_input.gd")
const FlowLayout := preload("res://tests/lib/flow_layout.gd")
const OptionsPlay := preload("res://tests/lib/options_play.gd")

var _menu: SettingsMenu


func suite_name() -> String:
	return "Options"


func run_checks() -> void:
	KeyBinds.reset()
	await _t("_check_rebind_keys")
	await _t("_check_rebind_pad_and_reset")
	await _t("_check_bindings_saved")
	await _t("_check_access_page")
	await _t("_check_held_toggle")
	await _t("_check_rumble_rows")
	await _t("_check_pages_fit")
	await _h("Options in play", func() -> void: await OptionsPlay.new(self, check).run())
	KeyBinds.reset()


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
	check(sig.text == "Space", "the signature attack starts on Space ('%s')" % sig.text)
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
		not InputMap.action_has_event("signature", _key(KEY_SPACE)),
		"Space no longer fires the signature attack"
	)
	await _bind(page, "dash", KeyBinds.KEYS, func() -> void: await GuiInput.key(self, KEY_ESCAPE))
	check(
		KeyBinds.text("dash", KeyBinds.KEYS) == "Shift" and is_instance_valid(page),
		"Esc while a binding waits keeps the old key and the page open"
	)
	await _bind(page, "dash", KeyBinds.KEYS, func() -> void: await GuiInput.key(self, KEY_W))
	check(
		(
			KeyBinds.text("dash", KeyBinds.KEYS) == "W"
			and KeyBinds.text("move_up", KeyBinds.KEYS) == "Up"
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
			KeyBinds.text("signature", KeyBinds.KEYS) == "Space"
			and KeyBinds.text("ultimate", KeyBinds.PAD) == "Y"
			and KeyBinds.text("move_up", KeyBinds.KEYS).begins_with("W")
		),
		"RESET brings back Space, pad Y and W"
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
		KeyBinds.text("signature", KeyBinds.KEYS) == "Space", "the defaults are back before loading"
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
	check(
		(
			page.held.text == "< HOLD >"
			and page.flashing.text == "< OFF >"
			and page.rumble.text == "< ON >"
			and page.gore.text == "< ON >"
		),
		"the defaults read HOLD, flashing OFF, rumble ON, gore ON"
	)
	for b: Button in [page.held, page.flashing, page.rumble, page.gore]:
		await GuiInput.click(self, b)
	await _frames(2)
	var cfg := ConfigFile.new()
	cfg.load(PlayerSettings.PATH)
	check(
		(
			page.held.text == "< TOGGLE >"
			and page.flashing.text == "< ON >"
			and page.rumble.text == "< OFF >"
			and page.gore.text == "< REDUCED >"
		),
		"each click steps its setting (%s)" % [[page.held.text, page.gore.text]]
	)
	check(
		(
			str(cfg.get_value("access", "hold_toggle")) == "true"
			and str(cfg.get_value("access", "reduce_flashing")) == "true"
			and str(cfg.get_value("access", "rumble")) == "false"
			and str(cfg.get_value("access", "gore")) == "false"
			and not PlayerSettings.gore_on()
		),
		"settings.cfg keeps all four"
	)
	await GuiInput.key(self, KEY_ESCAPE)
	await _frames(2)
	check(not is_instance_valid(page) and is_instance_valid(_menu), "Esc closes only the page")


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
		var grows := rows.size() == 3
		for i: int in range(1, rows.size()):
			grows = grows and Num.f(rows[i]["strong"]) > Num.f(rows[i - 1]["strong"])
		check(grows, "the %s rumble grows with each of the three growth stages" % key)


func _check_pages_fit() -> void:
	var layout := FlowLayout.new(self, check)
	for name: String in ["CONTROLS", "ACCESSIBILITY"]:
		var page := await _open(name)
		await layout.fits_at_scales(page, name + " page")
	_menu.queue_free()
	await _frames(1)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e
