class_name KeyBinds
extends RefCounted
## The player's own keys and pad buttons (director 2026-10-26, D-259 "Rebindable keys and
## buttons"). The Settings autoload builds the default bindings, then snapshot() keeps them and
## PlayerSettings.load_saved() puts the player's on top (settings.cfg [bindings]). A binding is a
## slot of an action: "keys" (keyboard keys and mouse buttons) or "pad" (pad buttons); binding a
## new input replaces the whole slot, and takes that input off every other action here so one
## press never does two things. Static, like PlayerSettings.

const KEYS := "keys"
const PAD := "pad"
## The actions the player can rebind, in the Controls page's order: action, the name it shows, and
## whether its pad slot takes a button (the moves stay on the left stick). An action the build does
## not have (stomp before its own button lands) is left out.
const ACTIONS: Array[Array] = [
	["move_up", "Move up", false],
	["move_down", "Move down", false],
	["move_left", "Move left", false],
	["move_right", "Move right", false],
	["signature", "Signature attack", true],
	["stomp", "Stomp", true],
	["dash", "Leap", true],
	["ultimate", "Ultimate", true],
	["pause", "Pause", true],
]
## The Controls list's rows (PlayerSettings.CONTROLS) that a rebind changes: the row's name, the
## actions whose keys it shows.
const ROWS := {
	"Move": ["move_up", "move_left", "move_down", "move_right"],
	"Signature attack": ["signature"],
	"Stomp": ["stomp"],
	"Leap": ["dash"],
	"Ultimate": ["ultimate"],
	"Pause": ["pause"],
}
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Left click",
	MOUSE_BUTTON_RIGHT: "Right click",
	MOUSE_BUTTON_MIDDLE: "Middle click",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}
const PAD_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up",
	JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}

## action -> {slot: [InputEvent]}: the slots the player has set (what settings.cfg keeps).
static var changed: Dictionary = {}
## action -> [InputEvent]: the bindings the game starts with (snapshot()).
static var _defaults: Dictionary = {}


## The ACTIONS rows this build has.
static func actions() -> Array[Array]:
	var out: Array[Array] = []
	for row: Array in ACTIONS:
		if InputMap.has_action(str(row[0])):
			out.append(row)
	return out


## Keeps the default bindings (Settings._ready, once the actions are built), so reset() can
## bring them back.
static func snapshot() -> void:
	_defaults.clear()
	for row: Array in actions():
		var action := str(row[0])
		_defaults[action] = InputMap.action_get_events(action).duplicate()


## The slot an input fills: KEYS (a key or a mouse button), PAD (a pad button), or "" (anything
## else: sticks, mouse motion).
static func slot_of(event: InputEvent) -> String:
	if event is InputEventKey or event is InputEventMouseButton:
		return KEYS
	if event is InputEventJoypadButton:
		return PAD
	return ""


## Binds `event` alone to `action`'s slot and takes it off every other rebindable action; saved.
static func bind(action: String, event: InputEvent) -> void:
	var slot := slot_of(event)
	if slot == "" or not InputMap.has_action(action):
		return
	var clean := _clean(event)
	for row: Array in actions():
		var other := str(row[0])
		if other == action:
			continue
		var kept: Array[InputEvent] = []
		var dropped := false
		for e: InputEvent in events(other, slot):
			if _same(e, clean):
				dropped = true
			else:
				kept.append(e)
		if dropped:
			_set_slot(other, slot, kept)
	var only: Array[InputEvent] = [clean]
	_set_slot(action, slot, only)
	PlayerSettings.save()


## Every binding back to the game's defaults; saved.
static func reset() -> void:
	for action: String in _defaults.keys():
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for e: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, e)
	changed.clear()
	PlayerSettings.save()


