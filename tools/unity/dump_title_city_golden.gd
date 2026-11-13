extends SceneTree
## Writes the title's burning city as Godot places it (scenes/title_fires.gd, title_burning_windows.gd,
## title_shore.gd lamps, title_sky_smoke.gd, title_ambience.gd with title_backdrop.gd's flashes and
## colossus reveals), so the Unity port (unity/Assets/Scripts/GameLogic/TitleCity.cs) can be checked
## against it number for number.
##
##   godot --headless --path . --script tools/unity/dump_title_city_golden.gd
##
## Output: unity/SimTests/golden/title_city.txt, read by TitleCheck (`dotnet run --project unity/SimTests`).
## FAR_Z: the far shore's edge; BOX: a far stand-in tower (x y z, size x y z) made here, the ones the
## fires choose from; LIT: the x of each burning tower; F: a fire (x y z, seed, size, smoke density);
## P: a burning pane (set 0 window fires / 1 hero, x y z, width, shade); LIT, F and P carry "real" (tuning's
## foci) or "probe" (the foci moved onto the front rows at PROBE_Z); LAMP: x, glow scale;
## SMOKE: a sky puff (layer, size, x y z); BEACH: the sand's two wave phases; A: an ambience event
## (step, kind, two values); FLASH: a far spot (step, kind, x y z); REVEAL: the next reveal wait.

const OUT := "res://unity/SimTests/golden/title_city.txt"
const DT := 1.0 / 60.0
const STEPS := 7200
## The city stands this many steps in (the first flashes then come soon, flashes_begin).
const LOADED := 90
const BOXES := 60

var _lines: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var title: Dictionary = Content.section("title")
	var tuning := CityGrowth.tuning_for(Content.tuning(), Num.i(title["city_tier"]))
	var city_cfg: Dictionary = tuning["city"]
	var layout := CityGrowth.layout(Content.tuning(), Num.i(title["city_tier"]), Seeds.make("city", 0))
	var sim := RampageSim.new({}, tuning, layout, Seeds.make("army", 0))
	var far_z := Num.f(sim.city["coast_z"]) - Num.f(sim.city["bay_width"])
	_lines.append("FAR_Z %.4f" % far_z)
	_fires(title, city_cfg, far_z)
	_lamps(title, far_z, Num.f(sim.city["coast_z"]))
	_smoke(title)
	var beach := Seeds.make("title_beach", 0)
	_lines.append("BEACH %.6f %.6f" % [beach.randf() * TAU, beach.randf() * TAU])
	_ambience(title, far_z)
	sim.dispose()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	print("title city golden: %d lines -> %s" % [_lines.size(), OUT])
	quit(0)


## Far towers made here around the foci (some outside the burning radius or the front rows), the real
## TitleFires lighting them and the real TitleBurningWindows painting their panes.
func _fires(title: Dictionary, city_cfg: Dictionary, far_z: float) -> void:
	var made := Seeds.make("title_dump", 0)
	var ground := CityGround.new(city_cfg)
	var skyline := CitySkyline.new(ground, Seeds.make("city_skyline", 0))
	var boxes: Array[Dictionary] = []
	for i: int in BOXES:
		var size := Vector3(made.randf_range(10.0, 30.0), made.randf_range(20.0, 140.0), made.randf_range(10.0, 30.0))
		var at := Vector3(made.randf_range(-60.0, 170.0), size.y * 0.5, far_z - made.randf_range(-10.0, 90.0))
		boxes.append({"at": at, "size": size})
		_lines.append("BOX %.4f %.4f %.4f %.4f %.4f %.4f" % [at.x, at.y, at.z, size.x, size.y, size.z])
	skyline._far = boxes
	var fire_cfg: Dictionary = title["fires"]
	_light(skyline, fire_cfg, far_z, "real")
	# Today's foci lie short of the far shore (the bay widened, D-377), so nothing lights: the same cfg
	# with each focus moved onto the front rows lights the district, so the placement itself is checked.
	var probe: Dictionary = fire_cfg.duplicate(true)
	var foci: Array = probe["foci"]
	var z := far_z - Num.f(probe["depth"]) * 0.5
	for focus: Array in foci:
		focus[1] = z
	_lines.append("PROBE_Z %.4f" % z)
	_light(skyline, probe, far_z, "probe")
	skyline.free()
	ground.free()


