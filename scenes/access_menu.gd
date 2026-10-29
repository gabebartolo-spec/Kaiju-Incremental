class_name AccessMenu
extends OptionsPage
## Settings > ACCESSIBILITY (director 2026-10-26, D-259): held moves on hold or toggle, reduce
## flashing, pad rumble, gore, and the language (D-392). Every press steps its setting through
## PlayerSettings, which saves.

var held: Button
var flashing: Button
var rumble: Button
var gore: Button
var language: Button


func _init() -> void:
	super(tr("ACCESSIBILITY"))


func _build(col: VBoxContainer) -> void:
	held = choice(func() -> void: PlayerSettings.toggle_hold())
	row(col, tr("Held moves"), [held])
	flashing = choice(func() -> void: PlayerSettings.toggle_flashing())
	row(col, tr("Reduce flashing"), [flashing])
	rumble = choice(func() -> void: PlayerSettings.toggle_rumble())
	row(col, tr("Rumble"), [rumble])
	gore = choice(func() -> void: PlayerSettings.toggle_gore())
	row(col, tr("Gore"), [gore])
	language = choice(func() -> void: PlayerSettings.next_language())
	# Each language's name is shown as its own speakers write it, never translated.
	language.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row(col, tr("Language"), [language])


func _refresh() -> void:
	held.text = cycle(tr("TOGGLE") if PlayerSettings.hold_toggle else tr("HOLD"))
	flashing.text = cycle(tr("ON") if PlayerSettings.reduce_flashing else tr("OFF"))
	rumble.text = cycle(tr("ON") if PlayerSettings.rumble else tr("OFF"))
	gore.text = cycle(tr("ON") if PlayerSettings.gore else tr("REDUCED"))
	language.text = cycle(PlayerSettings.language_name())
