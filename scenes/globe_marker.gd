class_name GlobeMarker
extends Control
## One continent's mission marker on the globe (Overworld plan row G4; director 2026-11-01: pin and
## name): a small diamond on the continent with a leader line up and right to its name. GlobeView
## places it each frame at the continent's anchor projected to the screen (the Control's position
## is the diamond's centre) and fades it out as the anchor turns away toward the globe's edge.

const DIAMOND_PX := 9.0  # half the diamond's diagonal, px at 1080p
const LEADER := Vector2(22.0, -22.0)  # diamond centre to the line's elbow
const LEADER_RUN := 10.0  # the line's flat run from the elbow to the name
const LINE_PX := 2.0
const NAME_GAP := 4.0  # line end to the name's left edge

var _name: Label


func _init(display_name: String) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_name = UiKit.label(display_name.to_upper(), UiKit.SIZE_SMALL, UiKit.ACCENT)
	_name.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_name)


func _ready() -> void:
	var size_px := _name.get_combined_minimum_size()
	_name.position = Vector2(LEADER.x + LEADER_RUN + NAME_GAP, LEADER.y - size_px.y / 2.0)


func _draw() -> void:
	var ink := UiKit.outline_color()
	var outline := float(UiKit.outline_px(UiKit.SIZE_SMALL))
	var elbow := LEADER
	var tip := LEADER + Vector2(LEADER_RUN, 0.0)
	# The outline first, wider, so the yellow reads over the bright coastlines.
	for pass_ink: Color in [ink, UiKit.ACCENT]:
		var grow := outline if pass_ink == ink else 0.0
		var w := LINE_PX + grow * 2.0
		draw_polyline(PackedVector2Array([Vector2.ZERO, elbow, tip]), pass_ink, w, true)
		var r := DIAMOND_PX + grow
		draw_colored_polygon(
			PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)]),
			pass_ink
		)
