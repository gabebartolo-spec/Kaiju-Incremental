class_name HudEndBeat
extends RefCounted
## The HUD's end beat (RampageHud): the run's last words on screen, by how it ended.


## The end beat: the reason the rampage ended slams onto the screen while the city keeps falling
## at normal speed (D-259: slow motion only when a landmark falls, LandmarkSlowmo; time stays 1.0
## here). After BEAT_FRAMES (or a confirm once BEAT_MIN_FRAMES have shown, so a held attack button
## cannot skip it by accident) it reports `beat_done`.
static func show_end_beat(h: RampageHud, reason: String) -> void:
	if h._beat_frame >= 0:
		return
	h._beat_frame = 0
	h.clock.visible = false
	h.news.muted = true
	h.news.visible = false
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.55, 0.25, 0.45 * PlayerSettings.flash_scale())  # Reduce flashing
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(flash)
	h.add_child(flash)
	var top := MarginContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(top)
	top.add_theme_constant_override("margin_top", RampageHud.BEAT_TOP)
	h.add_child(top)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(col)
	var lines: Array = RampageHud.HEADLINES.get(reason, ["RAMPAGE OVER", ""])
	h.headline = UiKit.label(h._beat(str(lines[0])), RampageHud.BEAT_SIZE, UiKit.ACCENT)
	h.headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(h.headline)
	var sub := UiKit.label(h._beat(str(lines[1])), UiKit.SIZE_HEAD, UiKit.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	h.headline.pivot_offset = h.headline.get_combined_minimum_size() * 0.5
	var tween := h.create_tween().set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	h.headline.scale = Vector2.ONE * 2.4
	tween.tween_property(h.headline, "scale", Vector2.ONE, 0.35)
	tween.parallel().tween_property(flash, "color:a", 0.0, 0.6)
