extends SceneTree
## Helicopter method B, a look test for the director (D-066, LEAD 2026-10-19): the camera pulls
## back to PULL x its distance while a helicopter pair is up and eases back when none is. The
## pair flies this branch's roof-cleared flight (rotor 4 m over the roofs), and its frame model
## (air.view zoom) pulls with the camera. The pull lives in this capture only, not in the game.
## The scene is capture_military's: a Behemoth croc at CLIP_AT, columns calling in close, the
## pair up from the start. --pull=1.0 gives today's camera at the same moments (stills only).
##
##   ci_capture.sh --movie --fps=60 --resolution=1920x1080 capture_heli_b.gd -- --pull=1.2
##     --seconds=16 --out=<dir>

const SHOTS: Array[int] = [60, 180, 300, 420, 540, 660, 780, 900]
const CLIP_SPAWN := 44.0
const CLIP_AT := Vector2(5, -70)
## Seconds the pull takes to ramp in and to ramp back (smoothstep: zero speed at both ends).
const RAMP := 1.6
## How far the view slides from the kaiju toward the helicopters' middle at full pull.
const FRAME_SHIFT := 0.3
## The helicopters leave (shot down) at these frames, so the clip shows the zoom-back.
const LEAVE_AT: Array[int] = [480, 540]
## Half the footprint of a helicopter with its rotor, metres, for the fully-in-frame test.
const HELI_HALF := 6.0
## Kaiju height in body-scale units, for its on-screen height.
const KAIJU_TALL := 7.0

var _out := "user://heli_b"
var _seconds := 16.0
var _pull := 1.2


