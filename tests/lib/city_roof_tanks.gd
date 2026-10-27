extends RefCounted
## The rooftop tank mix (director 2026-10-27, D-348, D-352: "the rooftanks look massive, and why
## are the brown"; "keep SOME of the wooden towers, but mix it up with the white ones"; picked
## "Mostly white" and "About 1.5 storeys"). Measured on the voxels BuildingLayout lays for BRICK
## lots (the archetype that carries one): about 3 roofs in 4 carry the white solar water heater
## (a white tank lying on its side above two dark panels in silver frames), the rest a wooden
## tower 12 cells tall (barrel taller than wide on legs, hoops, a cone roof). The sample at each
## stage and map seed is spread over the whole city, with the smallest and the largest footprint
## in it, so a tank is not clipped on a narrow roof.

const WHITE_MIN := 0.65
const WHITE_MAX := 0.85
const TOWER_TALL := 12  # cells, 1.5 storeys at 8 cells to a storey
const TOWER_SLACK := 1
const SAMPLE := 60  # BRICK lots per run, spread over the city
const MIN_BARREL := 5  # layers of one width: straight staves
const MIN_ASPECT := 1.1  # barrel layers for each cell of its width: taller than wide
const MIN_ROOF := 3  # cone roof layers above the barrel
const TIP_MAX := 2  # the roof ends in a point at most this many cells wide
const MIN_HOOPS := 2  # layers of the barrel with an iron hoop round it
const MIN_HOOP_CELLS := 8  # cells of a hoop beside the staves (a roof vent stack has 1)
const HEATER_LONG := 2.0  # the white tank is this many times longer than it is high and deep
const HEATER_ACROSS := 2  # cells across the tank, at least
const MIN_SOLAR := 12  # panel cells
const MIN_PANEL_LEVELS := 3  # layers the tilted panels climb through
const PLATFORM_SLACK := 2  # cells the platform may reach past the barrel's foot
const SHOWN := 3  # failures named in a message


## What one roof carries, found in the building's cells.
class Roof:
	extends RefCounted
	var cells: Dictionary = {}
	var tank: Array[Vector3i] = []  # wooden: the staves and the cone
	var solar: Array[Vector3i] = []  # white heater: the dark glass panels
	var body: Array[Vector3i] = []  # white heater: the tank, shaded underside
	var light: Array[Vector3i] = []  # white heater: the highlight along its top


static func check(tiers: Array[int], seeds: Array[int], check: Callable) -> void:
	var white := 0
	var wood := 0
	var shares: Array[String] = []
	var neither: Array[String] = []
	var tower: Array[String] = []
	var heater: Array[String] = []
	var heights: Array[int] = []
	for tier: int in tiers:
		for map_seed: int in seeds:
			var run_white := 0
			var run_wood := 0
			for b: RampageSim.Building in _sample(tier, map_seed):
				var roof := read(BuildingLayout.new(b, BuildingVoxels.RES).cells)
				var where := "%dx%d (stage %d, map_seed %d)" % [b.w, b.d, tier, map_seed]
				var bad := ""
				if not roof.solar.is_empty():
					run_white += 1
					bad = heater_problem(roof)
					if bad != "":
						heater.append("%s: %s" % [where, bad])
				elif not roof.tank.is_empty():
					run_wood += 1
					bad = tower_problem(roof, heights)
					if bad != "":
						tower.append("%s: %s" % [where, bad])
				else:
					neither.append(where)
			white += run_white
			wood += run_wood
			shares.append("%.2f" % (float(run_white) / maxf(1.0, float(run_white + run_wood))))
	var share := float(white) / maxf(1.0, float(white + wood))
	var line := "about 3 BRICK roofs in 4 carry the white solar heater: %.2f of %d sampled"
	line += " (bar %.2f to %.2f; per stage and seed %s)"
	check.call(
		white + wood > 0 and share >= WHITE_MIN and share <= WHITE_MAX,
		line % [share, white + wood, WHITE_MIN, WHITE_MAX, shares]
	)
	line = "every sampled BRICK roof has a wooden tower or a white heater (%d have neither: %s)"
	check.call(neither.is_empty(), line % [neither.size(), neither.slice(0, SHOWN)])
	line = "every wooden tower is %d +/- %d cells tall, a barrel under a cone roof"
	line += " (%d towers, heights %s; %d wrong: %s)"
	var tall := [TOWER_TALL, TOWER_SLACK, wood, _spread(heights), tower.size()]
	tall.append(tower.slice(0, SHOWN))
	check.call(wood > 0 and tower.is_empty(), line % tall)
	line = "every white heater is a tank lying on its side above two tilted dark panels"
	line += " (%d heaters; %d wrong: %s)"
	var lies := [white, heater.size(), heater.slice(0, SHOWN)]
	check.call(white > 0 and heater.is_empty(), line % lies)


