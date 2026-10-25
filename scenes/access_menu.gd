class_name AccessMenu
extends OptionsPage
## Settings > ACCESSIBILITY (director 2026-10-26, D-259): held moves on hold or toggle, reduce
## flashing, pad rumble, gore. Every press steps its setting through PlayerSettings, which saves.

var held: Button
var flashing: Button
var rumble: Button
var gore: Button


func _init() -> void:
	super("ACCESSIBILITY")


func _build(col: VBoxContainer) -> void:
	held = choice(func() -> void: PlayerSettings.toggle_hold())
	row(col, "Held moves", [held])
	flashing = choice(func() -> void: PlayerSettings.toggle_flashing())
	row(col, "Reduce flashing", [flashing])
	rumble = choice(func() -> void: PlayerSettings.toggle_rumble())
	row(col, "Rumble", [rumble])
	gore = choice(func() -> void: PlayerSettings.toggle_gore())
	row(col, "Gore", [gore])


func _refresh() -> void:
	held.text = cycle("TOGGLE" if PlayerSettings.hold_toggle else "HOLD")
	flashing.text = cycle("ON" if PlayerSettings.reduce_flashing else "OFF")
	rumble.text = cycle("ON" if PlayerSettings.rumble else "OFF")
	gore.text = cycle("ON" if PlayerSettings.gore else "REDUCED")
