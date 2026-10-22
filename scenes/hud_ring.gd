class_name HudRing
extends Control
## A cooldown ring on the rampage HUD (b2-12): an icon with a ring that fills clockwise from
## the top while the move recharges. Ready, the ring closes, the icon lights and the ring pops
## once, so ready never rests on colour alone (the ready sound is the rampage's). No text.

enum Icon { BREATH, DASH, ULTIMATE }

## The icon fills this share of the ring's inner radius (a square, the PNG's whole image).
const ICON_SHARE := 0.95
const SEGMENTS := 64
## The dark outline around the ring (px each side), for contrast over fire.
const OUTLINE := 1.0
## An icon's tuning key (data "ui" hud icons: key -> texture path).
const KEYS := {Icon.BREATH: "breath", Icon.DASH: "dash", Icon.ULTIMATE: "ultimate"}

var icon: Icon
## 0 = just used, 1 = ready.
var ratio := 1.0
var radius: float
var width: float
## The icon: its own node and texture (path in data), apart from the ring, so new art drops in.
var icon_node: TextureRect
var _pulse: Tween


func _init(p_icon: Icon, p_radius: float, p_width: float) -> void:
	icon = p_icon
	radius = p_radius
	width = p_width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * 2.0 * (radius + width / 2.0 + OUTLINE + 1.0)
	resized.connect(_place_icon)
	icon_node = TextureRect.new()
	icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon_node.texture = load_icon(icon)
	add_child(icon_node)
	_tint()


## The icon texture for `which`, from the path in tuning "ui" hud icons (null, with an error, if it
## is missing).
static func load_icon(which: Icon) -> Texture2D:
	var paths: Dictionary = UiKit.ui()["hud"]["icons"]
	var path := str(paths.get(str(KEYS[which]), ""))
	if not ResourceLoader.exists(path):
		push_error("HudRing: no icon texture at '%s'" % path)
		return null
	return load(path) as Texture2D


func _place_icon() -> void:
	pivot_offset = size / 2.0
	var half := (radius - width / 2.0) * ICON_SHARE
	icon_node.size = Vector2.ONE * 2.0 * half
	icon_node.position = size / 2.0 - icon_node.size / 2.0


## White when ready, grey while it recharges.
func _tint() -> void:
	icon_node.modulate = Color.WHITE if is_ready() else UiKit.MUTED.darkened(0.25)


func is_ready() -> bool:
	return ratio >= 1.0


## The ring's fill (0..1); closing it pops the ring once.
func set_ratio(value: float) -> void:
	var was := is_ready()
	ratio = clampf(value, 0.0, 1.0)
	if is_ready() and not was:
		_pop()
	_tint()
	queue_redraw()


func _pop() -> void:
	var hud: Dictionary = UiKit.ui()["hud"]
	if _pulse != null:
		_pulse.kill()
	scale = Vector2.ONE * Num.f(hud["ring_ready_scale"])
	_pulse = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(self, "scale", Vector2.ONE, Num.f(hud["ring_ready_s"]))


func _draw() -> void:
	var c := size / 2.0
	var dark := UiKit.outline_color()
	draw_circle(c, radius + width / 2.0 + OUTLINE, Color(UiKit.BG, 0.55))
	draw_arc(c, radius, 0.0, TAU, SEGMENTS, dark, width + 2.0 * OUTLINE, true)
	draw_arc(c, radius, 0.0, TAU, SEGMENTS, UiKit.PANEL_EDGE, width, true)
	if ratio > 0.0:
		var start := -PI / 2.0
		draw_arc(c, radius, start, start + TAU * ratio, SEGMENTS, UiKit.ACCENT, width, true)