## The roof's parts: the cells with the keys the two tanks are made of.
static func read(cells: Dictionary) -> Roof:
	var roof := Roof.new()
	roof.cells = cells
	for cell: Vector3i in cells:
		match str(cells[cell]):
			"tank":
				roof.tank.append(cell)
			"solar":
				roof.solar.append(cell)
			"heater":
				roof.body.append(cell)
			"heater_hi":
				roof.light.append(cell)
	return roof


## "" when the roof's wooden tower is a 12-cell barrel on legs under a cone roof, else why not.
## `heights` collects the tower heights.
static func tower_problem(roof: Roof, heights: Array[int]) -> String:
	var box: Dictionary = {}  # y -> Vector4i(x min, x max, z min, z max)
	var hoops: Dictionary = {}  # y -> the vent cells beside the staves on that layer
	for cell: Vector3i in roof.tank:
		_grow(box, cell)
		for side: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if str(roof.cells.get(cell + side, "")) == "vent":
				var ring: Dictionary = hoops.get(cell.y, {})
				ring[cell + side] = true
				hoops[cell.y] = ring
	for y: int in hoops.keys():  # a hoop rings the barrel; a roof vent stack only touches it
		var ring: Dictionary = hoops[y]
		if ring.size() < MIN_HOOP_CELLS:
			hoops.erase(y)
			continue
		for cell: Vector3i in ring:
			_grow(box, cell)
	var layers: Array = box.keys()
	layers.sort()
	var widths: Array[int] = []
	for y: int in layers:
		var at: Vector4i = box[y]
		widths.append(maxi(at.y - at.x, at.w - at.z) + 1)
	var floor_y := Num.i(layers[0])
	if Num.i(layers[-1]) - floor_y + 1 != widths.size():
		return "the tower has a gap between layers"
	var run := 0  # the barrel: the longest run of layers of one width
	var barrel := 0
	var barrel_end := 0
	for i: int in widths.size():
		run = run + 1 if i > 0 and widths[i] == widths[i - 1] else 1
		if run > barrel:
			barrel = run
			barrel_end = i
	var width := widths[barrel_end]
	var cone := widths.slice(barrel_end + 1)
	var tidy := true
	for i: int in range(1, cone.size()):
		tidy = tidy and cone[i] <= cone[i - 1]
	var foot: Vector4i = box[floor_y]
	var tall := _legs_below(roof, floor_y, foot) + widths.size()
	heights.append(tall)
	var why: Array[String] = []
	if absi(tall - TOWER_TALL) > TOWER_SLACK:
		why.append("%d cells tall" % tall)
	if barrel < MIN_BARREL or float(barrel) / width < MIN_ASPECT:
		why.append("barrel %d layers for %d wide, layers %s" % [barrel, width, widths])
	if cone.size() < MIN_ROOF or not tidy or cone[-1] > TIP_MAX:
		why.append("cone of %d layers %s" % [cone.size(), cone])
	if hoops.size() < MIN_HOOPS:
		why.append("%d hoops" % hoops.size())
	return ", ".join(why)


## The layers under the barrel's foot (x min, x max, z min, z max) that hold gear within the
## platform's width: the platform itself, then the legs, down to the roof.
static func _legs_below(roof: Roof, floor_y: int, foot: Vector4i) -> int:
	var layer := floor_y - 1
	var reach := foot
	for x: int in range(foot.x - PLATFORM_SLACK, foot.y + PLATFORM_SLACK + 1):
		for z: int in range(foot.z - PLATFORM_SLACK, foot.w + PLATFORM_SLACK + 1):
			if str(roof.cells.get(Vector3i(x, layer, z), "")) == "gear":
				reach = Vector4i(
					mini(reach.x, x), maxi(reach.y, x), mini(reach.z, z), maxi(reach.w, z)
				)
	var count := 0
	while _gear_in(roof, layer, reach):
		count += 1
		layer -= 1
	return count


static func _gear_in(roof: Roof, layer: int, reach: Vector4i) -> bool:
	for x: int in range(reach.x, reach.y + 1):
		for z: int in range(reach.z, reach.w + 1):
			if str(roof.cells.get(Vector3i(x, layer, z), "")) == "gear":
				return true
	return false