func _light(skyline: CitySkyline, fire_cfg: Dictionary, far_z: float, tag: String) -> void:
	var city := Node3D.new()
	city.add_child(skyline)
	var lit := TitleFires.new(city, fire_cfg, far_z).light()
	_lines.append("LIT %s %s" % [tag, " ".join(Array(lit).map(func(x: float) -> String: return "%.4f" % x))])
	var group := 0
	for node: Node in city.get_children():
		if node is FarFire:
			var fire := node as FarFire
			_lines.append(
				(
					"F %s %.4f %.4f %.4f %.6f %.4f %.4f"
					% [
						tag, fire.position.x, fire.position.y, fire.position.z, fire._seed,
						Num.f(fire._cfg["size"]), Num.f(fire._cfg["smoke_density"])
					]
				)
			)
		elif node is TitleBurningWindows:
			# Headless, a MultiMesh keeps no transforms: _ready's loop, over the node's own spots and stream.
			var panes := node as TitleBurningWindows
			var reach := Num.i(panes._cfg["cells"])
			var cell := 1.0 / CitySkyline.FAR_GRAIN
			for spot: Vector3 in panes._spots:
				for k: int in range(-reach, reach + 1):
					if k != 0 and panes._rng.randf() < Num.f(panes._cfg["gap"]):
						continue
					var share := 1.0 - float(absi(k)) / float(reach + 1)
					_lines.append(
						(
							"P %s %d %.4f %.4f %.4f %.4f %.4f"
							% [tag, group, spot.x + k * cell, spot.y, spot.z + TitleBurningWindows.OUT, cell, share]
						)
					)
			group += 1
	city.remove_child(skyline)
	city.free()


func _lamps(title: Dictionary, far_z: float, coast_z: float) -> void:
	var shore_cfg: Dictionary = title["shore"]
	var shore := TitleShore.new(
		shore_cfg,
		{
			"shore_z": far_z, "coast_z": coast_z, "cam": Vector3.ZERO, "fires": PackedFloat32Array(),
			"ripple": title["ripple"], "water": title["variants"][str(title["variant"])]["water"]
		}
	)
	for spot: Vector2 in shore._lamp_spots(Num.f(shore_cfg["half_span"])):
		_lines.append("LAMP %.4f %.4f" % [spot.x, spot.y])
	shore.free()


## title_sky_smoke.gd _bank's placement loop (headless, a MultiMesh keeps no transforms).
func _smoke(title: Dictionary) -> void:
	var layers: Array = title["sky_smoke"]
	var rng := Seeds.make("title_sky_smoke", 0)
	for n: int in layers.size():
		var layer: Dictionary = layers[n]
		var x: Array = layer["x"]
		var y: Array = layer["y"]
		var size: Array = layer["size"]
		for i: int in Num.i(layer["amount"]):
			var puff := rng.randf_range(Num.f(size[0]), Num.f(size[1]))
			var at := Vector3(
				rng.randf_range(Num.f(x[0]), Num.f(x[1])),
				rng.randf_range(Num.f(y[0]), Num.f(y[1])),
				Num.f(layer["z"]) + rng.randf_range(-1.0, 1.0) * Num.f(layer["depth"])
			)
			_lines.append("SMOKE %d %.4f %.4f %.4f %.4f" % [n, puff, at.x, at.y, at.z])


## The real TitleAmbience stepped by hand, its signals driving title_backdrop.gd's flash spots and
## colossus reveals as the backdrop draws them (title_screen.gd wires them; the backdrop processes first).
func _ambience(title: Dictionary, far_z: float) -> void:
	var sound := TitleAmbience.new()
	root.add_child(sound)
	sound.set_process(false)
	var flash := Seeds.make("title_flash", 0)
	var reveal := Seeds.make("title_colossus", 0)
	var state := {"step": 0, "loaded": false, "reveal_wait": 0.0}
	var spot := func(kind: String, low: float, high: float) -> void:
		var spans: Array = title["flashes"]["span_x"]
		var span: Array = spans[flash.randi_range(0, spans.size() - 1)]
		var at := Vector3(
			flash.randf_range(Num.f(span[0]), Num.f(span[1])),
			flash.randf_range(low, high),
			far_z - flash.randf_range(4.0, Num.f(title["fires"]["depth"]))
		)
		_lines.append("FLASH %d %s %.4f %.4f %.4f" % [state["step"], kind, at.x, at.y, at.z])
	sound.shot.connect(
		func() -> void:
			_lines.append("A %d shot %.6f %.6f" % [state["step"], sound._gun.pitch_scale, sound._gun.volume_db])
			if state["loaded"]:
				spot.call("shot", 0.0, 0.0)
	)
	sound.boomed.connect(
		func() -> void:
			_lines.append("A %d boom 0 0" % state["step"])
			if not state["loaded"]:
				return
			var boom: Dictionary = title["flashes"]["boom"]
			spot.call("boom", Num.f(boom["min_height"]), Num.f(boom["max_height"]))
			if state["reveal_wait"] <= 0.0:
				var every: Array = title["colossus"]["reveal_every_s"]
				state["reveal_wait"] = reveal.randf_range(Num.f(every[0]), Num.f(every[1]))
				_lines.append("REVEAL %d %.6f" % [state["step"], state["reveal_wait"]])
	)
	sound.stomped.connect(
		func() -> void:
			_lines.append("A %d stomp %.6f %.6f" % [state["step"], sound._stomp.pitch_scale, sound._stomp.volume_db])
	)
	for s: int in STEPS:
		state["step"] = s
		if s == LOADED:
			state["loaded"] = true
			sound.flashes_begin()
		if state["loaded"]:
			state["reveal_wait"] -= DT
		sound._process(DT)
	sound.free()