## Runs after Rampage places its camera each frame: moves the camera out along its own line of
## sight by the pull and slides the view a little toward the helicopters, round the point it
## looks at. `p` ramps 0..1 at a fixed rate while helicopters are up (1..0 when none are), and
## the smoothstep of it drives both, so the move starts and ends at rest.
class CameraPull:
	extends Node
	var rampage: Rampage
	var target := 1.2
	var p := 0.0
	var k := 1.0
	var shift := Vector2.ZERO

	func _process(delta: float) -> void:
		var sim := rampage.sim
		var up := not sim.air.helis.is_empty()
		p = clampf(p + (1.0 if up else -1.0) * delta / RAMP, 0.0, 1.0)
		var e := p * p * (3.0 - 2.0 * p) if target > 1.0 else 0.0
		k = 1.0 + (target - 1.0) * e
		var cam := rampage._camera
		var look := rampage._focus + Vector3(0, 3.5 * sim.body_scale(), 0)
		if up:
			var mid := Vector2.ZERO
			for heli: AirWing.Heli in sim.air.helis:
				mid += heli.pos
			mid /= float(sim.air.helis.size())
			shift = (mid - sim.kaiju_pos) * FRAME_SHIFT  # kept as the helicopters leave
		look += Vector3(shift.x, 0, shift.y) * e
		cam.position = look + (cam.position - look) * k
		cam.look_at(look)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		if arg.begins_with("--pull="):
			_pull = arg.substr(7).to_float()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {"claws": 1, "evolve1": 1}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 100000.0
	var tier := Num.i(stats["size"])
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0)), 1
	)
	rampage.sim.kaiju_pos = CLIP_AT
	rampage.scripted = _input
	root.add_child(rampage)
	var pull := CameraPull.new()
	pull.rampage = rampage
	pull.target = _pull
	pull.process_priority = 1000  # after Rampage's own camera placement
	root.add_child(pull)
	await physics_frame
	var sim := rampage.sim
	sim.army["spawn_radius"] = CLIP_SPAWN
	sim.army["start_interval"] = 1.6
	sim.army_units._spawn_timer = 0.3
	sim.air.cfg["after_chunks"] = 0
	sim.air.cfg["max_per_chunks"] = 1
	sim.air.cfg["interval"] = 0.8
	sim.chunks_destroyed = 2  # two helicopters may be up (AirWing.cap)
	var csv := FileAccess.open(_out.path_join("frames_x%.1f.csv" % _pull), FileAccess.WRITE)
	csv.store_line("frame,helis_up,helis_readable,kaiju_px,pull_k")
	var up_frames := 0
	var one_ok := 0
	var two_ok := 0
	var h_min := INF
	var h_sum := 0.0
	var h_n := 0
	var hud: Array[Rect2] = []
	for i: int in roundi(_seconds * 60.0):
		await physics_frame
		if LEAVE_AT.has(i) and not sim.air.helis.is_empty():
			sim.air.helis.pop_back()
			sim.chunks_destroyed = -1  # no replacements: the sky stays clear
		if i == 30:
			hud = _hud_rects(rampage._hud, root.get_viewport().get_visible_rect())
		var cam := rampage._camera
		var view := root.get_viewport().get_visible_rect()
		var ok := 0
		for heli: AirWing.Heli in sim.air.helis:
			if _readable(cam, heli, sim.air.altitude(), view, hud):
				ok += 1
		var bs := sim.body_scale()
		var foot := cam.unproject_position(Vector3(sim.kaiju_pos.x, 0, sim.kaiju_pos.y))
		var top := cam.unproject_position(
			Vector3(sim.kaiju_pos.x, KAIJU_TALL * bs, sim.kaiju_pos.y)
		)
		var px := absf(foot.y - top.y)
		var up := sim.air.helis.size()
		csv.store_line("%d,%d,%d,%.1f,%.3f" % [i, up, ok, px, pull.k])
		if up > 0:
			up_frames += 1
			one_ok += 1 if ok >= 1 else 0
			two_ok += 1 if ok >= 2 else 0
			h_min = minf(h_min, px)
			h_sum += px
			h_n += 1
		if SHOTS.has(i):
			var path := _out.path_join("heli_b_x%.1f_%04d.png" % [_pull, i])
			root.get_viewport().get_texture().get_image().save_png(path)
			print("%d: pull %.2f, helicopters up %d" % [i, pull.k, up])
	csv.close()
	print("HUD rects: ", hud)
	print(
		(
			"pull x%.1f: helis up %d frames; >=1 readable %d; 2 readable %d; kaiju px min %.0f mean %.0f"
			% [_pull, up_frames, one_ok, two_ok, h_min, h_sum / maxf(1.0, float(h_n))]
		)
	)
	quit()


## True when all four corners of the helicopter's footprint are inside the view and its middle
## is outside every HUD rectangle.
func _readable(
	cam: Camera3D, heli: AirWing.Heli, alt: float, view: Rect2, hud: Array[Rect2]
) -> bool:
	var c := Vector3(heli.pos.x, alt, heli.pos.y)
	if cam.is_position_behind(c):
		return false
	for dx: float in [-HELI_HALF, HELI_HALF]:
		for dz: float in [-HELI_HALF, HELI_HALF]:
			var q := c + Vector3(dx, 0, dz)
			if cam.is_position_behind(q) or not view.has_point(cam.unproject_position(q)):
				return false
	var mid := cam.unproject_position(c)
	for r: Rect2 in hud:
		if r.grow(12.0).has_point(mid):
			return false
	return true


## Screen rectangles of the HUD's visible widgets (boxes under 60% of the view; wrappers skipped).
func _hud_rects(node: Node, view: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for child: Node in node.get_children():
		out.append_array(_hud_rects(child, view))
		var c := child as Control
		if c != null and c.is_visible_in_tree():
			var r := c.get_global_rect()
			if r.size.x > 4.0 and r.size.y > 4.0 and r.size.x < view.size.x * 0.6 and r.size.y < view.size.y * 0.6:
				out.append(r)
	return out


func _input(sim: RampageSim) -> Dictionary:
	sim.facing = Vector2(1, 0)
	return {"move": Vector2.ZERO}
