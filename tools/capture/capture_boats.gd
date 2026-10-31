extends SceneTree
## The moored boats (D-404) in a real run, at the game camera: the kaiju walks to the nearest boat
## of --where (pier, bay, river) and wades through it, so its neighbours rock in his wake and are
## pushed off and the one he reaches rolls over and sinks. Prints each boat's state per second.
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_boats.gd -- --time=dusk --where=pier --seconds=20

const Kit := preload("res://tools/capture/capture_kit.gd")

var _seconds := 20.0
var _time := "dusk"
var _where := "pier"
var _view: BoatView
var _target := Vector2.INF
var _boat: Dictionary  # the one he chases (its live pos: the wake pushes it off)
var _side := 0.0  # > 0: a fixed camera this far past the boat, looking back at him
var _rampage: Rampage
var _place := 0.0  # > 0: once he is up, put him this far from the boat (arena edge lifted)


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"seconds": _seconds, "time": _time, "where": _where, "place": _place, "side": _side})
	_side = Num.f(a["side"])
	_place = Num.f(a["place"])
	_seconds = Num.f(a["seconds"])
	_time = str(a["time"])
	_where = str(a["where"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Content.set_time(_time)
	var rampage := Kit.autoplay(self, "reptilian", Kit.stats("reptilian"), 0)
	var city: CityView = rampage.get("_city")
	_view = city.boats
	_rampage = rampage
	rampage.scripted = _to_boat
	var frames := 0
	while frames < int(_seconds * 60.0) and not rampage.sim.over:
		await physics_frame
		frames += 1
		if frames % 60 == 0:
			_report(rampage.sim, frames / 60)
	quit()


## Walks the kaiju to the nearest boat of _where (chosen once, after he is up) and through it.
func _to_boat(sim: RampageSim) -> Dictionary:
	if _target == Vector2.INF:
		var best := INF
		print("boats: arena half %.1f" % sim.arena_half)
		for boat: Dictionary in _view.boats:
			print("boat %s at %s" % [boat["where"], boat["pos"]])
		for boat: Dictionary in _view.boats:
			var p: Vector2 = boat["pos"]
			if str(boat["where"]) == _where and p.distance_to(sim.kaiju_pos) < best:
				best = p.distance_to(sim.kaiju_pos)
				_target = p
				_boat = boat
		print("boats: walking to the %s boat at %s, %.0f away" % [_where, _target, best])
	if _place > 0.0 and not sim.emerge.active:
		sim.arena_half = 10000.0
		sim.kaiju_pos = _target + (Vector2.ZERO - _target).normalized() * _place
		print("boats: placed at %s" % sim.kaiju_pos)
		_place = 0.0
		if _side > 0.0:
			_side_camera(sim)
	var chase: Vector2 = _boat["pos"]
	var to := chase - sim.kaiju_pos
	return {"move": to.normalized() if to.length() > 0.5 else Vector2.ZERO}


func _report(sim: RampageSim, second: int) -> void:
	var near := 0
	for boat: Dictionary in _view.boats:
		var p: Vector2 = boat["pos"]
		if p.distance_to(sim.kaiju_pos) < 30.0:
			near += 1
	print("boats t=%ds kaiju %s, %d within 30, capsized %d" % [second, sim.kaiju_pos, near, _view.capsized])


## Parks a camera on the water _side units past the boat, low, looking back at him, so the boat
## capsizes in front of him rather than under him (director 2026-10-31: the follow camera hides it).
func _side_camera(sim: RampageSim) -> void:
	var cam := Camera3D.new()
	_rampage.add_child(cam)
	var along := (_target - sim.kaiju_pos).normalized()
	var eye := _target + along * _side
	cam.position = Vector3(eye.x, _side * 0.3, eye.y)
	cam.look_at(Vector3(_target.x, 3.0, _target.y))
	cam.current = true