## The events of `action` in `slot`.
static func events(action: String, slot: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return out
	for e: InputEvent in InputMap.action_get_events(action):
		if slot_of(e) == slot:
			out.append(e)
	return out


## What `action`'s slot shows: its inputs by name ("Space / Left click"), "-" when it has none.
static func text(action: String, slot: String) -> String:
	var names: Array[String] = []
	for e: InputEvent in events(action, slot):
		names.append(input_name(e))
	return " / ".join(names) if not names.is_empty() else "-"


## An input's name as the player knows it.
static func input_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "Esc" if code == KEY_ESCAPE else OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		var index := (event as InputEventMouseButton).button_index
		if MOUSE_NAMES.has(index):
			return shown(str(MOUSE_NAMES[index]))
		return TranslationServer.translate("Mouse %d") % index
	if event is InputEventJoypadButton:
		var button := (event as InputEventJoypadButton).button_index
		if PAD_NAMES.has(button):
			return shown(str(PAD_NAMES[button]))
		return TranslationServer.translate("Button %d") % button
	return "-"


## A name from ACTIONS, PlayerSettings.CONTROLS, MOUSE_NAMES or PAD_NAMES in the player's language
## (the English text is the key, each written out here so tools/i18n/strings.py finds it). Key and
## button names ("E", "Esc / P", "RB") have no entry and stay as they are.
static func shown(text: String) -> String:
	var names := {
		"Move": TranslationServer.translate("Move"),
		"Move up": TranslationServer.translate("Move up"),
		"Move down": TranslationServer.translate("Move down"),
		"Move left": TranslationServer.translate("Move left"),
		"Move right": TranslationServer.translate("Move right"),
		"Signature attack": TranslationServer.translate("Signature attack"),
		"Stomp": TranslationServer.translate("Stomp"),
		"Leap": TranslationServer.translate("Leap"),
		"Ultimate": TranslationServer.translate("Ultimate"),
		"Pause": TranslationServer.translate("Pause"),
		"Glide (insectoid, hold)": TranslationServer.translate("Glide (insectoid, hold)"),
		"Fullscreen": TranslationServer.translate("Fullscreen"),
		"Confirm": TranslationServer.translate("Confirm"),
		"Back": TranslationServer.translate("Back"),
		"WASD / arrows": TranslationServer.translate("WASD / arrows"),
		"Left stick": TranslationServer.translate("Left stick"),
		"Hold Space": TranslationServer.translate("Hold Space"),
		"Hold A": TranslationServer.translate("Hold A"),
		"Left click": TranslationServer.translate("Left click"),
		"Right click": TranslationServer.translate("Right click"),
		"Middle click": TranslationServer.translate("Middle click"),
		"Mouse 4": TranslationServer.translate("Mouse 4"),
		"Mouse 5": TranslationServer.translate("Mouse 5"),
		"D-pad up": TranslationServer.translate("D-pad up"),
		"D-pad down": TranslationServer.translate("D-pad down"),
		"D-pad left": TranslationServer.translate("D-pad left"),
		"D-pad right": TranslationServer.translate("D-pad right"),
	}
	return str(names.get(text, text))


## The keyboard and pad text of a Controls list row `entry` ([name, keyboard, pad, ...]) with the
## player's bindings in place of the defaults' text, for each slot the player changed.
static func row_text(entry: Array) -> Array:
	var out := entry.duplicate()
	var acts: Array = ROWS.get(str(entry[0]), [])
	if acts.is_empty():
		return out
	if _any_changed(acts, KEYS):
		var keys: Array[String] = []
		for action: Variant in acts:
			keys.append(text(str(action), KEYS))
		out[1] = (" " if acts.size() > 1 else " / ").join(keys)
	if acts.size() == 1 and _any_changed(acts, PAD):
		out[2] = text(str(acts[0]), PAD)
	return out


static func _any_changed(acts: Array, slot: String) -> bool:
	for action: Variant in acts:
		var slots: Dictionary = changed.get(str(action), {})
		if slots.has(slot):
			return true
	return false


## Writes the player's slots into settings.cfg's [bindings] (PlayerSettings.save()).
static func write(cfg: ConfigFile) -> void:
	for action: String in changed.keys():
		var slots: Dictionary = changed[action]
		var out := {}
		for slot: String in slots.keys():
			var codes: Array[String] = []
			for e: InputEvent in slots[slot]:
				codes.append(_code(e))
			out[slot] = codes
		cfg.set_value("bindings", action, out)


## Puts settings.cfg's [bindings] on the InputMap (PlayerSettings.load_saved()); an unknown action
## or input is skipped.
static func read(cfg: ConfigFile) -> void:
	changed.clear()
	if not cfg.has_section("bindings"):
		return
	for action: String in cfg.get_section_keys("bindings"):
		var value: Variant = cfg.get_value("bindings", action, {})
		if not InputMap.has_action(action) or not value is Dictionary:
			continue
		var saved: Dictionary = value
		for slot: Variant in saved.keys():
			if str(slot) not in [KEYS, PAD]:
				continue
			var list: Array[InputEvent] = []
			var codes: Variant = saved[slot]
			if not codes is Array:
				continue
			for code: Variant in codes:
				var e := _event(str(code))
				if e != null and slot_of(e) == str(slot):
					list.append(e)
			_set_slot(action, str(slot), list)


static func _set_slot(action: String, slot: String, list: Array[InputEvent]) -> void:
	for e: InputEvent in events(action, slot):
		InputMap.action_erase_event(action, e)
	for e: InputEvent in list:
		InputMap.action_add_event(action, e)
	var slots: Dictionary = changed.get(action, {})
	slots[slot] = list
	changed[action] = slots


## The input as the game binds it: a key by its physical place, a mouse or pad button by index.
static func _clean(event: InputEvent) -> InputEvent:
	return _event(_code(event))


static func _same(a: InputEvent, b: InputEvent) -> bool:
	return _code(a) == _code(b)


## "key:<physical keycode>", "mouse:<button>", "pad:<button>".
static func _code(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key:%d" % code
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "pad:%d" % (event as InputEventJoypadButton).button_index
	return ""


static func _event(code: String) -> InputEvent:
	var kind := code.get_slice(":", 0)
	var number := code.get_slice(":", 1)
	if not number.is_valid_int():
		return null
	match kind:
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = number.to_int() as Key
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = number.to_int() as MouseButton
			return mouse
		"pad":
			var pad := InputEventJoypadButton.new()
			pad.button_index = number.to_int() as JoyButton
			return pad
	return null
