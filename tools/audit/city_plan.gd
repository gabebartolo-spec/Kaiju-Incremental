extends SceneTree
## A 1920 x 1080 top-down plan of each demo continent's city at its own stage, straight from the
## sim (CityGen.map): blocks by use, the water it is built round (Ostia's sea, Carthago's round
## harbour, Thule's iced fjord; CityHarbour, CityWater), every street at its width, and the
## kaiju's rise as a red ring with a line to where he wades ashore, and the landmark spots (yellow
## medium, orange big, magenta biggest). Every stage runs the same city. For the director's yes
## on a layout before its 3D build (D-435). Headless, no renderer.
##   godot --headless --path . --script tools/audit/city_plan.gd -- --out=<dir> [--continent=<id>]

const Png := preload("res://tools/audit/audit_png.gd")
const SIZE := Vector2i(1920, 1080)
const COLORS := {
	"sea": Color("2a5a6c"),
	"ice": Color("c8dce6"),
	"shore": Color("5a5248"),
	"harbour": Color("c8b48a"),
	"rise": Color("ff2020"),
	"margin": Color("101214"),
}
## Landmark spots by size (city "landmark_spots"): the spot a filled square, its site outlined.
const SPOTS := {"medium": Color("ffe040"), "big": Color("ff9020"), "biggest": Color("ff40d0")}


func _init() -> void:
	var out := "user://city_plan"
	var only := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--continent="):
			only = arg.trim_prefix("--continent=")
	var base := Content.tuning()
	var code := 0
	for id: String in ["ostia_minor", "carthago", "thule"]:
		if only != "" and id != only:
			continue
		var tier := Num.i(Content.continent(id)["stage"]) + 1
		var cfg: Dictionary = CityGrowth.tuning_for(base, tier, id)["city"]
		var path := "%s/%s_plan.png" % [out, id]
		var err := _save(CityGen.map(cfg), cfg, path)
		print("plan: ", path, " err ", err)
		code = maxi(code, err)
	quit(code)


func _save(plan: Dictionary, cfg: Dictionary, path: String) -> int:
	var extent := CityBand.extent(cfg)
	var side := SIZE.y
	var img := Image.create(side, side, false, Image.FORMAT_RGB8)
	img.fill(Png.COLORS["ground"])
	var view := {"img": img, "extent": extent, "scale": side / (2.0 * extent)}
	var bay: Rect2 = plan["bay"]
	Png._rect(view, bay, COLORS["harbour"])  # Ostia's front: one beach, no grid
	for block: Dictionary in plan["blocks"]:
		var use := str(block["use"])
		var fill: Color = COLORS.get(use, Png.COLORS.get(use, Png.COLORS["built"]))
		Png._rect(view, CityGen.pavement(block, cfg), fill)
	_sea(view, plan)
	_water(view, plan)
	var nodes: Array[Vector2] = plan["nodes"]
	for s: Dictionary in plan["streets"]:
		var kind := str(s["kind"])
		var color: Color = Png.COLORS["alley"] if kind == CityGen.ALLEY else Png.COLORS["road"]
		Png._line(view, [nodes[Num.i(s["from"])], nodes[Num.i(s["to"])]], Num.f(s["width"]), color)
	_spots(view, plan, cfg)
	if plan.has("rise_spawn"):
		var spawn: Vector2 = plan["rise_spawn"]
		var bank: Vector2 = plan.get("rise_bank", spawn)
		Png._line(view, [spawn, bank], 1.0, COLORS["rise"])
		for r: float in [6.0, 6.3, 6.6, 6.9]:
			Png._ring(view, spawn, r, COLORS["rise"])
	var canvas := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
	canvas.fill(COLORS["margin"])
	canvas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((SIZE.x - side) / 2, 0))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return canvas.save_png(path)


## Ostia's sea: everything north of the beach's waterline (over the front's sand, "harbour").
func _sea(view: Dictionary, plan: Dictionary) -> void:
	if not plan.has("harbour"):
		return
	var h: Dictionary = plan["harbour"]["h"]
	_fill(view, func(p: Vector2) -> bool: return p.y < CityHarbour.shore_at(h, p.x), COLORS["sea"])


## Carthago's harbour (open water) or Thule's fjord (ice).
func _water(view: Dictionary, plan: Dictionary) -> void:
	for canal: Dictionary in plan.get("canals", []):
		var rect: Rect2 = canal["rect"]
		Png._rect(view, rect, COLORS["sea"])
	var water: Dictionary = plan.get("water", {})
	match str(water.get("kind", "")):
		CityWater.COTHON:
			var at: Vector2 = water["at"]
			var r := Num.f(water["radius"])
			_fill(view, func(p: Vector2) -> bool: return p.distance_to(at) < r, COLORS["sea"])
		CityWater.FJORD:
			var half := Num.f(water["width"]) * 0.5
			_fill(
				view,
				func(p: Vector2) -> bool: return absf(p.x - CityWater.centre_x(water, p.y)) < half,
				COLORS["ice"]
			)


## Each designated spot a 6 m square, and each sized landmark's site outlined, by size.
func _spots(view: Dictionary, plan: Dictionary, cfg: Dictionary) -> void:
	var spots: Dictionary = cfg.get("landmark_spots", {})
	for id: String in spots:
		if id.begins_with("_"):
			continue
		var spot: Dictionary = spots[id]
		var at: Array = spot["at"]
		var p := Vector2(Num.f(at[0]), Num.f(at[1]))
		var fill: Color = SPOTS[str(spot["size"])]
		Png._rect(view, Rect2(p - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), fill)
	for site: Dictionary in plan["sites"]:
		var spec: Dictionary = site.get("spec", {})
		if not spec.has("size"):
			continue
		var r: Rect2 = site["outer"]
		var c: Color = SPOTS[str(spec["size"])]
		_outline(view, r, c)


## r's four edges, 1.5 m wide.
func _outline(view: Dictionary, r: Rect2, c: Color) -> void:
	for edge: Rect2 in [
		Rect2(r.position, Vector2(r.size.x, 1.5)),
		Rect2(Vector2(r.position.x, r.end.y - 1.5), Vector2(r.size.x, 1.5)),
		Rect2(r.position, Vector2(1.5, r.size.y)),
		Rect2(Vector2(r.end.x - 1.5, r.position.y), Vector2(1.5, r.size.y)),
	]:
		Png._rect(view, edge, c)


## Every pixel whose ground point passes `inside`.
func _fill(view: Dictionary, inside: Callable, color: Color) -> void:
	var img: Image = view["img"]
	var s: float = view["scale"]
	var e: float = view["extent"]
	for y: int in img.get_height():
		for x: int in img.get_width():
			if inside.call(Vector2((x + 0.5) / s - e, (y + 0.5) / s - e)):
				img.set_pixel(x, y, color)
