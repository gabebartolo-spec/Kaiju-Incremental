extends RefCounted
## The run intro (director 2026-10-20 #11, research 20): the whole intro hands over within 3 s,
## the short cut within its "short_seconds", both show the head breaking the surface with the roar,
## the camera ends exactly on the gameplay camera (no pop), and a real key press skips it by
## running the same sim ticks faster, so a skipped run and an unskipped one are the same run from
## the handover on (R 20.2-20.4). Seeded and clock-free: the city, the army and the rise are pinned
## and every check counts physics frames.

const FlowIntroMain := preload("res://tests/lib/flow_intro_main.gd")
const FRAME_CAP := 60 * 10
## Frames into the rise the skip key is pressed (under the water still, before the break).
const SKIP_AT := 20
## Live frames played after the handover before the two runs are compared.
const AFTER := 45
const FPS := 60.0
## The camera at the handover lies this close to the gameplay camera (share of its offset).
const POP_SHARE := 0.02
## From the break to JERK_AFTER frames past the handover, the camera's frame-to-frame step changes
## by at most JERK_SHARE of its offset per frame of camera time (no stutter at the hand-over, no
## pop at the break): the short cut runs n sim ticks a frame, so a smooth move there changes n^2
## times as fast and its change is divided by n^2.
const JERK_SHARE := 0.01
const JERK_AFTER := 30
## The intro's last frame lies this close to the gameplay camera it hands over to (the lead's brief
## 2026-10-26: within 0.1 m and 0.5 degrees): eye (m), aim and field of view (degrees).
const HAND_METRES := 0.1
const HAND_DEGREES := 0.5


static func run(tree: SceneTree, check: Callable) -> void:
	await FlowIntroMain.run(tree, check)  # which intro Main picks, from a real save
	var full := await _play(tree, true, -1)
	var skipped := await _play(tree, true, SKIP_AT)
	var short := await _play(tree, false, -1)
	var cfg: Dictionary = Content.section("intro")
	var short_cap := roundi(Num.f(cfg["short_seconds"]) * FPS) + 2
	(
		check
		. call(
			Num.i(full["handover"]) <= 180 and Num.i(short["handover"]) <= short_cap,
			(
				"the whole intro hands over on frame %d (<= 180, 3 s), the short cut on frame %d (<= %d)"
				% [full["handover"], short["handover"], short_cap]
			)
		)
	)
	for r: Dictionary in [full, short]:
		(
			check
			. call(
				Num.i(r["broke"]) > 1 and Num.i(r["broke"]) < Num.i(r["handover"]) and r["roared"],
				(
					(
						"%s intro: the head breaks the surface on frame %d, in shot, before the handover"
						+ " (%d), and he roars on it: %s"
					)
					% [r["name"], r["broke"], r["handover"], r["roared"]]
				)
			)
		)
		(
			check
			. call(
				Num.f(r["jerk"]) <= JERK_SHARE,
				(
					(
						"%s intro: from the break to %d frames past the handover the camera's step changes by"
						+ " at most %.4f of its offset a frame (<= %.2f; worst on frame %d)"
					)
					% [r["name"], JERK_AFTER, r["jerk"], JERK_SHARE, r["jerk_at"]]
				)
			)
		)
		check.call(
			Num.f(r["pop"]) <= POP_SHARE,
			(
				(
					"%s intro: at the handover the camera is %.3f of its offset from the gameplay"
					+ " camera (<= %.2f)"
				)
				% [r["name"], r["pop"], POP_SHARE]
			)
		)
	for r: Dictionary in [full, skipped, short]:
		var hand: Array = r["hand"]
		check.call(
			hand[0] <= HAND_METRES and hand[1] <= HAND_DEGREES and hand[2] <= HAND_DEGREES,
			(
				(
					"%s intro: its last frame is %.4f m, %.4f deg of aim and %.4f deg of fov from"
					+ " the gameplay camera (<= %.1f m, %.1f deg)"
				)
				% [r["name"], hand[0], hand[1], hand[2], HAND_METRES, HAND_DEGREES]
			)
		)
	check.call(
		Num.i(skipped["handover"]) < Num.i(full["handover"]) - 60,
		(
			"a key press on frame %d skips: handover on frame %d, not %d"
			% [SKIP_AT, skipped["handover"], full["handover"]]
		)
	)
	check.call(
		skipped["state"] == full["state"] and short["state"] == full["state"],
		(
			"skipped, short and whole intros are the same run %d frames after the handover (%s)"
			% [AFTER, full["state"]]
		)
	)


