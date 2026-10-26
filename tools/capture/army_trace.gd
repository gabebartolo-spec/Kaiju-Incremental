extends SceneTree
## Top-down debug trace of the army (D-066) and headless timing of its step. Plays a seeded
## autoplayed rampage (the tools/pacing.gd player) and draws, over the street plan, every tank's
## track (one colour per tank, a dot where it entered, a ring where it stood 3 s or more), the
## helicopters' tracks and the kaiju's path; building footprints in grey. Prints the army
## step's cost per sim step (it times Army.step through a subclass, so it runs on code from
## before D-066 too, for the before/after pair).
##   godot --headless --path . --script tools/capture/army_trace.gd -- \
##     [--tier=1] [--seed=0] [--seconds=60] [--out=user://army_trace.png]

const DT := 1.0 / 15.0
const PX := 6.0  # pixels per metre
const LEVELS := {1: {}, 2: {"evolve1": 1}, 3: {"evolve1": 1, "evolve2": 1}}


## Army.step, timed (microseconds per call kept in `costs`).
class TimedArmy:
	extends Army
	var costs: Array[int] = []

	func step(dt: float) -> void:
		var t0 := Time.get_ticks_usec()
		super.step(dt)
		costs.append(Time.get_ticks_usec() - t0)


var _tier := 1
var _seed := 0
var _seconds := 60.0
var _out := "user://army_trace.png"
var _half := 0.0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			_tier = arg.substr(7).to_int()
		if arg.begins_with("--seed="):
			_seed = arg.substr(7).to_int()
		if arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var levels: Dictionary = LEVELS[_tier]
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 1000000.0  # the trace watches the army: the run must not end early
	stats["run_seconds"] = 100000.0
	var tuning := CityGrowth.tuning_for(Content.tuning(), _tier)
	var air: Dictionary = tuning["air"]
	air["after_chunks"] = 0  # helicopters up from the start, so the trace shows them
	var layout := CityGrowth.layout(Content.tuning(), _tier, Seeds.make("city", _seed))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", _seed))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	var army := TimedArmy.new(sim, Seeds.make("army", _seed))
	sim.army_units = army
	var tracks := {}  # tank id -> Array[Vector2]
	var parked := {}  # tank id -> Array[Vector2] (where it stood 3 s or more)
	var still := {}
	var helis := {}
	var kaiju: Array[Vector2] = []
	var target := Vector2(INF, INF)
	var shots := 0
	for steps: int in roundi(_seconds / DT):
		if steps % 8 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and not sim.body.stomp_reaches(target):
			move = (target - sim.kaiju_pos).normalized()
		var held := RampageSim.HELD if steps % 30 < 15 else 0
		for event: Dictionary in sim.step(
			DT, move, sim.ability_ready_in <= 0.0, held | RampageSim.ULTIMATE
		):
			if str(event["type"]) == "tank_fired":
				shots += 1
		kaiju.append(sim.kaiju_pos)
		for tank: RampageSim.Tank in sim.tanks:
			var list: Array = tracks.get(tank.id, [])
			var s := 0.0
			var prev: Vector2 = list[list.size() - 1] if not list.is_empty() else Vector2(INF, INF)
			if prev.distance_to(tank.pos) < 0.001:
				s = Num.f(still.get(tank.id, 0.0)) + DT
			still[tank.id] = s
			if absf(s - 3.0) < DT * 0.5:
				var at: Array = parked.get(tank.id, [])
				at.append(tank.pos)
				parked[tank.id] = at
			list.append(tank.pos)
			tracks[tank.id] = list
		for heli: AirWing.Heli in sim.air.helis:
			var list: Array = helis.get(heli.id, [])
			list.append(heli.pos)
			helis[heli.id] = list
	_report(army.costs, tracks.size(), shots)
	_draw(sim, {"tanks": tracks, "parked": parked, "helis": helis}, kaiju)
	quit()


