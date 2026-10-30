class_name TreeFxLayer
extends Control
## Draws the tree's juice that sits over the nodes (TreeFx): motes flying to a bought node, the
## white flash on it, a ring's rim flaring open, an evolution's bolts and plate flash.

var area: TreeArea


func _init(p_area: TreeArea) -> void:
	area = p_area
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(self)


func _draw() -> void:
	var fx := area.fx
	var juice := area.colour("juice")
	var top := area.colour("liquid_top")
	_draw_motes(fx, juice, top)
	# A bought node flashes white and fades.
	for id: String in fx.flashes:
		var share := Num.f(fx.flashes[id]) / fx.f("flash_s")
		var b: UpgradeNode = area.buttons[id]
		var rect := Rect2(b.position, b.size * area.view.zoom)
		draw_rect(rect, Color(1, 1, 1, 0.75 * share))
	_draw_rings(fx, top)
	# An evolution: lightning from the plate's centre to the node, over a plate flash.
	if fx.plate_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(top, fx.plate_flash))
	var origin := area.view.to_screen(Vector2.ZERO)
	for bolt: Dictionary in fx.bolts:
		var share := 1.0 - Num.f(bolt["t"]) / fx.f("bolt_s")
		var to := area.centre_of(str(bolt["to"]))
		for which: int in Num.i(fx.cfg["bolt_count"]):
			var points := fx.bolt_points(origin, to, Num.i(bolt["seed"]), which)
			draw_polyline(points, Color(juice, share), 9.0 * share + 1.0, true)
			draw_polyline(points, Color(Color.WHITE, share), 3.0 * share + 0.5, true)


## Motes: Special K leaving the counter for the cell, each on its own bow.
func _draw_motes(fx: TreeFx, juice: Color, top: Color) -> void:
	var mote_px := fx.f("mote_px") * maxf(0.5, area.view.zoom)
	for mote: Dictionary in fx.motes:
		var p := fx.mote_progress(mote)
		if p < 0.0:
			continue
		var from: Vector2 = mote["at"]
		var to := area.centre_of(str(mote["to"]))
		var along := to - from
		var side := Vector2(-along.y, along.x) * fx.f("mote_bow") * Num.f(mote["side"])
		var ease := p * p * (3.0 - 2.0 * p)
		var at := from + along * ease + side * sin(p * PI)
		draw_circle(at, mote_px * (1.0 - 0.5 * p), juice)
		draw_circle(at, mote_px * 0.45, top)


## A ring opening: its rim flares out and fades.
func _draw_rings(fx: TreeFx, top: Color) -> void:
	var origin := area.view.to_screen(Vector2.ZERO)
	for open: Dictionary in fx.ring_opens:
		var share := 1.0 - Num.f(open["t"]) / fx.f("ring_open_s")
		var reach := area.rim_radius(Num.i(open["ring"]) - 1) * area.view.zoom
		var width := fx.f("ring_open_width") * area.view.zoom * share
		draw_arc(origin, reach, 0.0, TAU, 160, Color(top, share), maxf(1.0, width), true)