## "" when the white heater is a tank lying on its side above two tilted dark panels in silver
## frames, else why not.
static func heater_problem(roof: Roof) -> String:
	var white: Array[Vector3i] = roof.body + roof.light
	var why: Array[String] = []
	if white.is_empty():
		return "no white tank"
	var tank := _bounds(white)
	var long_x := tank.y - tank.x + 1
	var long_z := tank.w - tank.z + 1
	var high := _high(white)
	var across := mini(long_x, long_z)
	var along := maxi(long_x, long_z)
	if mini(across, high) < HEATER_ACROSS or along < HEATER_LONG * maxi(across, high):
		why.append("tank %d long, %d across, %d high" % [along, across, high])
	if roof.body.is_empty() or roof.light.is_empty() or _top(roof.light) <= _top(roof.body):
		why.append("no highlight along the top of the tank")
	var open := 0
	for cell: Vector3i in white:
		if cell.x == tank.x and str(roof.cells.get(cell + Vector3i.LEFT, "")) != "gear":
			open += 1
		if cell.x == tank.y and str(roof.cells.get(cell + Vector3i.RIGHT, "")) != "gear":
			open += 1
	if open > 0:
		why.append("%d cells at the ends of the tank without a cap" % open)
	var panels := _bounds(roof.solar)
	var levels: Dictionary = {}
	var columns: Array[int] = []
	for cell: Vector3i in roof.solar:
		levels[cell.y] = true
		if not columns.has(cell.x):
			columns.append(cell.x)
	columns.sort()
	var groups := 1
	for i: int in range(1, columns.size()):
		groups += 1 if columns[i] > columns[i - 1] + 1 else 0
	if roof.solar.size() < MIN_SOLAR or levels.size() < MIN_PANEL_LEVELS or groups != 2:
		why.append(
			(
				"%d panel cells in %d groups over %d layers"
				% [roof.solar.size(), groups, levels.size()]
			)
		)
	if _top(roof.solar) >= _low(white) or panels.x > tank.x or panels.y < tank.y:
		why.append("the panels are not under the tank")
	return ", ".join(why)


## A spread of the BRICK lots of one run: the smallest three, the largest, and every few between.
static func _sample(tier: int, map_seed: int) -> Array[RampageSim.Building]:
	var base: Dictionary = Content.tuning().duplicate(true)
	var city_cfg: Dictionary = base["city"]
	city_cfg["map_seed"] = map_seed
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(
		stats,
		CityGrowth.tuning_for(base, tier),
		CityGrowth.layout(base, tier, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	var brick: Array[RampageSim.Building] = []
	for b: RampageSim.Building in sim.lot_buildings():
		if b.style % 4 == BuildingLayout.BRICK:
			brick.append(b)
	brick.sort_custom(_smaller)
	var picked: Array[RampageSim.Building] = []
	var step := maxi(1, ceili(float(brick.size()) / SAMPLE))
	for i: int in range(0, brick.size(), step):
		picked.append(brick[i])
	for b: RampageSim.Building in brick.slice(0, SHOWN) + brick.slice(-1):
		if not picked.has(b):
			picked.append(b)
	return picked


static func _smaller(p: RampageSim.Building, q: RampageSim.Building) -> bool:
	return p.w * p.d < q.w * q.d


static func _grow(box: Dictionary, cell: Vector3i) -> void:
	var at: Vector4i = box.get(cell.y, Vector4i(cell.x, cell.x, cell.z, cell.z))
	box[cell.y] = Vector4i(
		mini(at.x, cell.x), maxi(at.y, cell.x), mini(at.z, cell.z), maxi(at.w, cell.z)
	)


## (x min, x max, z min, z max) of the cells.
static func _bounds(cells: Array[Vector3i]) -> Vector4i:
	var at := Vector4i(cells[0].x, cells[0].x, cells[0].z, cells[0].z)
	for cell: Vector3i in cells:
		at = Vector4i(
			mini(at.x, cell.x), maxi(at.y, cell.x), mini(at.z, cell.z), maxi(at.w, cell.z)
		)
	return at


static func _low(cells: Array[Vector3i]) -> int:
	var y := cells[0].y
	for cell: Vector3i in cells:
		y = mini(y, cell.y)
	return y


static func _top(cells: Array[Vector3i]) -> int:
	var y := cells[0].y
	for cell: Vector3i in cells:
		y = maxi(y, cell.y)
	return y


static func _high(cells: Array[Vector3i]) -> int:
	return _top(cells) - _low(cells) + 1


## "min to max" of a list of numbers.
static func _spread(values: Array[int]) -> String:
	if values.is_empty():
		return "none"
	return "%d to %d" % [values.min(), values.max()]
