extends SceneTree
## The tanks at work (D-066) at the game camera: a Behemoth croc stands at a crossing while tank
## columns drive in by road and deploy to firing posts round it. Clip-only overrides, so it all
## happens inside 18 s and inside the frame: columns call in from CLIP_SPAWN (not
## army.spawn_radius) every 1.6 s; the kaiju cannot fall. Everything else is the game's own data
## and code (the helicopters are today's, at their own call-in: none come in 18 s). Stills along
## the way; pair with --write-movie (ci_capture.sh --movie) for the clip.
## At each still the log gives every tank's drawn hull, turret and barrel outline in the still's
## own pixels (OUTLINE lines: frame, tank, part, x,y points: every voxel of the part's
## MultiMeshInstance through its own global transform, projected by the game camera of that
## frame) and its pose against its road and the kaiju (POSE lines, see _pose).
## --mode=fallback (capture and debug only, never the game's HUD): fixed cameras instead of the
## game's, first on the road the first column enters by, then on the tank that falls back first,
## with an on-screen m/s readout of it. --probe: the POSE lines only, every SHOT, no stills
## (runs headless).
## Needs a window and the no-focus override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_military.gd -- --out=<dir> [--seconds=18] [--mode=fallback]

const SHOTS: Array[int] = [300, 480, 600, 720, 750, 780, 840, 900, 960, 1050, 1060]
const PARTS: Array[String] = ["hull", "turret", "barrel"]
## Where columns call in from, metres from the kaiju (the game's is army.spawn_radius).
const CLIP_SPAWN := 44.0
## Where the kaiju stands: a crossing at the north end of the Behemoth city (the same spot as
## round 3's clip, so the critic compares like with like).
const CLIP_AT := Vector2(5, -50)  # south of the stage-2 bay's coast road (z -62, D-377)
## Mid-clip the kaiju strides east down the avenue at the tanks posted there (physics frames),
## so the take shows them fall back out of its reach and post again.
const WALK_FRAMES := Vector2i(540, 780)
const WALK := Vector2(1, 0)
## Fallback mode: the entry camera until this frame, then the camera on the falling-back tank.
const ENTRY_UNTIL := 520
## Fallback mode cameras: height and distance back (m) from what they watch, and the readout's
## averaging window (physics frames).
const WATCH_EYE := Vector3(0, 22, 26)
## The entry camera: how far toward the kaiju from where the first tank enters, and how high (m).
const ENTRY_EYE := Vector2(16, 26)
const PACE_WINDOW := 12
## How far along its road either way from a tank the KERB lines run (m).
const KERB_SPAN := 7.0

var _out := "user://military"
var _seconds := 18.0
var _mode := "game"
var _probe := false
var _frame := 0  # physics frames run (counted as they start, as the sim sees them)
var _rampage: Rampage
var _watch_cam: Camera3D
var _readout: Label
var _watched := -1  # the tank the fallback camera is on
var _trail: Array[Vector2] = []  # its positions, one per physics frame


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		if arg.begins_with("--mode="):
			_mode = arg.substr(7)
		if arg == "--probe":
			_probe = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {"claws": 1, "evolve1": 1}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 100000.0  # the clip watches the army: the kaiju must not fall mid-take
	var tier := Num.i(stats["size"])
	_rampage = Rampage.new()
	_rampage.setup(
		species, stats, CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0)), 1
	)
	_rampage.sim.kaiju_pos = CLIP_AT  # before the view is built, so it starts there
	_rampage.scripted = _input
	root.add_child(_rampage)
	await physics_frame
	var sim := _rampage.sim
	sim.army["spawn_radius"] = CLIP_SPAWN
	sim.army["start_interval"] = 1.6
	sim.army_units._spawn_timer = 0.3
	if _mode == "fallback":
		_watch_setup()
	physics_frame.connect(_tick)
	var shots := SHOTS.duplicate()
	var total := roundi(_seconds * 60.0)
	while _frame < total:
		if _probe:
			await physics_frame
		else:
			await RenderingServer.frame_post_draw  # what was drawn is what is measured
		if not shots.is_empty() and _frame >= shots[0]:
			var shot: int = shots.pop_front()
			if not _probe:
				var path := _out.path_join("military_%04d.png" % shot)
				root.get_viewport().get_texture().get_image().save_png(path)
				_outlines(shot)
			_poses(shot)
	quit()


## One physics frame starts (before the sim steps): count it; the fallback cameras follow.
func _tick() -> void:
	_frame += 1
	if _watch_cam != null:
		_watch_update()


