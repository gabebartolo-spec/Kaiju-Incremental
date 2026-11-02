extends RefCounted
## The water suite's cost checks (tests/run_water_tests.gd; play ran 6.5 fps, 2026-11-02): the
## bay never settles (its open sea keeps running), so whatever walks its whole window each frame
## costs every frame. WaterSim._stand scans only the columns round the kaiju and the ones still
## holding his body (Basin.held), not the whole window (on vs off: the cells it reads); WaterView
## writes each column's height with no call per column, the same heights as the per-column code
## it replaced. Seeded: the city's map seed, a fixed 60 Hz rise and walk.

const Harbour := preload("res://tests/lib/city_harbour.gd")

const STAGE := 2
const STEPS := 600
const DT := 1.0 / 60.0
## The most of the old scan (near plus the whole window) the held scan may read.
const SCAN_SHARE := 0.1


## A fresh sim rising in the bay (the rise and the walk after it stand him in water).
static func _sim() -> RampageSim:
	var sim := Harbour._fresh(STAGE, Num.i(Content.section("city")["map_seed"]))
	sim.emerge.start(sim)
	return sim


## Basin.held is the box round every column holding the body, and the scan it allows reads a
## small share of what scanning the whole window did.
static func held(check: Callable) -> void:
	var sim := _sim()
	var on := 0
	var off := 0
	var right := 0
	var steps := 0
	for s: int in STEPS:
		sim.step(DT, Vector2(0.3, 1.0), false, 0)
		for basin: WaterSim.Basin in sim.water.basins:
			var box := _body_box(basin)
			right += int(box == basin.held)
			steps += 1
			var near := box.grow(1) if box.has_area() else Rect2i()
			on += _area(near.merge(basin.held) if basin.held.has_area() else near)
			off += _area(near.merge(basin.active) if basin.active.has_area() else near)
	check.call(
		right == steps, "Basin.held is the body's box every step (%d of %d)" % [right, steps]
	)
	check.call(
		off > 0 and on < off * SCAN_SHARE,
		"the stand scan reads %d cells where the whole window was %d" % [on, off]
	)
	sim.dispose()


## WaterView._fill writes the per-column heights the old code did (lift, the film over the sand,
## the body's hollow, the dry column's sand).
static func fill(t: SceneTree, check: Callable) -> void:
	var sim := _sim()
	var view := WaterView.new(sim)
	t.root.add_child(view)
	view.set_process(false)
	var film := Num.f(Content.section("water_sim")["film"])
	var bad := 0
	for s: int in STEPS:
		sim.step(DT, Vector2(0.3, 1.0) if s < STEPS / 2 else Vector2(-1.0, 0.2), false, 0)
		if s % 60 != 0:
			continue
		view.call("_fill", true)
		var bytes: Array = view.get("_bytes")
		for n: int in sim.water.basins.size():
			if _old(sim.water.basins[n], film, view) != bytes[n]:
				bad += 1
	check.call(bad == 0, "the view's heights match the per-column code (%d basins differ)" % bad)
	view.queue_free()
	sim.dispose()


static func _old(basin: WaterSim.Basin, film: float, view: WaterView) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(basin.nx * basin.nz * 2)
	for k: int in basin.nx * basin.nz:
		var ground: float = view.call("_ground", basin, k)
		h[2 * k] = 0.0
		if basin.depth[k] > 0.0:
			h[2 * k] = maxf(basin.lift(k), ground + film)
		elif basin.body[k] > 0.0:
			h[2 * k] = view.call("_around", basin, k, ground)
		h[2 * k + 1] = ground
	return h


static func _body_box(basin: WaterSim.Basin) -> Rect2i:
	var lo := Vector2i(basin.nx, basin.nz)
	var hi := Vector2i(-1, -1)
	for k: int in basin.nx * basin.nz:
		if basin.body[k] > 0.0:
			var c := Vector2i(k % basin.nx, k / basin.nx)
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE) if hi.x >= 0 else Rect2i()


static func _area(r: Rect2i) -> int:
	return r.size.x * r.size.y
