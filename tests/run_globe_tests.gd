extends "res://tests/lib/runner.gd"
## Globe suite (Overworld plan rows G1, G2, G4): the Tellus Nova mask holds the seven continents
## apart, Neptunia an island chain; the globe reads the mask where SphereMesh draws it, and a
## point on each continent hit-tests to that continent through the camera, lights it and picks it
## on a click; each continent's marker stays on it as the globe spins, and a click flies the
## camera to it. Seeded, no clock.
##   godot --headless --path . --script tests/run_globe_tests.gd

## The continents in the mask's value order (1..7; D-420), as Content.continents() loads them.
const ORDER := [
	"ostia_minor", "carthago", "thule", "silvania", "mons_ferrata", "neptunia", "aurelia"
]
## Plan row G1: 0 sea, 1..7 the continents in ORDER (tools/overworld/paint_tellus_mask.py).
const MASK := "res://assets/overworld/tellus_nova_mask.png"
const NEPTUNIA_ISLES := 5  # the gate: an island chain, not one landmass
const GLOBE := "res://scenes/globe_view.tscn"
const UV_TOLERANCE := 0.0001
const SPIN_STEPS := 24  # globe positions over one full turn of idle spin
const FLY_STEPS := 10  # frames a fly-to is stepped in
const FLY_OFFSET := 0.6  # rad, how far round from the centre a clicked continent starts


func suite_name() -> String:
	return "Globe"


func run_checks() -> void:
	await _t("_check_globe_mask")
	await _t("_check_globe_uv")
	await _t("_check_globe_hit")
	await _t("_check_globe_markers")


func _check_globe_mask() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(MASK))
	check(
		img != null and img.get_width() == 2 * img.get_height(), "the mask is 2:1 equirectangular"
	)
	if img == null:
		return
	img.convert(Image.FORMAT_L8)
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	var counts := PackedInt32Array()
	counts.resize(256)
	for v in px:
		counts[v] += 1
	var stray := 0
	for v in range(ORDER.size() + 1, 256):
		stray += counts[v]
	check(stray == 0, "every pixel is sea or one of the 7 continents (%d stray)" % stray)
	for n in ORDER.size():
		check(counts[n + 1] > 0, "%s has land on the mask" % ORDER[n])
	# Each pole row is one value: a row mixing land and sea meets at the pole as a straight wedge.
	var mixed := 0
	for x in w:
		mixed += int(px[x] != px[0]) + int(px[(h - 1) * w + x] != px[(h - 1) * w])
	check(
		mixed == 0, "each pole row is all one value, so nothing pinches at a pole (%d off)" % mixed
	)
	var nep := ORDER.find("neptunia") + 1
	var isles := _regions(px, w, h, nep)
	check(
		isles >= NEPTUNIA_ISLES,
		"Neptunia is an island chain: %d separate islands (>= %d)" % [isles, NEPTUNIA_ISLES]
	)


## Separate 4-connected regions of one value; x wraps, as the mask's left and right edges meet.
func _regions(px: PackedByteArray, w: int, h: int, value: int) -> int:
	var seen := PackedByteArray()
	seen.resize(px.size())
	var found := 0
	for i in px.size():
		if px[i] != value or seen[i] == 1:
			continue
		found += 1
		seen[i] = 1
		var stack: Array[int] = [i]
		while not stack.is_empty():
			var c: int = stack.pop_back()
			var x := c % w
			var y := c / w
			for nb: int in [
				y * w + (x + 1) % w,
				y * w + (x + w - 1) % w,
				c - w if y > 0 else -1,
				c + w if y < h - 1 else -1
			]:
				if nb >= 0 and px[nb] == value and seen[nb] == 0:
					seen[nb] = 1
					stack.append(nb)
	return found


## The land shader samples the mask at the mesh's UV; the hit-test computes a UV from a point.
## They must agree, or a click lands on the wrong continent: every SphereMesh vertex off the
## poles and the seam maps back to its own UV.
func _check_globe_uv() -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = GlobeView.SEGMENTS
	sphere.rings = GlobeView.RINGS
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var worst := 0.0
	var tested := 0
	for i in verts.size():
		var uv := uvs[i]
		if uv.y <= 0.0 or uv.y >= 1.0 or uv.x <= 0.0 or uv.x >= 1.0:
			continue
		worst = maxf(worst, (GlobeView.uv_of(verts[i]) - uv).length())
		tested += 1
	check(
		tested > 0 and worst < UV_TOLERANCE,
		"uv_of matches SphereMesh's UVs at %d vertices (worst %.6f)" % [tested, worst]
	)