## Prints every drawn tank's part outlines in the still's pixels: the convex hull of every voxel
## corner of the part's MultiMeshInstance3D, through that node's own global transform, projected
## by the camera that drew the frame (unproject_position works in the viewport's canvas size,
## 1920x1080 under the project's stretch: scaled to the still's pixels).
func _outlines(frame: int) -> void:
	var cam := root.get_viewport().get_camera_3d()
	var px := (
		Vector2(root.get_viewport().get_texture().get_size())
		/ root.get_viewport().get_visible_rect().size
	)
	print("STILL %d %dx%d drawn at frame %d" % [frame, px.x * 1920, px.y * 1080, _frame])
	for id: int in _rampage._tank_nodes:
		var node: TankModel = _rampage._tank_nodes[id]
		var at: Array[Node3D] = [node, node._turret, node._barrel]
		for k: int in PARTS.size():
			var pts := PackedVector2Array()
			for corner: Vector3 in _voxel_corners(_part_mesh(at[k])):
				pts.append(cam.unproject_position(corner) * px)
			var line := "OUTLINE %d %d %s" % [frame, id, PARTS[k]]
			for q: Vector2 in Geometry2D.convex_hull(pts):
				line += " %.0f,%.0f" % [q.x, q.y]
			print(line)


## The voxels a part node draws (its own MultiMeshInstance3D child).
static func _part_mesh(node: Node3D) -> MultiMeshInstance3D:
	for child: Node in node.get_children():
		if child is MultiMeshInstance3D:
			return child
	return null


