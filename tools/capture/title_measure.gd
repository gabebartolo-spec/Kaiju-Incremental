extends RefCounted
## Debug numbers for the title's camera (D-158): the tallest far-shore towers and the Colossus's
## head top, each as pixels above the shore line at the capture's size, plus the menu's plates.
## Used by capture_title.gd --measure; prints "measure ..." lines. Not part of the shipped game.

## A tower stands at least this far from the left edge (share of the width) to count as "centre"
## (the menu column covers the left), and at most this far from it.
const CENTRE_FROM := 0.3
const CENTRE_TO := 0.8
## The Colossus's head top lies on the pose picture's top row (alpha above this).
const OPAQUE := 0.5
## The beacon on the lattice tower is a stand-in too, but 1 m wide: not a tower, and high up.
const TOWER_MIN_WIDTH := 4.0
const LATTICE_MIN_Y := 20.0


## Prints the head-vs-tower numbers for `backdrop`'s camera at a frame `frame_h` px tall: the
## tallest towers in frame (the far shore's and the lattice tower's), the Colossus's crest (its
## card faces the camera, tilt included), and the head over the tallest tower.
static func towers_and_head(backdrop: TitleBackdrop, frame_h: float) -> void:
	var camera := backdrop.find_children("*", "Camera3D", true, false)[0] as Camera3D
	var view := camera.get_viewport() as SubViewport
	var size := Vector2(view.size)
	print(
		"measure camera pos ",
		camera.position,
		" rot_deg ",
		camera.rotation_degrees,
		" fov ",
		camera.fov
	)
	var far_z := (
		Num.f(backdrop._city.sim.city["coast_z"]) - Num.f(backdrop._city.sim.city["bay_width"])
	)
	var shore := _screen_y(camera, size, Vector3(camera.position.x, 0.0, far_z), frame_h)
	print("measure shore line y px ", snappedf(shore, 0.1))
	var found: Array[Dictionary] = []
	for node: Node in backdrop.find_children("*", "CitySkyline", true, false):
		for box: Dictionary in (node as CitySkyline).stand_ins():
			var at: Vector3 = box["at"]
			var dim: Vector3 = box["size"]
			if at.z > far_z or at.z < far_z - 80.0:
				continue
			# The lattice tower's beacon (1 m wide) tops the lattice tower; the rest are towers.
			var lattice := dim.x < TOWER_MIN_WIDTH
			if lattice and at.y < LATTICE_MIN_Y:
				continue
			var top := Vector3(at.x, at.y + dim.y * 0.5, at.z + (0.0 if lattice else dim.z * 0.5))
			var share := camera.unproject_position(top).x / size.x
			if not lattice and (share < CENTRE_FROM or share > CENTRE_TO):
				continue
			var y := _screen_y(camera, size, top, frame_h)
			var base := _screen_y(camera, size, Vector3(top.x, 0.0, top.z), frame_h)
			found.append(
				{
					"what": "lattice" if lattice else "tower",
					"x": at.x,
					"z": at.z,
					"m": top.y,
					"y": y,
					"px": base - y,
					"share": share
				}
			)
	found.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return Num.f(a["px"]) > Num.f(b["px"])
	)
	for n: int in mini(found.size(), 5):
		var f := found[n]
		print(
			"measure ",
			f["what"],
			" x ",
			snappedf(Num.f(f["x"]), 0.1),
			" z ",
			snappedf(Num.f(f["z"]), 0.1),
			" top m ",
			snappedf(Num.f(f["m"]), 0.1),
			" top y px ",
			snappedf(Num.f(f["y"]), 0.1),
			" height px ",
			snappedf(Num.f(f["px"]), 0.1),
			" share_x ",
			snappedf(Num.f(f["share"]), 0.001)
		)
	var colossus := backdrop.find_children("*", "TitleColossus", true, false)[0] as TitleColossus
	var cfg: Dictionary = Content.section("title")["colossus"]
	var tex := load("res://assets/title/colossus_0.png") as Texture2D
	var img := tex.get_image()
	var top_row := 0
	var head_u := 0.0
	for row: int in img.get_height():
		var hit := -1
		for col: int in img.get_width():
			if img.get_pixel(col, row).a > OPAQUE:
				hit = col
				break
		if hit >= 0:
			top_row = row
			head_u = float(hit) / img.get_width()
			break
	var height := Num.f(cfg["height"])
	var width := height * tex.get_width() / tex.get_height()
	# The card is a full billboard (title_colossus.gdshader): its own x and y run along the camera's.
	var basis := camera.global_transform.basis
	var crest := (
		colossus.position
		+ (
			basis
			* Vector3(
				(head_u - 0.5) * width, height * (1.0 - float(top_row) / img.get_height()), 0.0
			)
		)
	)
	var head_y := _screen_y(camera, size, crest, frame_h)
	var head_x := camera.unproject_position(crest).x / size.x
	print(
		"measure head crest world ",
		crest,
		" y px ",
		snappedf(head_y, 0.1),
		" above shore px ",
		snappedf(shore - head_y, 0.1),
		" x px ",
		snappedf(head_x * frame_h * 16.0 / 9.0, 0.1)
	)
	if not found.is_empty():
		var tallest := Num.f(found[0]["px"])
		print(
			"measure head over the tallest in frame (",
			found[0]["what"],
			" ",
			snappedf(tallest, 0.1),
			" px): ",
			snappedf((shore - head_y) / tallest, 0.01),
			"x"
		)
	# The silhouette's left and right ends on screen (the head is whole: inside 0..1 of the frame).
	for key: String in ["card_left", "card_right"]:
		var side := -0.5 if key == "card_left" else 0.5
		var p := camera.unproject_position(
			colossus.position + basis * Vector3(side * width, height, 0.0)
		)
		print(
			"measure ",
			key,
			" share ",
			snappedf(p.x / size.x, 0.001),
			", ",
			snappedf(p.y / size.y, 0.001)
		)