static func _rampage(full: bool) -> Rampage:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.full_intro = full
	rampage.setup(species, stats, layout, 0)
	rampage.autoplay_signature = false
	return rampage


## One run, walking into the city from the handover on; skip_at >= 0 presses Space on that frame.
static func _play(tree: SceneTree, full: bool, skip_at: int) -> Dictionary:
	var rampage := _rampage(full)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {"move": Vector2(0.3, -1.0)}
	tree.root.add_child(rampage)
	var sim := rampage.sim
	var out := {"name": "whole" if full else "short", "handover": -1, "broke": -1, "pop": INF}
	out["roared"] = false
	out["jerk"] = 0.0
	out["jerk_at"] = -1
	var path: Array[Vector3] = []
	var frame := 0
	var live := 0
	while live < AFTER and frame < FRAME_CAP:
		if frame == skip_at:
			var key := InputEventKey.new()
			key.keycode = KEY_SPACE
			key.pressed = true
			tree.root.push_input(key)
		await tree.physics_frame
		await tree.process_frame  # the camera is placed in _process (one a frame: --fixed-fps)
		frame += 1
		if Num.i(out["broke"]) < 0 and sim.emerge.surfaced:
			out["broke"] = frame
			out["roared"] = _roaring(rampage)
		if Num.i(out["handover"]) < 0 and not sim.emerge.active:
			out["handover"] = frame
			out["pop"] = _pop(rampage)
		if not sim.emerge.active:
			live += 1
		if Num.i(out["broke"]) >= 0 and live <= JERK_AFTER and skip_at < 0:
			path.append(rampage._camera.global_position)
			var n := Num.f(rampage._rise.intro.get("_rate")) if sim.emerge.active else 1.0
			_jerk(out, path, rampage._follow.offset.length() * n * n, frame)
	out["hand"] = _hand(rampage._rise)
	if skip_at >= 0:
		out["name"] = "skipped"
	out["state"] = (
		"at %s, facing %s, clock %.3f, hp %.1f"
		% [sim.kaiju_pos.snappedf(0.001), sim.facing.snappedf(0.001), sim.time_left, sim.hp]
	)
	rampage.queue_free()
	await tree.process_frame
	return out


## Whether a roar is playing under the rampage (Sfx.roar's player).
static func _roaring(rampage: Rampage) -> bool:
	for p: Node in rampage.find_children("*", "AudioStreamPlayer", false, false):
		var player := p as AudioStreamPlayer
		if player.stream != null and player.stream.resource_path.ends_with("roar.ogg"):
			return true
	return false


## The intro's last shot against the gameplay camera it hands over to (RampageRise.play_view and
## shot_view, both kept from the last frame the rise ran): [eye metres, aim degrees, fov degrees].
static func _hand(rise: RampageRise) -> Array[float]:
	var play := rise.play_view
	var shot := rise.shot_view
	if shot.is_empty():
		return [INF, INF, INF]
	var p_eye: Vector3 = play["eye"]
	var s_eye: Vector3 = shot["eye"]
	var p_aim: Vector3 = play["aim"]
	var s_aim: Vector3 = shot["aim"]
	var p_dir := (p_aim - p_eye).normalized()
	var s_dir := (s_aim - s_eye).normalized()
	var fov := absf(Num.f(shot["fov"]) - Num.f(play["fov"]))
	return [s_eye.distance_to(p_eye), rad_to_deg(s_dir.angle_to(p_dir)), fov]


## How far the camera is from the gameplay camera (CameraFollow's eye, which the intro hands over
## to), as a share of its offset's length.
static func _pop(rampage: Rampage) -> float:
	var follow: CameraFollow = rampage._follow
	var cam: Camera3D = rampage._camera
	return cam.global_position.distance_to(follow.eye()) / follow.offset.length()


## The change in the camera's step from the frame before (second difference) as a share of
## `scale`; keeps the worst in out["jerk"] and its frame in out["jerk_at"].
static func _jerk(out: Dictionary, path: Array[Vector3], scale: float, frame: int) -> void:
	var n := path.size()
	if n < 3:
		return
	var jerk := (path[n - 1] - 2.0 * path[n - 2] + path[n - 3]).length() / scale
	if jerk > Num.f(out["jerk"]):
		out["jerk"] = jerk
		out["jerk_at"] = frame
