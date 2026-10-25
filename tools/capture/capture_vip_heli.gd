extends SceneTree
## The leader's escape helicopter (VipView, D-149) through the REAL game camera, which follows the
## kaiju. The scene is staged as a player would play it: the kaiju is walked up the avenue until a
## mid-rise stands about PAD_NEAR m ahead of it, turned to face it, and the leader's seeded
## lift-off is called in on that roof. The lap closes on the pad, where the dash begins, so the
## leader leaves inside breath reach, in the kaiju's frame; the breath fires once the dash is under
## way. The kaiju's stomps are held off while the leader is up and the breath's aim wedge is hidden
## (a capture only; the sim and the camera are the game's).
## Every frame it prints measurements ("M ..."): the leader's width in px at 4K (the 1080p width x
## 2), the brightness of its body voxels against the lit windows, the cone against the leader on
## the kill frame, and the wreck's body, fall and parachute on screen down to the ground.
## Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/vip.avi \
##     --script tools/capture/capture_vip_heli.gd -- --out=<dir> --tier=2 --run=1

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 120
## The roof is this far ahead of the kaiju (m, min and max; the breath leaves from the snout, about
## 13 m ahead, and the body breaks what is nearer) and within this bearing of its heading.
const PAD_NEAR := [19.0, 23.0]
const PAD_BEARING_DEG := 35.0
const TURN_ONLY := 0.06
const FACING_OK := 0.12
## Frames with no building falling before the lift-off is called in.
const SETTLE_QUIET := 180
## Seconds filmed after the leader is down, and the longest the shot runs after lift-off.
const AFTER := 5.0
const LONGEST := 20.0
## Frames kept before lift-off in the trimmed clip, printed as the trim point.
const LEAD_FRAMES := 90
const LEVELS := [
	{"claws": 2, "hide": 2},
	{"claws": 5, "hide": 5, "rage": 3, "evolve1": 1},
	{"claws": 5, "hide": 5, "rage": 5, "evolve1": 1, "tail": 3, "sig_power": 3, "evolve2": 1}
]

var _out := "user://vip_heli"
var _rampage: Rampage
var _view: VipView
var _lift_frame := 0
var _down_frame := -1
var _last_aim := {}
var _step := 0
var _phase := "walk"
var _pad_at := Vector2.ZERO
var _strip_seen: NewsTicker
var _prev: Image


