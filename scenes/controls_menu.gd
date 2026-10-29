class_name ControlsMenu
extends OptionsPage
## Settings > CONTROLS (director 2026-10-26, D-259 "Rebindable keys and buttons"): each action's
## keyboard-and-mouse and pad binding as a button; press one, then the key, mouse button or pad
## button to use (Esc keeps the old one). KeyBinds binds it, takes it off any other action, and
## saves. RESET brings the game's own bindings back. The rows nobody rebinds (fullscreen, menu
## confirm and back) are listed under them.

## A binding's text while it waits, in English (the button shows it through tr()).
const WAIT_KEYS := "PRESS A KEY"
const WAIT_PAD := "PRESS A BUTTON"
## The Controls list rows (PlayerSettings.CONTROLS) shown as text: not rebindable here.
const FIXED: Array[String] = ["Glide (insectoid, hold)", "Fullscreen", "Confirm", "Back"]

## action -> {KeyBinds.KEYS: Button, KeyBinds.PAD: Button}
var binds: Dictionary = {}
## The binding waiting for its input: [action, slot], or [] when none is.
var waiting: Array = []


func _init() -> void:
	super(tr("CONTROLS"))


func _build(col: VBoxContainer) -> void:
	var heads: Array[Control] = [
		UiKit.label(tr("Keyboard"), UiKit.SIZE_BODY, UiKit.MUTED),
		UiKit.label(tr("Pad"), UiKit.SIZE_BODY, UiKit.MUTED),
	]
	row(col, "", heads)
	for entry: Array in KeyBinds.actions():
		var action := str(entry[0])
		var keys := choice(_wait.bind(action, KeyBinds.KEYS))
		var pad: Control
		binds[action] = {KeyBinds.KEYS: keys}
		if entry[2]:
			pad = choice(_wait.bind(action, KeyBinds.PAD))
			binds[action][KeyBinds.PAD] = pad
		else:  # made only here: a label built and then replaced was never freed (debt row 2)
			pad = UiKit.label(KeyBinds.shown("Left stick"), UiKit.SIZE_BODY, UiKit.MUTED)
		row(col, KeyBinds.shown(str(entry[1])), [keys, pad])
	for entry: Array in PlayerSettings.CONTROLS:
		if not FIXED.has(str(entry[0])):
			continue
		if entry.size() > 3 and not Demo.allows(str(entry[3])):
			continue
		var texts: Array[Control] = [
			UiKit.label(KeyBinds.shown(str(entry[1])), UiKit.SIZE_BODY, UiKit.MUTED),
			UiKit.label(KeyBinds.shown(str(entry[2])), UiKit.SIZE_BODY, UiKit.MUTED),
		]
		row(col, KeyBinds.shown(str(entry[0])), texts)


func _foot_buttons() -> Array[Button]:
	var reset := UiKit.button(tr("RESET"), UiKit.SIZE_HEAD)
	HazardBox.trim_height(reset, BACK_MARGIN)
	reset.pressed.connect(
		func() -> void:
			waiting = []
			KeyBinds.reset()
	)
	return [reset]


func _wait(action: String, slot: String) -> void:
	waiting = [action, slot]


## While a binding waits, the next press of its kind is the new binding; Esc keeps the old one.
func _input(event: InputEvent) -> void:
	if waiting.is_empty() or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key != null and (key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE):
		waiting = []
		get_viewport().set_input_as_handled()
		return
	if KeyBinds.slot_of(event) != str(waiting[1]):
		return
	KeyBinds.bind(str(waiting[0]), event)
	waiting = []
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	for action: String in binds.keys():
		var slots: Dictionary = binds[action]
		for slot: String in slots.keys():
			var b: Button = slots[slot]
			if waiting == [action, slot]:
				b.text = tr("PRESS A KEY") if slot == KeyBinds.KEYS else tr("PRESS A BUTTON")
			else:
				b.text = KeyBinds.text(action, slot)
