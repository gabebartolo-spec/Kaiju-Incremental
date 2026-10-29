extends RefCounted
## The tree suite's map checks (tests/run_tree_tests.gd; D-275, layout A: "A but we need to be
## able to zoom out and pan easily"): every node inside its own stage's ring and no two touching
## (TreeLayout), and the camera (TreeView) zooming between the default (text 24 px at 1080p) and
## the whole tree, toward the cursor, and panning without the tree leaving the screen. Pure maths:
## no scene is built.

const CROC := "reptilian"
const SPECIES: Array[String] = ["reptilian", "insectoid", "cephalopod"]
const SCREEN := Vector2(1920, 1080)
## The map beside the side panel at 1080p, smaller than the screen (a fit there fits the screen).
const AREA := Vector2(1300, 1000)
const CROC_NODES := 58

var check: Callable
## The share of the view the whole tree fills (tuning "tree" "view").
var _fit: float


func _init(p_check: Callable) -> void:
	check = p_check
	var cfg: Dictionary = Content.section("tree")["view"]
	_fit = Num.f(cfg["fit_margin"])


func run() -> void:
	_check_map_rings()
	_check_map_overlap()
	_check_map_fit()
	_check_view_zoom_clamp()
	_check_view_pan_clamp()
	_check_view_zoom_cursor()


## The map of `species`' tree, capstones marked as the upgrade screen marks them.
func _map(species: String) -> TreeLayout:
	var tree := UpgradeTree.new(Content.upgrades(), {}, species)
	var ultimates: Array[String] = []
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		if def.get("ultimate", false) == true:
			ultimates.append(id)
	return TreeLayout.build(tree, ultimates)


## D-275 bar 5: every node's box lies inside its own ring's band (radius +/- half its depth), and
## the bands never overlap, in every species' map.
func _check_map_rings() -> void:
	var bad: Array[String] = []
	for species: String in SPECIES:
		var tree := UpgradeTree.new(Content.upgrades(), {}, species)
		var map := _map(species)
		for id: String in tree.order:
			var r := tree.ring(id)
			var box := map.rect(id)
			var corners: Array[Vector2] = [
				box.position,
				box.end,
				Vector2(box.end.x, box.position.y),
				Vector2(box.position.x, box.end.y)
			]
			for corner: Vector2 in corners:
				var off := absf(corner.length() - map.radii[r - 1])
				if off > map.half_depth[r - 1] + 0.01:
					bad.append("%s %s leaves ring %d by %.0f" % [species, id, r, off])
		for k: int in range(map.radii.size() - 1):
			var out := map.radii[k] + map.half_depth[k]
			if out >= map.radii[k + 1] - map.half_depth[k + 1]:
				bad.append("%s rings %d and %d overlap" % [species, k + 1, k + 2])
	check.call(bad.is_empty(), "every node inside its own stage ring: %s" % [bad.slice(0, 6)])


## D-275 bar 5: no two nodes' boxes overlap, in any species' map.
func _check_map_overlap() -> void:
	var bad: Array[String] = []
	for species: String in SPECIES:
		var map := _map(species)
		var ids: Array = map.centres.keys()
		for a: int in ids.size():
			for b: int in range(a + 1, ids.size()):
				var one := str(ids[a])
				var two := str(ids[b])
				if map.rect(one).intersects(map.rect(two)):
					bad.append("%s %s and %s" % [species, one, two])
	check.call(bad.is_empty(), "no two nodes overlap: %s" % [bad.slice(0, 6)])


## D-275 bar 1: zoomed all the way out, all 58 croc nodes sit inside the 16:9 screen and inside
## the smaller map area beside the side panel.
func _check_map_fit() -> void:
	var map := _map(CROC)
	check.call(map.centres.size() == CROC_NODES, "the croc map has %d nodes" % map.centres.size())
	for view_size: Vector2 in [SCREEN, AREA]:
		var view := TreeView.new(map.bounds, view_size, _fit)
		view.set_zoom(0.0)
		var outside: Array[String] = []
		for id: String in map.centres:
			var box := map.rect(id)
			var shown := Rect2(view.to_screen(box.position), box.size * view.zoom)
			if not Rect2(Vector2.ZERO, view_size).encloses(shown):
				outside.append(id)
		check.call(
			is_equal_approx(view.zoom, view.fit_zoom()) and outside.is_empty(),
			"at zoom %.3f every node fits %s: %s" % [view.zoom, view_size, outside]
		)


## D-275 bar 1: zoom never goes past the default (text 24 px) nor out past the whole tree, by the
## wheel or by setting it.
func _check_view_zoom_clamp() -> void:
	var view := TreeView.new(_map(CROC).bounds, SCREEN, _fit)
	check.call(view.fit_zoom() < TreeView.DEFAULT_ZOOM, "the croc tree needs zooming out to fit")
	view.zoom_at(SCREEN * 0.3, 1000.0)
	check.call(is_equal_approx(view.zoom, TreeView.DEFAULT_ZOOM), "zoom in stops at the default")
	view.zoom_at(SCREEN * 0.7, 0.001)
	check.call(is_equal_approx(view.zoom, view.fit_zoom()), "zoom out stops at the whole tree")
	view.set_zoom(9.0)
	check.call(is_equal_approx(view.zoom, TreeView.DEFAULT_ZOOM), "set_zoom stops at the default")
	view.set_zoom(0.0)
	view.resize(SCREEN * 0.5)
	check.call(view.zoom >= view.fit_zoom() - 0.0001, "a smaller view keeps zoom inside its limits")


## D-275 bar 3: however far it pans, the tree never leaves the screen: where the tree is wider
## than the view the view stays over the tree, where it is narrower the tree stays centred.
func _check_view_pan_clamp() -> void:
	var map := _map(CROC)
	var view := TreeView.new(map.bounds, SCREEN, _fit)
	var bad: Array[String] = []
	var pushes: Array[Vector2] = [
		Vector2(1e6, 0), Vector2(-1e6, 0), Vector2(0, 1e6), Vector2(0, -1e6), Vector2(1e6, 1e6)
	]
	for push: Vector2 in pushes:
		view.pan_by(push)
		var seen := Rect2(view.to_tree(Vector2.ZERO), SCREEN / view.zoom)
		if not map.bounds.grow(0.01).encloses(seen):
			bad.append("pan %s shows %s past the tree %s" % [push, seen, map.bounds])
	view.look_at(Vector2(-1e6, 1e6))
	if not map.bounds.has_point(view.centre):
		bad.append("look_at leaves the centre at %s" % view.centre)
	view.set_zoom(0.0)
	view.pan_by(Vector2(5000, -5000))
	if view.centre.distance_to(map.bounds.get_center()) > 0.01:
		bad.append("zoomed out, the tree moves off centre to %s" % view.centre)
	check.call(bad.is_empty(), "the tree never leaves the screen: %s" % [bad])


## D-275 bar 2: the wheel zooms toward the cursor: the tree point under it stays under it.
func _check_view_zoom_cursor() -> void:
	var map := _map(CROC)
	var view := TreeView.new(map.bounds, SCREEN, _fit)
	view.set_zoom(0.5)
	view.look_at(map.bounds.get_center())
	var cursor := Vector2(1100, 600)
	var under := view.to_tree(cursor)
	view.zoom_at(cursor, 1.2)
	check.call(is_equal_approx(view.zoom, 0.6), "the wheel zooms by its step (%.3f)" % view.zoom)
	check.call(
		view.to_tree(cursor).distance_to(under) < 0.01,
		"the point under the cursor stays put (%s -> %s)" % [under, view.to_tree(cursor)]
	)
