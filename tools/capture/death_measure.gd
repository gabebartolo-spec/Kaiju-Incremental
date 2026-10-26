extends RefCounted
## Measures his stone (capture_death.gd --measure): the director's "i dont like the pale blocks
## that come out of the explosion" as a number. In three paused frames (just before the shatter,
## the debris and shards in flight, and landed) it takes the mean luminance of the pixels the stone
## body, then his debris, then his shards cover, and prints each against the body's. A group's
## pixels are found by painting it unshaded magenta in the same paused frame (the pixels that turn
## magenta, one pixel in from the edge); the real frame is read with its own materials back.
## Luminance is the shown sRGB colour's (Color.get_luminance). Saves the frames to the folder.

## The shatter happens at stagger_s + stone_s; the first sample is this much before it.
const BEFORE_SHATTER := 0.05
## Seconds after the shatter the flash has gone (death.look burst_s) and the pieces are in flight.
const IN_FLIGHT := 0.7
## Seconds after the shatter when every shard is down.
const LANDED := 2.0
const MAGENTA := Color(1.0, 0.0, 1.0)

var _tree: SceneTree
var _rampage: Rampage
var _out: String
var _paint: StandardMaterial3D
var _body_lum := 0.0


func _init(tree: SceneTree, rampage: Rampage, out: String) -> void:
	_tree = tree
	_rampage = rampage
	_out = out
	DirAccess.make_dir_recursive_absolute(out)
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.albedo_color = MAGENTA


func run() -> void:
	var sim := _rampage.sim
	var cfg: Dictionary = Content.section("death")
	var shatter := Num.f(cfg["stagger_s"]) + Num.f(cfg["stone_s"])
	var kaiju: KaijuModel = _rampage.get("_kaiju")
	while sim.death.t < shatter - BEFORE_SHATTER:
		await _tree.physics_frame
	_body_lum = await _sample("body", _geometry(kaiju))
	var view: DeathView = _rampage.find_child("DeathView", false, false)
	while sim.death.since_shatter < IN_FLIGHT or not view.burst:
		await _tree.physics_frame
	await _group("flight", view)
	while sim.death.since_shatter < LANDED:
		await _tree.physics_frame
	await _group("landed", view)


## Debris, then shards, at one moment.
func _group(label: String, view: DeathView) -> void:
	var debris: Node = view.get("_debris")
	var shards: Node = view.get("_shards")
	await _sample("%s_debris" % label, _geometry(debris))
	await _sample("%s_shards" % label, _geometry(shards))


## Pauses the game, finds `nodes`' pixels and reads the frame's luminance there; unpauses.
## Returns the mean luminance (-1 with none on screen).
func _sample(label: String, nodes: Array[GeometryInstance3D]) -> float:
	_tree.paused = true
	var was: Array[Material] = []
	for node: GeometryInstance3D in nodes:
		was.append(node.material_override)
		node.material_override = _paint
	var mask := await _frame()
	for i: int in nodes.size():
		nodes[i].material_override = was[i]
	var real := await _frame()
	_tree.paused = false
	var sum := 0.0
	var count := 0
	for y: int in range(1, real.get_height() - 1):
		for x: int in range(1, real.get_width() - 1):
			if _is_paint(mask, x, y) and _is_paint(mask, x - 1, y) and _is_paint(mask, x + 1, y):
				if _is_paint(mask, x, y - 1) and _is_paint(mask, x, y + 1):
					sum += real.get_pixel(x, y).get_luminance()
					count += 1
	real.save_png("%s/%s.png" % [_out, label])
	mask.save_png("%s/%s_mask.png" % [_out, label])
	var mean := sum / count if count > 0 else -1.0
	var ratio := mean / _body_lum if _body_lum > 0.0 and label != "body" else 1.0
	print(
		(
			"MEASURE %s: %d px, mean luminance %.4f, %.0f%% of the body"
			% [label, count, mean, ratio * 100.0]
		)
	)
	return mean


func _is_paint(img: Image, x: int, y: int) -> bool:
	var c := img.get_pixel(x, y)
	# The tonemap and glow wash the magenta towards (0.94, 0.45, 0.91): strong red and blue, green
	# well under both. Nothing else in the game's frames is (checked: 0 pixels in the real frames).
	return c.r > 0.7 and c.b > 0.7 and c.g < 0.62 * minf(c.r, c.b)


## Two drawn frames later (the override is drawn), the window's picture.
func _frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return _tree.root.get_texture().get_image()


## Every drawn node under `root` (itself included).
func _geometry(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var todo: Array[Node] = [root]
	while not todo.is_empty():
		var node: Node = todo.pop_back()
		if node is GeometryInstance3D and (node as GeometryInstance3D).is_visible_in_tree():
			out.append(node as GeometryInstance3D)
		todo.append_array(node.get_children())
	return out