## Every drawn voxel's eight corners, in the world: instance transform x the cube's AABB, through
## the node's global transform.
static func _voxel_corners(mmi: MultiMeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mm := mmi.multimesh
	var box := mm.mesh.get_aabb()
	for i: int in mm.instance_count:
		var xf := mmi.global_transform * mm.get_instance_transform(i)
		for k: int in 8:
			out.append(xf * box.get_endpoint(k))
	return out


## One POSE line per tank: where it is against its road and the kaiju, in the world and on screen.
## off = hull axis off the road's axis (deg, world; least of the roads at a crossing), lat = hull
## centre off the road's centre line (m), kerb = how far the outer track edge lies past the
## carriageway's edge (m, + = over the kerb), body = the hull's nearest corner or side to the
## kaiju's body edge (tail root to snout, body_radius wide; m), scr = hull axis and road axis on
## screen (deg).
func _poses(frame: int) -> void:
	var sim := _rampage.sim
	var convoy := sim.army_units.convoy
	var graph := convoy.graph
	var cam := root.get_viewport().get_camera_3d()
	var hull: Array = convoy.cfg["hull"]
	var half := Vector2(Num.f(hull[0]), Num.f(hull[1])) * 0.5
	var radius := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	var head := convoy.posts.head()
	for tank: RampageSim.Tank in sim.tanks:
		var r: ConvoyRoute = convoy.routes.get(tank.id)
		var u := convoy.front(tank.id)
		if r == null or u == Vector2.ZERO:
			continue
		var e := graph.road_under(tank.pos, r.edge)
		var axis := graph.axis(e)
		var a := graph.nodes[graph.edge_a[e]]
		var lat := (tank.pos - a).dot(axis.orthogonal())
		var kerb := -INF
		var body := INF
		for c: Vector2 in _hull_corners(tank.pos, u, half):
			kerb = maxf(kerb, absf((c - a).dot(axis.orthogonal())) - graph.edge_half[e])
			var q := Geometry2D.get_closest_point_to_segment(c, sim.kaiju_pos, head)
			body = minf(body, c.distance_to(q) - radius)
		var off := rad_to_deg(acos(clampf(absf(u.dot(axis)), 0.0, 1.0)))
		for k: int in graph.roads_at(graph.cell_of(tank.pos)):
			if graph.on_edge(tank.pos, k):
				var dk := rad_to_deg(acos(clampf(absf(u.dot(graph.axis(k))), 0.0, 1.0)))
				off = minf(off, dk)
		var centre := Geometry2D.get_closest_point_to_segment(tank.pos, sim.kaiju_pos, head)
		_kerbs(frame, tank, e)
		print(
			(
				(
					"POSE %d tank %d at %.1f,%.1f road %d half %.1f off %.1f deg lat %+.2f kerb %+.2f"
					% [
						frame,
						tank.id,
						tank.pos.x,
						tank.pos.y,
						e,
						graph.edge_half[e],
						off,
						lat,
						kerb
					]
				)
				+ (
					" body %.1f (centre %.1f) %s scr hull %.0f road %.0f at %s"
					% [
						body,
						tank.pos.distance_to(centre) - radius,
						"back" if r.retreating else ("park" if r.path.is_empty() else "drive"),
						_screen_deg(cam, tank.pos, u),
						_screen_deg(cam, tank.pos, axis),
						cam.unproject_position(Vector3(tank.pos.x, 1.0, tank.pos.y)) * _px()
					]
				)
			)
		)


## The tank's road by it: left kerb, centre line, right kerb, in still pixels (KERB lines).
func _kerbs(frame: int, tank: RampageSim.Tank, e: int) -> void:
	var graph := _rampage.sim.army_units.convoy.graph
	var cam := root.get_viewport().get_camera_3d()
	var axis := graph.axis(e)
	var half := graph.edge_half[e]
	var a := graph.nodes[graph.edge_a[e]]
	var mid := a + axis * (tank.pos - a).dot(axis)  # on the centre line, abreast of the tank
	var line := "KERB %d %d" % [frame, tank.id]
	for side: float in [-1.0, 0.0, 1.0]:
		for along: float in [-KERB_SPAN, KERB_SPAN]:
			var g := mid + axis * along + axis.orthogonal() * half * side
			var q := cam.unproject_position(Vector3(g.x, 0.05, g.y)) * _px()
			line += " %.0f,%.0f" % [q.x, q.y]
	print(line)


## Canvas (unproject) to still pixels; 1 when probing headless (no real texture).
func _px() -> Vector2:
	if _probe:
		return Vector2.ONE
	return (
		Vector2(root.get_viewport().get_texture().get_size())
		/ root.get_viewport().get_visible_rect().size
	)


static func _hull_corners(p: Vector2, u: Vector2, half: Vector2) -> Array[Vector2]:
	var s := u.orthogonal()
	var out: Array[Vector2] = []
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			out.append(p + u * half.x * sx + s * half.y * sy)
	return out


## The screen angle (deg, 0 = right, + = down the screen) of direction d through p, 1 m up.
static func _screen_deg(cam: Camera3D, p: Vector2, d: Vector2) -> float:
	var a := cam.unproject_position(Vector3(p.x - d.x * 2.5, 1.0, p.y - d.y * 2.5))
	var b := cam.unproject_position(Vector3(p.x + d.x * 2.5, 1.0, p.y + d.y * 2.5))
	var deg := rad_to_deg((b - a).angle())
	return wrapf(deg, -90.0, 90.0)


## Fallback mode: a fixed camera of our own and the readout (capture only).
func _watch_setup() -> void:
	_watch_cam = Camera3D.new()
	_watch_cam.fov = 45.0
	root.add_child(_watch_cam)
	_watch_cam.current = true
	var layer := CanvasLayer.new()
	_readout = Label.new()
	_readout.position = Vector2(40, 110)  # below the HUD's bars
	_readout.add_theme_font_size_override("font_size", 44)
	_readout.add_theme_color_override("font_outline_color", Color.BLACK)
	_readout.add_theme_constant_override("outline_size", 10)
	layer.add_child(_readout)
	root.add_child(layer)


## The entry camera looks up the first column's road from the kaiju's side, at where it
## enters; after ENTRY_UNTIL the camera settles on the first tank falling back (and stays put)
## and reads out its pace.
func _watch_update() -> void:
	var sim := _rampage.sim
	var convoy := sim.army_units.convoy
	if _frame < ENTRY_UNTIL:
		if _frame == 2 or (_watched < 0 and not sim.tanks.is_empty()):
			var first: RampageSim.Tank = sim.tanks[0] if not sim.tanks.is_empty() else null
			var at := first.pos if first != null else CLIP_AT
			_watched = first.id if first != null else -1
			var toward := (CLIP_AT - at).normalized()  # the column drives in toward the camera
			var ground := Vector3(at.x, 0.0, at.y)
			_watch_cam.position = ground + Vector3(toward.x, 0, toward.y) * ENTRY_EYE.x
			_watch_cam.position.y = ENTRY_EYE.y
			_watch_cam.look_at(ground)
		_readout.text = "column entry by road  (capture view, frame %d)" % _frame
		return
	if _frame == ENTRY_UNTIL:
		_watched = -1
		_trail.clear()
	if _watched < 0:
		for tank: RampageSim.Tank in sim.tanks:
			var r: ConvoyRoute = convoy.routes.get(tank.id)
			if r != null and r.retreating:
				_watched = tank.id
				_aim(tank.pos)
				break
		_readout.text = "waiting for a tank to fall back  (frame %d)" % _frame
		return
	var pos := Vector2(INF, INF)
	var backing := false
	for tank: RampageSim.Tank in sim.tanks:
		if tank.id == _watched:
			pos = tank.pos
			var r: ConvoyRoute = convoy.routes.get(tank.id)
			backing = r != null and r.retreating
	if pos.x == INF:
		_readout.text = "tank %d gone  (frame %d)" % [_watched, _frame]
		return
	_trail.append(pos)
	var pace := 0.0
	if _trail.size() > PACE_WINDOW:
		pace = pos.distance_to(_trail[_trail.size() - 1 - PACE_WINDOW]) * 60.0 / PACE_WINDOW
	_readout.text = (
		"tank %d  %s  %.1f m/s  (capture view, frame %d)"
		% [_watched, "falling back" if backing else "holding", pace, _frame]
	)


## Puts the fixed camera over `at`, looking at it, the kaiju's side of it in view.
func _aim(at: Vector2) -> void:
	var ground := Vector3(at.x, 0.0, at.y)
	_watch_cam.position = ground + WATCH_EYE
	_watch_cam.look_at(ground)


## The kaiju stands side-on to the camera, and strides at the tanks mid-clip (walk).
func _input(sim: RampageSim) -> Dictionary:
	sim.facing = Vector2(1, 0)
	return {"move": walk(_frame)}


## The clip's move at physics frame `frame`.
static func walk(frame: int) -> Vector2:
	return WALK if frame >= WALK_FRAMES.x and frame < WALK_FRAMES.y else Vector2.ZERO