func _initialize() -> void:
	var a := Kit.args({"out": _out, "run": 1, "tier": 2})
	_out = str(a["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(Num.i(a["run"]), Num.i(a["tier"]))


func _run(run: int, tier: int) -> void:
	await process_frame
	PlayerSettings.controls_seen = true  # no first-run controls card over the shot
	var levels: Dictionary = LEVELS[tier - 1]
	var stats := Kit.stats("reptilian", levels)
	stats["run_seconds"] = 600.0  # the real run-timer HUD counts down from here in the shot
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	_rampage = Kit.rampage("reptilian", stats, run, layout)
	_rampage.scripted = _input
	root.add_child(_rampage)
	await _rampage.wait_loaded()
	while _rampage.sim.emerge.active:
		await physics_frame
	await Kit.frames(self, SETTLE)
	for node: Node in _rampage.get_children():
		if node is BreathAim:
			node.set_physics_process(false)
			(node as Node3D).visible = false
	_view = _rampage.find_children("*", "VipView", true, false)[0]
	var sim := _rampage.sim
	await _stage(sim)
	process_frame.connect(_measure)
	var left := LONGEST
	while left > 0.0 and (sim.vip.flying() or _down_frame < 0 and sim.vip.state != "escaped"):
		await physics_frame
		left -= 1.0 / 60.0
	await Kit.ticks(self, roundi(AFTER * 60.0))
	print("state %s after %.1f s, rubble %.1f" % [sim.vip.state, sim.vip.flight_t, sim.rubble])
	print("TRIM from %.2f s of the movie" % (maxf(0.0, _lift_frame - LEAD_FRAMES) / 60.0))
	quit()


## Walks the kaiju up the avenue until a roof is ahead, turns it to face it, calls the lift-off in.
func _stage(sim: RampageSim) -> void:
	var pad := -1
	var walked := 0
	while pad < 0 and walked < 60 * 40:
		pad = _roof_ahead(sim)
		await physics_frame
		walked += 1
	var b := sim.buildings[pad]
	_pad_at = Vector2(b.x, b.z)
	var gap := _pad_at.distance_to(sim.kaiju_pos)
	sim.vip.cfg["pad_height"] = [b.height, b.height]
	sim.vip.cfg["pad_range"] = [gap - 0.6, gap + 0.6]
	_phase = "turn"
	var turned := 0
	while turned < 60 * 4 and absf(sim.facing.angle_to(_pad_at - sim.kaiju_pos)) > FACING_OK:
		await physics_frame
		turned += 1
	_phase = "wait"
	var quiet := 0  # nothing of the walk is still falling or settling when it lifts off
	while quiet < SETTLE_QUIET:
		quiet = quiet + 1 if sim.falls.is_empty() else 0
		await physics_frame
	var gap_now := _pad_at.distance_to(sim.kaiju_pos)  # the kaiju drifted a little while turning
	sim.vip.cfg["pad_range"] = [gap_now - 0.6, gap_now + 0.6]
	sim.vip._spawn_at = 0.0
	while not sim.vip.flying():
		await physics_frame
	_phase = "fly"
	_lift_frame = Engine.get_frames_drawn()
	print("pad %s h%d, %.1f ahead; lift-off at %s" % [_pad_at, b.height, gap, sim.vip.pos])


## The index of a pad-eligible roof PAD_NEAR ahead of the kaiju (within PAD_BEARING_DEG of its
## facing), or -1.
func _roof_ahead(sim: RampageSim) -> int:
	var heights: Array = sim.vip.cfg["pad_height"]
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var tall := b.height >= Num.i(heights[0]) and b.height <= Num.i(heights[1])
		var to := Vector2(b.x, b.z) - sim.kaiju_pos
		var ahead := absf(sim.facing.angle_to(to)) < deg_to_rad(PAD_BEARING_DEG)
		if tall and b.in_arena and b.frame.alive_count > 0 and ahead:
			if to.length() >= Num.f(PAD_NEAR[0]) and to.length() <= Num.f(PAD_NEAR[1]):
				return i
	return -1


## Walking north, then turning to face the roof, then breathing at the leader once it dashes.
func _input(sim: RampageSim) -> Dictionary:
	match _phase:
		"walk":
			sim._stomp_timer = 9.0  # a walk with no stomps, so the roofs ahead are untouched
			return {"move": Vector2(0.0, -1.0)}
		"turn":
			sim._stomp_timer = 9.0  # the roof ahead must still stand when the leader lifts off
			return {"move": (_pad_at - sim.kaiju_pos).normalized() * TURN_ONLY}
		"wait":
			sim._stomp_timer = 9.0
			return {}
		"fly":
			if sim.vip.flying():
				sim._stomp_timer = 9.0  # the kaiju's own stomps never reach the low leader
				return _breath(sim)
	return {}


func _breath(sim: RampageSim) -> Dictionary:
	var to := sim.vip.pos - sim.kaiju_pos
	var aim := BreathCone.of(sim)
	var angle := absf(sim.facing.angle_to(to))
	_last_aim = {
		"dist": to.length(),
		"reach": sim.ability_reach(),
		"angle": rad_to_deg(angle),
		"half": rad_to_deg(Num.f(aim["half_angle"]))
	}
	var in_cone := angle < Num.f(aim["half_angle"]) and to.length() < sim.ability_reach()
	# (the dash has begun once the leader has picked the edge point it runs to)
	var fire := in_cone and sim.ability_ready_in <= 0.0 and sim.vip._exit.x < INF
	return {"move": to.normalized() * TURN_ONLY, "signature": fire}


## Per rendered frame: the measurements.
func _measure() -> void:
	_step += 1
	var sim := _rampage.sim
	for event: Dictionary in sim.events:
		if str(event["type"]) == "vip_killed" and _down_frame < 0:
			_down_frame = _step
			print(
				"M KILL flight %.1f s by %s: cone %s" % [sim.vip.flight_t, event["by"], _last_aim]
			)
	if _step % 20 == 0 and sim.vip.flying() and sim.vip.flight_t >= 4.0:
		print("M AIM t %.1f ready %.1f %s" % [sim.vip.flight_t, sim.ability_ready_in, _last_aim])
	var cam := root.get_viewport().get_camera_3d()
	var shot := root.get_texture().get_image() if _step % 30 == 0 or _down_frame == _step else null
	if _view._model != null:
		_leader(cam, shot)
	if _down_frame >= 0:
		_wreck(cam, _step - _down_frame)
	if shot != null:
		_edge_streak(shot)
	_strip_size()
	_breath_between(cam)


## The leader's width in px (1080p, and x2 for 4K) and its body voxels' brightness against the
## windows (the 99.5th percentile of the frame's luminance outside it).
func _leader(cam: Camera3D, shot: Image) -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var points: Array[Vector2] = []
	for mmi: Node in _view._model.find_children("*", "MultiMeshInstance3D", true, false):
		var part := mmi as MultiMeshInstance3D
		var box := part.get_aabb()
		for corner: int in 8:
			var world := part.global_transform * (box.position + box.size * _corner(corner))
			if not cam.is_position_behind(world):
				var px := cam.unproject_position(world)
				low = low.min(px)
				high = high.max(px)
		if part == _view._model.get_child(0) and shot != null:
			for i: int in mini(part.multimesh.instance_count, 400):
				var at := part.global_transform * part.multimesh.get_instance_transform(i).origin
				points.append(cam.unproject_position(at))
	var width := high.x - low.x
	if shot == null:
		return
	var scale := Vector2(shot.get_size()) / Vector2(root.get_visible_rect().size)
	var own := 0.0
	var own_max := 0.0
	var seen := 0
	for p: Vector2 in points:
		var q := Vector2i(p * scale)
		if Rect2i(Vector2i.ZERO, shot.get_size()).has_point(q):
			var l := shot.get_pixelv(q).get_luminance()
			own += l
			own_max = maxf(own_max, l)
			seen += 1
	var lums := PackedFloat32Array()
	for y: int in range(0, shot.get_height(), 6):
		for x: int in range(0, shot.get_width(), 6):
			var q := Vector2(x, y) / scale
			if q.x < low.x or q.x > high.x or q.y < low.y or q.y > high.y:
				lums.append(shot.get_pixel(x, y).get_luminance())
	lums.sort()
	var windows := lums[int(lums.size() * 0.995)]
	print(
		(
			"M LEADER t %.1f width %.0f px@1080p = %.0f px@4K, body lum mean %.2f max %.2f, windows %.2f"
			% [sim_t(), width, width * 2.0, own / maxf(1, seen), own_max, windows]
		)
	)


func sim_t() -> float:
	return _rampage.sim.vip.flight_t


func _corner(i: int) -> Vector3:
	return Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)


## The wreck's body piece, the spinning fall and the first parachute on screen, every 6th frame.
func _wreck(cam: Camera3D, frames: int) -> void:
	if frames % 6 != 0 or frames > 60 * 8:
		return
	var parts: Array[String] = []
	var wreck: HeliWreck = _view._wreck
	for piece: HeliDebris.Piece in wreck._debris._pieces.slice(0, 1):
		parts.append(_at("body", cam, piece.node))
	for fall: HeliWreck.Fall in wreck._falling.values():
		parts.append(_at("fall", cam, fall.node))
	for chute: HeliWreck.Chute in wreck._crew.slice(0, 1):
		parts.append(_at("chute", cam, chute.node))
	print("M WRECK +%.2f s %s" % [frames / 60.0, " | ".join(parts)])


func _at(label: String, cam: Camera3D, node: Node3D) -> String:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return label + " gone"
	var world := node.global_position
	return "%s px %s h %.1f" % [label, cam.unproject_position(world).round(), world.y]


## A bright yellow streak hugging the left edge (the critic's finding 5).
func _edge_streak(shot: Image) -> void:
	var hot := 0
	for y: int in range(0, shot.get_height(), 2):
		for x: int in range(0, 60, 2):
			var c := shot.get_pixel(x, y)
			if c.r > 0.9 and c.g > 0.7 and c.b < 0.35:
				hot += 1
	if hot > 10:
		print("M EDGE-STREAK frame %d: %d yellow px in the left 60 px" % [_step, hot])


## The headline strip's text size, once per strip: the font's size and the line it draws.
func _strip_size() -> void:
	var strip := _view._strip
	if strip == null or strip == _strip_seen:
		return
	_strip_seen = strip
	var label: Label = strip._crawl
	var size := label.get_theme_font_size("font_size")
	var font := label.get_theme_font("font")
	print(
		(
			"M STRIP font %d px, line %.0f px, label %.0f x %.0f px at %s (1080p viewport)"
			% [
				size,
				font.get_height(size),
				label.size.x,
				label.size.y,
				root.get_visible_rect().size
			]
		)
	)


## Is the breath on screen between his mouth and the leader? On the kill frame and the 8 after it:
## the mouth's and the leader's screen points, and how much of the line between them changed
## against the frame before (the breath's own pixels; the aim wedge and stomps are off).
func _breath_between(cam: Camera3D) -> void:
	var shot := root.get_texture().get_image()
	var sim := _rampage.sim
	var frames := _step - _down_frame if _down_frame >= 0 else -1
	if _prev != null and frames >= 0 and frames <= 8:
		var bs := sim.body_scale()
		var snout: Array = sim.city["breath_snout_ahead"]
		var ahead := Num.f(snout[mini(sim.size_tier(), snout.size() - 1)]) * bs
		var m := sim.kaiju_pos + sim.facing * ahead
		var mouth := cam.unproject_position(Vector3(m.x, 4.0 * bs, m.y))
		var h := sim.vip.pos
		var heli := cam.unproject_position(Vector3(h.x, sim.vip.altitude(), h.y))
		var scale := Vector2(shot.get_size()) / Vector2(root.get_visible_rect().size)
		var changed := 0
		for i: int in 40:
			var q := Vector2i(mouth.lerp(heli, (i + 0.5) / 40.0) * scale)
			if Rect2i(Vector2i.ZERO, shot.get_size()).has_point(q):
				var d := absf(
					shot.get_pixelv(q).get_luminance() - _prev.get_pixelv(q).get_luminance()
				)
				changed += 1 if d > 0.12 else 0
		var verdict := "YES" if changed >= 12 else "NO"
		print(
			(
				"M BREATH kill+%d: mouth px %s, leader px %s, %d of 40 points on the line changed -> %s"
				% [frames, mouth.round(), heli.round(), changed, verdict]
			)
		)
	_prev = shot