func _report(costs: Array[int], tanks: int, shots: int) -> void:
	var sorted := costs.duplicate()
	sorted.sort()
	var total := 0
	for c: int in costs:
		total += c
	var n := maxi(1, sorted.size())
	print(
		(
			"army step tier %d seed %d: %d steps, mean %.0f us, p95 %d us, max %d us; %d tanks, %d shots"
			% [
				_tier,
				_seed,
				sorted.size(),
				float(total) / n,
				sorted[mini(n - 1, n * 95 / 100)],
				sorted[n - 1],
				tanks,
				shots
			]
		)
	)


func _draw(sim: RampageSim, trace: Dictionary, kaiju: Array[Vector2]) -> void:
	var tracks: Dictionary = trace["tanks"]
	var parked: Dictionary = trace["parked"]
	var helis: Dictionary = trace["helis"]
	var half := sim.arena_half + 22.0
	var size := ceili(half * 2.0 * PX)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color("1b1f24"))
	_half = half
	var plan := CityGen.map(sim.city)
	var nodes: Array = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		var a: Vector2 = nodes[Num.i(street["from"])]
		var b: Vector2 = nodes[Num.i(street["to"])]
		var shade := Color("5a6470") if str(street["kind"]) != CityGen.ALLEY else Color("33393f")
		_line(img, _px(a), _px(b), shade, maxi(1, roundi(Num.f(street["width"]) * PX * 0.5)))
	for b: RampageSim.Building in sim.buildings:
		var lo := _px(Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5))
		var hi := _px(Vector2(b.x + b.w * 0.5, b.z + b.d * 0.5))
		img.fill_rect(Rect2i(lo, hi - lo), Color("2c3138"))
	var edge := _px(Vector2(-sim.arena_half, -sim.arena_half))
	var span := roundi(sim.arena_half * 2.0 * PX)
	_rect(img, Rect2i(edge, Vector2i(span, span)), Color("445"))
	for k: int in range(1, kaiju.size()):
		_line(img, _px(kaiju[k - 1]), _px(kaiju[k]), Color("ff4a3a"), 2)
	var hue := 0.0
	for id: int in tracks:
		var list: Array = tracks[id]
		var c := Color.from_hsv(fmod(hue, 1.0), 0.75, 1.0)
		hue += 0.137
		for k: int in range(1, list.size()):
			var a: Vector2 = list[k - 1]
			var b: Vector2 = list[k]
			_line(img, _px(a), _px(b), c, 1)
		var first: Vector2 = list[0]
		_dot(img, _px(first), c, 4)
		var stops: Array = parked.get(id, [])
		for at: Vector2 in stops:
			_ring(img, _px(at), c, 7)
	for id: int in helis:
		var list: Array = helis[id]
		for k: int in range(1, list.size()):
			var a: Vector2 = list[k - 1]
			var b: Vector2 = list[k]
			_line(img, _px(a), _px(b), Color("6ec8ff"), 1)
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	img.save_png(_out)
	print("trace: ", ProjectSettings.globalize_path(_out))


func _px(p: Vector2) -> Vector2i:
	return Vector2i(roundi((p.x + _half) * PX), roundi((p.y + _half) * PX))


static func _line(img: Image, a: Vector2i, b: Vector2i, c: Color, w: int) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) + 1
	for s: int in steps + 1:
		var p := Vector2(a).lerp(Vector2(b), float(s) / steps)
		_dot(img, Vector2i(p.round()), c, w)


static func _dot(img: Image, p: Vector2i, c: Color, r: int) -> void:
	for dx: int in range(-r + 1, r):
		for dy: int in range(-r + 1, r):
			var q := p + Vector2i(dx, dy)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
				img.set_pixelv(q, c)


static func _ring(img: Image, p: Vector2i, c: Color, r: int) -> void:
	for n: int in 48:
		var a := TAU * n / 48.0
		_dot(img, p + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r)), c, 1)


static func _rect(img: Image, r: Rect2i, c: Color) -> void:
	_line(img, r.position, Vector2i(r.end.x, r.position.y), c, 1)
	_line(img, Vector2i(r.end.x, r.position.y), r.end, c, 1)
	_line(img, r.end, Vector2i(r.position.x, r.end.y), c, 1)
	_line(img, Vector2i(r.position.x, r.end.y), r.position, c, 1)