## On the globe scene: each continent's anchor, turned to face the camera, hit-tests to that
## continent through the screen; the pointer over it lights it, a click picks it; sea and the space
## beside the globe hit nothing.
func _check_globe_hit() -> void:
	var globe: GlobeView = (load(GLOBE) as PackedScene).instantiate()
	globe.spin = false
	root.add_child(globe)
	var picked: Array[String] = []
	globe.continent_picked.connect(func(id: String) -> void: picked.append(id))
	var anchors := _anchors()
	var cam := globe.camera()
	for n in ORDER.size():
		var local := anchors[n + 1]
		_face(globe, local)
		var screen := cam.unproject_position(globe.surface_global(local))
		var hit := globe.continent_at(screen)
		check(hit == str(ORDER[n]), "%s's anchor hit-tests to it (got '%s')" % [ORDER[n], hit])
		var move := InputEventMouseMotion.new()
		move.position = screen
		globe._unhandled_input(move)
		check(globe.hovered == str(ORDER[n]), "the pointer over %s lights it" % ORDER[n])
		_click(globe, screen)
		globe._process(GlobeView.FLY_S)  # the pick's fly-to lands before the next one
	check(picked == Array(ORDER, TYPE_STRING, "", null), "a click picks each one: %s" % [picked])
	var sea := anchors[0]
	_face(globe, sea)
	var at := cam.unproject_position(globe.surface_global(sea))
	check(globe.continent_at(at) == "", "open sea hits no continent")
	check(
		globe.continent_at(Vector2.ZERO) == "", "the corner of the screen, off the globe, hits none"
	)
	globe.free()


## Plan row G4 (director 2026-11-01: a marker on every continent, pin and name; a click flies the
## camera in). Each marker stands on its own continent's land; as the globe spins, every marker on
## the near side sits over its continent on the screen and every one on the far side is hidden;
## a click on a continent turns it to the screen's centre and closes the camera in, the spin
## holds there, and Esc flies back out and the spin resumes.
func _check_globe_markers() -> void:
	var globe: GlobeView = (load(GLOBE) as PackedScene).instantiate()
	root.add_child(globe)
	var mask := GlobeView.MASK.get_image()
	mask.convert(Image.FORMAT_L8)
	for n in ORDER.size():
		var id := str(ORDER[n])
		var on := GlobeView.id_at_uv(mask, GlobeView.uv_of(globe.anchor_of(id)))
		check(on == n + 1, "%s's marker stands on its own land (mask value %d)" % [id, on])
	_markers_attached(globe)
	var cam := globe.camera()
	var centre := cam.get_viewport().get_visible_rect().size / 2.0
	for id: String in ORDER:
		globe.fly_out()
		globe._process(GlobeView.FLY_S)
		_face(globe, globe.anchor_of(id).rotated(Vector3.UP, FLY_OFFSET))
		_click(globe, globe.marker(id).position)
		check(globe.selected == id and globe.flying(), "a click on %s starts its fly-to" % id)
		for i in FLY_STEPS:
			globe._process(GlobeView.FLY_S / FLY_STEPS)
		var yaw := globe.yaw
		globe._process(1.0)
		var at := globe.continent_at(centre)
		var dist := cam.position.z
		check(
			at == id and is_equal_approx(dist, GlobeView.ZOOM_DISTANCE) and globe.yaw == yaw,
			"%s arrives at the centre (under it: '%s'), camera at %.2f, spin holds" % [id, at, dist]
		)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	globe._unhandled_input(esc)
	globe._process(GlobeView.FLY_S)
	var before := globe.yaw
	globe._process(1.0)
	check(
		(
			globe.selected == ""
			and is_equal_approx(cam.position.z, GlobeView.CAMERA_DISTANCE)
			and is_equal_approx(globe.yaw - before, GlobeView.IDLE_SPIN)
		),
		"Esc flies back out to %.1f and the spin resumes" % GlobeView.CAMERA_DISTANCE
	)
	globe.free()


## Over one full turn of idle spin, each marker on the near side sits over its own continent on
## the screen and each one on the far side is hidden.
func _markers_attached(globe: GlobeView) -> void:
	var cam := globe.camera()
	var shown := 0
	var hidden := 0
	var wrong: Array[String] = []
	for step in SPIN_STEPS:
		globe._process(TAU / GlobeView.IDLE_SPIN / SPIN_STEPS)
		for id: String in ORDER:
			var m := globe.marker(id)
			var world := globe.surface_global(globe.anchor_of(id))
			var near := (world - globe.global_position).dot(cam.global_position - world) > 0.0
			if m.visible != near:
				wrong.append("%s step %d: visible %s, near %s" % [id, step, m.visible, near])
			elif m.visible:
				shown += 1
				var under := globe.continent_at(m.position)
				if under != id:
					wrong.append("%s step %d: marker over '%s'" % [id, step, under])
			else:
				hidden += 1
	check(
		wrong.is_empty() and shown > 0 and hidden > 0,
		(
			"over a full turn each near marker sits on its continent, each far one is hidden"
			+ " (%d shown, %d hidden): %s" % [shown, hidden, wrong]
		)
	)


## The mask's anchors, sea first (GlobeView.anchors).
func _anchors() -> Array[Vector3]:
	var img := Image.load_from_file(ProjectSettings.globalize_path(MASK))
	img.convert(Image.FORMAT_L8)
	return GlobeView.anchors(img, ORDER.size())


## Turns the globe so a point in its own frame faces the camera.
func _face(globe: GlobeView, local: Vector3) -> void:
	globe.yaw = -atan2(local.x, local.z)
	globe.set_tilt(asin(local.y))
	globe._process(0.0)


func _click(globe: GlobeView, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		globe._unhandled_input(click)