## The water band: the shore line down to the top of the near railing, px at the capture's height
## (the band before D-158 was 476 px at 2160: shore 1208, rail 1684).
static func water_band(backdrop: TitleBackdrop, frame_h: float) -> void:
	var camera := backdrop.find_children("*", "Camera3D", true, false)[0] as Camera3D
	var view := camera.get_viewport() as SubViewport
	var size := Vector2(view.size)
	var city: Dictionary = backdrop._city.sim.city
	var shore: Dictionary = Content.section("title")["shore"]
	var far_z := Num.f(city["coast_z"]) - Num.f(city["bay_width"])
	var edge_z := Num.f(city["coast_z"]) - Num.f(shore["ledge_from"]) - Num.f(shore["ledge_depth"])
	var rail_y := Num.f(shore["ledge_top"]) + 0.45 + Num.f(shore["rail_height"])
	var top := _screen_y(camera, size, Vector3(camera.position.x, rail_y, edge_z + 0.9), frame_h)
	var line := _screen_y(camera, size, Vector3(camera.position.x, 0.0, far_z), frame_h)
	print(
		"measure water band px ",
		snappedf(top - line, 0.1),
		" (shore ",
		snappedf(line, 0.1),
		", rail top ",
		snappedf(top, 0.1),
		"; before D-158: 476)"
	)


## The nearest far-shore building to the Continue / New Kaiju plates, in px at the capture's height
## (the gap between the plate's face and the building's projected box; 0 when they overlap).
static func plate_clearance(backdrop: TitleBackdrop, frame_h: float) -> void:
	var camera := backdrop.find_children("*", "Camera3D", true, false)[0] as Camera3D
	var view := camera.get_viewport() as SubViewport
	var size := Vector2(view.size)
	var scale := frame_h / Num.f(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var plates: Array[Rect2] = []
	for found: Node in backdrop.get_parent().find_children("*", "Button", true, false):
		var b := found as Button
		if b.text.begins_with("CONTINUE") or b.text.begins_with("NEW KAIJU"):
			var r := b.get_global_rect()
			r.size -= HazardBox.PLATE_SHADOW
			plates.append(Rect2(r.position * scale, r.size * scale))
	var far_z := (
		Num.f(backdrop._city.sim.city["coast_z"]) - Num.f(backdrop._city.sim.city["bay_width"])
	)
	var best := INF
	var best_what := ""
	for node: Node in backdrop.find_children("*", "CitySkyline", true, false):
		for box: Dictionary in (node as CitySkyline).stand_ins():
			var at: Vector3 = box["at"]
			var dim: Vector3 = box["size"]
			if at.z > far_z + 1.0:
				continue
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for corner: int in 8:
				var p := (
					at
					+ (
						dim
						* 0.5
						* Vector3(
							1.0 if corner & 1 else -1.0,
							1.0 if corner & 2 else -1.0,
							1.0 if corner & 4 else -1.0
						)
					)
				)
				if camera.is_position_behind(p):
					continue
				var s := (
					camera.unproject_position(p) / size * Vector2(frame_h * 16.0 / 9.0, frame_h)
				)
				lo = lo.min(s)
				hi = hi.max(s)
			if lo.x == INF:
				continue
			var rect := Rect2(lo, hi - lo)
			for plate: Rect2 in plates:
				var dx := maxf(
					maxf(rect.position.x - plate.end.x, plate.position.x - rect.end.x), 0.0
				)
				var dy := maxf(
					maxf(rect.position.y - plate.end.y, plate.position.y - rect.end.y), 0.0
				)
				var gap := Vector2(dx, dy).length()
				if gap < best:
					best = gap
					best_what = "box at %s size %s rect %s vs plate %s" % [at, dim, rect, plate]
	print("measure plate clearance px ", snappedf(best, 0.1), " ", best_what)


## The screen row (px at the capture's height) of a world point.
static func _screen_y(camera: Camera3D, size: Vector2, at: Vector3, frame_h: float) -> float:
	return camera.unproject_position(at).y / size.y * frame_h
