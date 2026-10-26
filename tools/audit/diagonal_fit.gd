extends SceneTree
## Picks the city's diagonal avenue (city.diagonal_through z and city.diagonal_deg) for its rings:
## the setting nearest the current one under which every seed's street lines can keep the
## diagonal's crossings clear of the grid's (CityLineFit.x_runs_fit; road geometry, D-265,
## director 2026-10-26: "No, split them apart"). Rerun it whenever the district rings, block
## sizes, street widths or outskirts change (the city_audit suite fails while the data does not
## fit). A setting counts only when its neighbours STEP_Z either side fit too (a margin).
##   godot --headless --path . --script tools/audit/diagonal_fit.gd -- [--write]
## --write puts the pick into data/tuning.json (the two rows only).

const DEG_REACH := 3.0  # search the angle this far either side of the current one
const DEG_STEP := 0.25
const Z_REACH := 45.0  # and the through point's z this far either side
const Z_STEP := 0.25
const STEP_Z := 0.05  # the margin a pick needs on both sides


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	var cfg: Dictionary = Content.tuning()["city"]
	var through: Array = cfg["diagonal_through"]
	var x0 := Num.f(through[0])
	var z0 := Num.f(through[1])
	var deg0 := Num.f(cfg["diagonal_deg"])
	var full := CityGen.districts(cfg)[-1]
	var fits_now := CityLineFit.x_runs_fit(cfg, CityGen.diagonal_of(cfg))
	print(
		(
			"diagonal_fit: now through (%.2f, %.2f) at %.2f deg: %s"
			% [x0, z0, deg0, "fits" if fits_now else "does NOT fit"]
		)
	)
	var tries: Array[Array] = []  # [deviation, z, deg], nearest first
	var deg := deg0 - DEG_REACH
	while deg <= deg0 + DEG_REACH + 0.001:
		var z := z0 - Z_REACH
		while z <= z0 + Z_REACH + 0.001:
			tries.append([_deviation([x0, z0, deg0], [x0, z, deg], full), z, deg])
			z += Z_STEP
		deg += DEG_STEP
	tries.sort_custom(func(p: Array, q: Array) -> bool: return Num.f(p[0]) < Num.f(q[0]))
	var best := {}
	var best_dev := INF
	for t: Array in tries:
		if _fits(cfg, x0, Num.f(t[1]), Num.f(t[2])):
			best = {"z": t[1], "deg": t[2]}
			best_dev = Num.f(t[0])
			break
	if best.is_empty():
		printerr("diagonal_fit: no setting fits within the search")
		quit(1)
		return
	print(
		(
			"diagonal_fit: pick through (%.2f, %.2f) at %.2f deg (moves up to %.1f m)"
			% [x0, best["z"], best["deg"], best_dev]
		)
	)
	if "--write" in OS.get_cmdline_user_args():
		_write(x0, Num.f(best["z"]), Num.f(best["deg"]))
	quit(0)


## A setting fits, and so do its neighbours STEP_Z either side.
func _fits(cfg: Dictionary, x0: float, z: float, deg: float) -> bool:
	for dz: float in [0.0, -STEP_Z, STEP_Z]:
		var c := cfg.duplicate()
		c["diagonal_through"] = [x0, z + dz]
		c["diagonal_deg"] = deg
		if not CityLineFit.x_runs_fit(c, CityGen.diagonal_of(c)):
			return false
	return true


## How far line b strays from line a ([x, z, deg] each) over the city (x within +-full).
static func _deviation(a: Array, b: Array, full: float) -> float:
	var out := 0.0
	for x: float in [-full, full]:
		var za := Num.f(a[1]) + (x - Num.f(a[0])) * tan(deg_to_rad(Num.f(a[2])))
		var zb := Num.f(b[1]) + (x - Num.f(b[0])) * tan(deg_to_rad(Num.f(b[2])))
		out = maxf(out, absf(za - zb))
	return out


func _write(x0: float, z: float, deg: float) -> void:
	var path := "res://data/tuning.json"
	var text := FileAccess.get_file_as_string(path)
	var through := RegEx.create_from_string('"diagonal_through": \\[[^\\]]*\\]')
	var angle := RegEx.create_from_string('"diagonal_deg": [0-9.\\-]+')
	text = through.sub(text, '"diagonal_through": [%s, %s]' % [_num(x0), _num(z)])
	text = angle.sub(text, '"diagonal_deg": %s' % _num(deg))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	print("diagonal_fit: wrote data/tuning.json")


static func _num(v: float) -> String:
	return str(snappedf(v, 0.01))
