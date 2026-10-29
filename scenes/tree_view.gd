class_name TreeView
extends RefCounted
## The evolution tree's camera (D-275: "we need to be able to zoom out and pan easily"): which
## point of the tree is at the middle of the screen and how far it is zoomed. Pure maths, so the
## tree suite checks the clamps headless. Zoom 1 is the default, text at 24 px on 1080p; the
## furthest zoom out fits the whole tree on screen; zoom stays between the two. Panning stays
## clamped so the tree never leaves the screen: on an axis where the tree is wider than the
## view, the view stays over the tree; where it is narrower, the tree stays centred.

const DEFAULT_ZOOM := 1.0

var zoom := DEFAULT_ZOOM
## The tree point (canvas units) at the middle of the view.
var centre := Vector2.ZERO
## The view's size on screen.
var view_size := Vector2(1920, 1080)
## The box round every node (TreeLayout.bounds).
var bounds := Rect2()
## A share of the view the whole tree fills at the furthest zoom out (tuning "tree" "view").
var fit_margin := 0.95


func _init(p_bounds: Rect2, p_view: Vector2, p_fit_margin: float) -> void:
	bounds = p_bounds
	fit_margin = p_fit_margin
	resize(p_view)


## The zoom at which the whole tree fits the view (never above the default).
func fit_zoom() -> float:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return DEFAULT_ZOOM
	var fit := minf(view_size.x / bounds.size.x, view_size.y / bounds.size.y) * fit_margin
	return minf(fit, DEFAULT_ZOOM)


## The view changed size: keep the zoom and centre inside their limits.
func resize(p_view: Vector2) -> void:
	view_size = Vector2(maxf(1.0, p_view.x), maxf(1.0, p_view.y))
	set_zoom(zoom)


func set_zoom(z: float) -> void:
	zoom = clampf(z, fit_zoom(), DEFAULT_ZOOM)
	clamp_centre()


## Zooms by `factor` keeping the tree point under `screen_at` (view coordinates) where it is,
## as far as the clamps allow (the mouse wheel zooms toward the cursor).
func zoom_at(screen_at: Vector2, factor: float) -> void:
	var held := to_tree(screen_at)
	zoom = clampf(zoom * factor, fit_zoom(), DEFAULT_ZOOM)
	centre = held - (screen_at - view_size * 0.5) / zoom
	clamp_centre()


## Moves the view by `screen_delta` (view pixels): dragging the tree right shows what is left.
func pan_by(screen_delta: Vector2) -> void:
	centre -= screen_delta / zoom
	clamp_centre()


## Puts `tree_point` at the middle of the view, as near as the clamps allow.
func look_at(tree_point: Vector2) -> void:
	centre = tree_point
	clamp_centre()


func clamp_centre() -> void:
	var half := view_size * 0.5 / zoom
	centre.x = _clamp_axis(centre.x, bounds.position.x, bounds.end.x, half.x)
	centre.y = _clamp_axis(centre.y, bounds.position.y, bounds.end.y, half.y)


static func _clamp_axis(at: float, low: float, high: float, half: float) -> float:
	if high - low <= half * 2.0:
		return (low + high) * 0.5
	return clampf(at, low + half, high - half)


## A tree point's place in the view (view pixels).
func to_screen(tree_point: Vector2) -> Vector2:
	return (tree_point - centre) * zoom + view_size * 0.5


## The tree point under a place in the view.
func to_tree(screen_at: Vector2) -> Vector2:
	return (screen_at - view_size * 0.5) / zoom + centre
