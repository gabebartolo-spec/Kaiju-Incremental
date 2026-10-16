class_name RampageHud
extends CanvasLayer
## The rampage HUD: health, clock, rubble, city destroyed, signature readiness; then the
## results panel. Reads the sim; the Continue button reports back through `continued`.

signal continued

const HEADLINES := {
	"defeated": "THE ARMY BROUGHT YOU DOWN",
	"time": "YOUR RAGE IS SPENT",
	"city_fallen": "THE CITY HAS FALLEN",
}

var sim: RampageSim
var species: Dictionary
var _hp: ProgressBar
var _hp_text: Label
var _time: Label
var _rubble: Label
var _destruction: ProgressBar
var _ability: Label
var _ultimate: Label
var _results_shown := false


func _init(p_sim: RampageSim, p_species: Dictionary) -> void:
	sim = p_sim
	species = p_species


func _ready() -> void:
	var root := MarginContainer.new()
	UiKit.full_rect(root)
	for side: String in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 28)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	top.add_child(left)
	left.add_child(UiKit.label(str(species["name"]).to_upper(), UiKit.SIZE_BODY, UiKit.MUTED))
	_hp = UiKit.bar(UiKit.BAD, 30)
	left.add_child(_hp)
	_hp_text = UiKit.label("", UiKit.SIZE_SMALL)
	left.add_child(_hp_text)

	_time = UiKit.label("", 64)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_time)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	top.add_child(right)
	_rubble = _right_label(right, "", UiKit.SIZE_HEAD, UiKit.WARN)
	_right_label(right, "CITY DESTROYED", UiKit.SIZE_SMALL, UiKit.MUTED)
	_destruction = UiKit.bar(UiKit.ACCENT, 22)
	right.add_child(_destruction)

	var bottom := VBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	root.add_child(bottom)
	_ability = UiKit.label("", UiKit.SIZE_HEAD)
	_ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_ability)
	_ultimate = UiKit.label("", UiKit.SIZE_BODY)
	_ultimate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_ultimate)
	var hint := UiKit.label("Move: WASD / left stick", UiKit.SIZE_SMALL, UiKit.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
	refresh()


func _right_label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := UiKit.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(l)
	return l


func refresh() -> void:
	_hp.max_value = sim.max_hp
	_hp.value = sim.hp
	_hp_text.text = "%d / %d" % [ceili(sim.hp), ceili(sim.max_hp)]
	_time.text = "%d" % ceili(maxf(0.0, sim.time_left))
	_time.add_theme_color_override("font_color", UiKit.BAD if sim.time_left < 10.0 else UiKit.TEXT)
	_rubble.text = "RUBBLE  %d" % Num.i(floor(sim.rubble))
	_destruction.value = sim.destruction() * 100.0
	var ability: Dictionary = species["ability"]
	var ability_name := str(ability["name"]).to_upper()
	if sim.ability_ready_in <= 0.0:
		_ability.text = "%s  READY  [Space / A]" % ability_name
		_ability.add_theme_color_override("font_color", UiKit.GOOD)
	else:
		_ability.text = "%s  %.1fs" % [ability_name, sim.ability_ready_in]
		_ability.add_theme_color_override("font_color", UiKit.MUTED)
	_ultimate.visible = sim.powers.has_ultimate()
	if sim.ultimate_ready_in <= 0.0:
		_ultimate.text = "ULTIMATE  READY  [E / Y]"
		_ultimate.add_theme_color_override("font_color", UiKit.ACCENT)
	else:
		_ultimate.text = "ULTIMATE  %.0fs" % sim.ultimate_ready_in
		_ultimate.add_theme_color_override("font_color", UiKit.MUTED)


func show_results() -> void:
	if _results_shown:
		return
	_results_shown = true
	var result := sim.result()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	UiKit.full_rect(dim)
	add_child(dim)
	var centre := CenterContainer.new()
	UiKit.full_rect(centre)
	add_child(centre)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(720, 0)
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var headline := str(HEADLINES.get(result["reason"], "RAMPAGE OVER"))
	var lines: Array[String] = [
		"Rubble earned:  %d" % Num.i(result["rubble"]),
		"City destroyed:  %d%%" % Num.i(Num.f(result["destruction"]) * 100.0),
		"Tanks crushed:  %d" % Num.i(result["tanks"]),
		"Helicopters downed:  %d" % Num.i(result["helis"]),
	]
	var title := UiKit.label(headline, UiKit.SIZE_HEAD, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	for line: String in lines:
		var l := UiKit.label(line, UiKit.SIZE_BODY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	var go := UiKit.button("EVOLVE  >", UiKit.SIZE_HEAD)
	go.pressed.connect(func() -> void: continued.emit())
	col.add_child(go)
	go.grab_focus.call_deferred()
