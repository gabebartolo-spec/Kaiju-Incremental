extends SceneTree
## A real autoplayed rampage (hatchling, night by default) that dismisses the first-run controls
## card with a real key event, as a player would, and logs one line a frame to --out: the frame,
## whether the kaiju is still rising from the river, how many buildings and standing cells the
## camera bubble hides (cells of the sim's building frames nearer the camera than the bubble
## radius), the radius, and whether the kaiju's chest is on screen. Used to pick a clip window
## where a tower is cut away; the same run under --write-movie is the clip (it is deterministic
## at a fixed frame rate), and --frame prints the camera's numbers there.
##   godot --path . --resolution 3840x2160 --fixed-fps 30 [--write-movie <out.avi>] \
##     --script tools/capture/capture_bubble_window.gd -- --seconds=60 --out=<log> [--frame=N]
##     [--bubble_off]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SPECIES := "reptilian"
const FPS := 30.0
const LAMP_REACH := 40.0  # lamps this near the kaiju count as its street
const CHEST := 3.5  # body scales above the feet

var _seconds := 60.0
var _out := "bubble_window.txt"
var _time := "night"
var _frame := -1
var _stage := 0
var _weather := ""
var _bubble_off := false


func _initialize() -> void:
	var a := Kit.args(
		{
			"seconds": _seconds,
			"out": _out,
			"time": _time,
			"frame": _frame,
			"stage": _stage,
			"weather": _weather,
			"bubble_off": _bubble_off
		}
	)
	_seconds = Num.f(a["seconds"])
	_out = str(a["out"])
	_time = str(a["time"])
	_frame = Num.i(a["frame"])
	_stage = Num.i(a["stage"])
	_weather = str(a["weather"])
	_bubble_off = a["bubble_off"] == true
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if _time != "":
		Content.set_time(_time)
	if _weather != "":
		Content.set_weather(_weather)
	var rampage: Rampage
	if _stage == 0:
		rampage = Kit.autoplay(self, SPECIES, Kit.stats(SPECIES), 0)
	else:
		var stats := Kit.stats(SPECIES, Kit.STAGE_LEVELS[_stage - 1], SPECIES)
		var layout := CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0))
		rampage = Kit.autoplay(self, SPECIES, stats, 0, layout)
	await rampage.wait_loaded()
	var cam := Kit.game_camera(self)
	var log := FileAccess.open(_out, FileAccess.WRITE)
	var dismissed := false
	var lamps := _lamp_spots()
	for f: int in roundi(_seconds * FPS):
		await process_frame
		if rampage.sim.over:
			break
		if _bubble_off:  # after the rampage set it this frame, before it is drawn
			RenderingServer.global_shader_parameter_set("bubble_radius", 0.0)
		if lamps.is_empty() and f % 30 == 0:
			lamps = _lamp_spots()  # the city lays them as it streams in
		if not dismissed and not rampage.sim.emerge.active:
			dismissed = _dismiss(rampage)
		var eye := cam.global_position
		var bubble: Object = rampage.get("_bubble")  # null on a build without the bubble
		var radius: float = bubble.call("radius") if bubble != null else 0.0
		var tally := _hidden(rampage.sim, eye, radius)
		var chest := _chest(rampage)
		var on_screen := (
			not cam.is_position_behind(chest)
			and root.get_visible_rect().grow(-40.0).has_point(cam.unproject_position(chest))
		)
		log.store_line(
			(
				"%d %d %d %d %.2f %d %d"
				% [
					f,
					1 if rampage.sim.emerge.active else 0,
					tally.x,
					tally.y,
					radius,
					1 if on_screen else 0,
					_lamps_in_view(cam, rampage, lamps)
				]
			)
		)
		if f == _frame:
			var to := chest - eye
			var pitch := rad_to_deg(atan2(-to.y, Vector2(to.x, to.z).length()))
			print(
				"CAMERA frame %d: dist %.1f pitch %.1f fov %.1f" % [f, to.length(), pitch, cam.fov]
			)
	log.close()
	quit()


## The street lamps' spots (x z) the city's decor placed along its streets.
func _lamp_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for node: Node in root.find_children("*", "CityDecor", true, false):
		var spots: Array = node.get("_lamp_spots")
		for p: Variant in spots:
			var spot: Vector2 = p
			out.append(spot)
	return out


## How many lamps within LAMP_REACH of the kaiju are on screen.
func _lamps_in_view(cam: Camera3D, rampage: Rampage, lamps: Array[Vector2]) -> int:
	var at := Vector2(rampage.sim.kaiju_pos.x, rampage.sim.kaiju_pos.y)
	var seen := 0
	var rect := root.get_visible_rect().grow(-40.0)
	for lamp: Vector2 in lamps:
		if lamp.distance_to(at) > LAMP_REACH:
			continue
		var p := Vector3(lamp.x, 0.5, lamp.y)
		if not cam.is_position_behind(p) and rect.has_point(cam.unproject_position(p)):
			seen += 1
	return seen


## A real key press, as a player's: the HUD's card goes once it has been up its minimum.
func _dismiss(rampage: Rampage) -> bool:
	var hud: RampageHud = rampage.get("_hud")
	if hud.controls_card == null:
		return true
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	return hud.controls_card == null


func _chest(rampage: Rampage) -> Vector3:
	var kaiju: KaijuModel = rampage.get("_kaiju")
	var at := kaiju.focus()
	return at + Vector3(0.0, CHEST * rampage.sim.body_scale(), 0.0)


## [buildings, cells] of standing building cells inside the bubble of `radius` round `eye`.
func _hidden(sim: RampageSim, eye: Vector3, radius: float) -> Vector2i:
	var towers := 0
	var cells := 0
	for b: RampageSim.Building in sim.buildings:
		if b.frame == null:
			continue
		var lo := Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5)
		var box := AABB(lo, Vector3(b.w, b.height, b.d))
		if eye.clamp(box.position, box.end).distance_to(eye) >= radius:
			continue
		var here := 0
		for z: int in b.frame.d:
			for y: int in b.frame.h:
				for x: int in b.frame.w:
					var centre := lo + Vector3(x + 0.5, y + 0.5, z + 0.5)
					if b.frame.alive(Vector3i(x, y, z)) and centre.distance_to(eye) < radius:
						here += 1
		cells += here
		towers += 1 if here > 0 else 0
	return Vector2i(towers, cells)
