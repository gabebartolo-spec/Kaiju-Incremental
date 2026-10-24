class_name SerpentHood
extends MeshInstance3D
## The cobra's hood (D-206; director 2026-10-24, D-218: "gotta fix the frill on the snakes neck
## though, looks terrible from above"): a thin flared shield over the back of the neck, no longer
## the tube itself widened (a pale smooth spoon from the high camera). It runs from the back of the
## head (TOP of head_len) to hood_len m behind the head, widest hood_peak m behind it at hood_flare
## times the head's widest (data/tuning.json "serpent"), rounded at the top and tapering into the
## neck. Spread, its upper part is laid flat from the back of the head, hood_tilt rad below level
## (its back toward the high camera), its lower part curving into the neck; folding, it closes onto
## the neck's own width and shape, and folded (while it slithers) it is not drawn. Its back is the
## body's green in fine scales with a dark rim and the cobra's pale spectacle; its front is dark.
## Rebuilt each frame over the tube's rings; presentation only.

## The spectacle's pale, and the hood's front (dark: the camera only meets it as an edge, where a
## pale one glinted beside the head).
const PALE := Color("e2d89c")
const THROAT := Color("30541b")
## The grid: rows along the hood, columns across (odd: one runs down the middle).
const ROWS := 24
const COLS := 17
## The skin texture's size (px), built once per hood shape.
const TEX := 256
## Where the hood starts (share of head_len), and where its lower part starts curving into the neck
## (share of its length).
const TOP := 0.85
const INTO_NECK := 0.65
## The wings' thickness by the neck (m), and how far the hood stands clear of the neck's skin (m).
const WING := 0.12
const GAP := 0.08
## Below this spread the folded hood is not drawn.
const SHOWN := 0.02
## The back's paint, in m at full spread: the dark rim (fading out over the lower part), the
## scales (diamonds SCALE_W across, SCALE_L along, edges SCALE_EDGE of a scale darkened to
## SCALE_DARK, each scale varied by SCALE_VARY), the flanks' lighter share.
const RIM := 0.32
const RIM_SOFT := 0.08
const SCALE_W := 0.3
const SCALE_L := 0.26
const SCALE_EDGE := 0.14
const SCALE_DARK := 0.72
const SCALE_VARY := 0.1
const FLANK_SHARE := 0.3
## The spectacle (m at full spread): two rings EYE_X each side of the middle, EYE_BELOW below the
## widest row (dark centre, pale ring, dark outline radii), joined under them by a pale bridge, an
## arc of radius BRIDGE_R centred BRIDGE_UP above the rings, BRIDGE_PALE wide in a dark BRIDGE_DARK.
const EYE_X := 0.52
const EYE_BELOW := 0.1
const EYE_IN := 0.19
const EYE_PALE := 0.34
const EYE_OUT := 0.43
const BRIDGE_R := 0.6
const BRIDGE_UP := 0.22
const BRIDGE_PALE := 0.07
const BRIDGE_DARK := 0.12

## The skin textures already built, by hood shape.
static var _skins := {}
var _cfg: Dictionary
var _tube: SerpentTube
var _mesh := ArrayMesh.new()
var _back_mat := StandardMaterial3D.new()
var _front_mat := StandardMaterial3D.new()
## Where the hood runs along the body (m behind the snout), its widest row (share of its length)
## and its half width at full spread (m).
var _top := 0.0
var _end := 0.0
var _peak := 0.0
var _full := 0.0


func _init(cfg: Dictionary, tube: SerpentTube) -> void:
	_cfg = cfg
	_tube = tube
	name = "SerpentHood"
	mesh = _mesh
	visible = false
	var head := Num.f(cfg["head_len"])
	_top = head * TOP
	_end = head + Num.f(cfg["hood_len"])
	_peak = (head + Num.f(cfg["hood_peak"]) - _top) / (_end - _top)
	var widest := 0.0
	for k: int in int(head * 10.0) + 1:
		widest = maxf(widest, tube.body_width(k * 0.1, 1.0))
	_full = Num.f(cfg["hood_flare"]) * widest * 0.5
	for mat: StandardMaterial3D in [_back_mat, _front_mat]:
		mat.roughness = 0.6
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_back_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_front_mat.albedo_color = THROAT


## How wide the hood is drawn `d` m behind the snout at `spread` (m; 0 off the hood or folded).
func width_at(d: float, spread: float, swell: float) -> float:
	if spread <= SHOWN or d < _top or d > _end:
		return 0.0
	return _half((d - _top) / (_end - _top), spread, swell) * 2.0


## Lays the hood over the tube's `rings` ([centres, sides, ups]: each ring's middle and frame, one
## every `step` m from the snout), spread `spread` (0 folded, 1 full, above 1 flared wider).
func place(rings: Array, step: float, spread: float, swell: float) -> void:
	visible = spread > SHOWN
	if not visible:
		return
	if _back_mat.albedo_texture == null:
		_back_mat.albedo_texture = _skin()
	var rows := _rows(rings, step, spread)
	var mids: PackedVector3Array = rings[0]
	var back := PackedVector3Array()
	var front := PackedVector3Array()
	var uvs := PackedVector2Array()
	for row: int in ROWS + 1:
		var t := float(row) / ROWS
		var d := lerpf(_top, _end, t)
		var half := _half(t, spread, swell)
		var neck := _tube.body_width(d, swell) * 0.5  # wider than tall: a round core holds it rolled
		var c: Vector3 = rows[0][row]
		var s: Vector3 = rows[1][row]
		var n: Vector3 = rows[2][row]
		var room := maxf(half - neck - GAP, 0.0)
		var spine := _sample(mids, d, step) - c
		var o := clampf(spine.dot(s), -room, room)  # where the neck runs under it, across
		var rise := maxf(neck + spine.dot(n), 0.0)  # how far the neck's top reaches above its middle
		for col: int in COLS:
			var x := lerpf(-1.0, 1.0, float(col) / (COLS - 1))
			var th := _thick(x * half, o, half, Vector2(neck, rise))
			back.append(c + s * (x * half) + n * th)
			front.append(c + s * (x * half) - n * th)
			uvs.append(Vector2((x + 1.0) * 0.5, t))
	_mesh.clear_surfaces()
	_add(back, uvs, 1.0, _back_mat)
	_add(front, uvs, -1.0, _front_mat)


## Each row's centre, across (the hood's side) and normal (its back): spread, the upper rows lie on
## a straight line from the back of the head, hood_tilt below level, curving onto the neck over the
## lower rows (from INTO_NECK); folded, on the neck. Never sunk into the neck: a row's centre stays
## at or above the neck's own centre along its normal.
func _rows(rings: Array, step: float, spread: float) -> Array:
	var mids: PackedVector3Array = rings[0]
	var sides: PackedVector3Array = rings[1]
	var ups: PackedVector3Array = rings[2]
	var anchor := _sample(mids, _top, step)
	var back_h := _back_way(rings, anchor)
	var tilt := Num.f(_cfg["hood_tilt"])
	var along := back_h * cos(tilt) + Vector3.DOWN * sin(tilt)
	var across := Vector3(back_h.z, 0.0, -back_h.x)  # as SerpentTube's sides: (way.y, 0, -way.x)
	var normal := along.cross(across).normalized()
	var held := clampf(spread, 0.0, 1.0)
	var centres := PackedVector3Array()
	var acrosses := PackedVector3Array()
	var normals := PackedVector3Array()
	for row: int in ROWS + 1:
		var t := float(row) / ROWS
		var d := lerpf(_top, _end, t)
		var k := held * (1.0 - smoothstep(INTO_NECK, 1.0, t))
		var spine := _sample(mids, d, step)
		var s := _sample(sides, d, step).lerp(across, k).normalized()
		var n := _sample(ups, d, step).lerp(normal, k)
		n = (n - s * n.dot(s)).normalized()
		var c := spine.lerp(anchor + along * (d - _top), k)
		c += n * maxf(0.0, (spine - c).dot(n))
		centres.append(c)
		acrosses.append(s)
		normals.append(n)
	return [centres, acrosses, normals]


## The level way the hood runs back from `anchor` (the back of the head): the head's own, so the
## hood frames the head from behind however the neck bends under it.
func _back_way(rings: Array, anchor: Vector3) -> Vector3:
	var mids: PackedVector3Array = rings[0]
	var way := Vector3(anchor.x - mids[0].x, 0.0, anchor.z - mids[0].z)
	if way.length() < 0.01:  # the head straight up: the frame's own way
		var side: Vector3 = rings[1][0]
		way = Vector3(-side.z, 0.0, side.x)
	return way.normalized()


## The hood's half width (m) at `t` of its length, spread `spread`: the neck's own, flaring out to
## _full with the outline.
func _half(t: float, spread: float, swell: float) -> float:
	var neck := _tube.body_width(lerpf(_top, _end, t), swell) * 0.5
	return neck + maxf(_full - neck, 0.0) * _outline(t) * spread


## The outline's flare (0..1) at `t` of the hood's length: a rounded top (a quarter circle) to the
## widest row, then tapering into the neck.
func _outline(t: float) -> float:
	if t <= _peak:
		var k := 1.0 - t / _peak
		return sqrt(maxf(0.0, 1.0 - k * k))
	return cos(PI * 0.5 * clampf((t - _peak) / (1.0 - _peak), 0.0, 1.0))


## Half the hood's thickness `x` m from its middle (`half` its half width): over the neck (`o` m
## off the middle, `neck` its half width and how far its top reaches above the hood's middle) its
## own section and GAP over it, thin wings beside it, sharp at the rim.
static func _thick(x: float, o: float, half: float, neck: Vector2) -> float:
	var r := absf(x - o) / (neck.x + GAP)
	var core := (neck.y + GAP) * sqrt(maxf(0.0, 1.0 - r * r))
	var wing := WING * (1.0 - smoothstep(neck.x * 0.5, half, absf(x)))
	return maxf(core, wing)


## Joint-spaced samples `at` (one every `step` m) read at `d` m.
static func _sample(at: PackedVector3Array, d: float, step: float) -> Vector3:
	var f := d / step
	var i := clampi(int(f), 0, at.size() - 2)
	return at[i].lerp(at[i + 1], clampf(f - i, 0.0, 1.0))


## One face of the hood as a surface: `points` row by row, normals out along `side` of the hood's
## normal (1 the back, -1 the front), wound so its front faces that way.
func _add(points: PackedVector3Array, uvs: PackedVector2Array, side: float, mat: Material) -> void:
	var norms := PackedVector3Array()
	norms.resize(points.size())
	for row: int in ROWS + 1:
		for col: int in COLS:
			var a := (
				points[row * COLS + mini(col + 1, COLS - 1)] - points[row * COLS + maxi(col - 1, 0)]
			)
			var b := (
				points[mini(row + 1, ROWS) * COLS + col] - points[maxi(row - 1, 0) * COLS + col]
			)
			norms[row * COLS + col] = (b.cross(a) * side).normalized()
	var mid := (ROWS / 2) * COLS + COLS / 2
	var face := (points[mid + COLS] - points[mid]).cross(points[mid + 1] - points[mid])
	var flip := face.dot(norms[mid]) > 0.0  # Godot's front faces wind clockwise
	var indices := PackedInt32Array()
	for row: int in ROWS:
		for col: int in COLS - 1:
			var a := row * COLS + col
			var quad := [a, a + COLS, a + 1, a + 1, a + COLS, a + COLS + 1]
			if flip:
				quad = [a, a + 1, a + COLS, a + 1, a + COLS + 1, a + COLS]
			for q: int in quad:
				indices.append(q)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(_mesh.get_surface_count() - 1, mat)


## The back's skin (u across, v from the top down), at full spread, built once per hood shape.
func _skin() -> ImageTexture:
	var key := "%.3f %.3f %.3f %.3f" % [_top, _end, _peak, _full]
	if _skins.has(key):
		return _skins[key]
	var image := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var length := _end - _top
	var eye_y := _peak * length + EYE_BELOW
	for j: int in TEX:
		var t := (j + 0.5) / TEX
		var half := _half(t, 1.0, 1.0)
		var dt := 1.0 / TEX
		var slope := (
			(_half(t + dt, 1.0, 1.0) - _half(maxf(t - dt, 0.0), 1.0, 1.0)) / (2.0 * dt * length)
		)
		var fade := 1.0 - smoothstep(0.7, 0.92, t)
		for i: int in TEX:
			var x := ((i + 0.5) / TEX * 2.0 - 1.0) * half
			var edge := (half - absf(x)) / sqrt(1.0 + slope * slope)
			var rim := (1.0 - smoothstep(RIM - RIM_SOFT, RIM, edge)) * fade
			image.set_pixel(i, j, _paint(x, t * length, absf(x) / half, rim, eye_y))
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_skins[key] = tex
	return tex


## The back's colour at `x` m across, `y` m down from the top (`across` of the half width out; `rim`
## how far into the dark rim; the spectacle's rings `eye_y` m down).
static func _paint(x: float, y: float, across: float, rim: float, eye_y: float) -> Color:
	var base := SerpentTube.BACK.lerp(
		SerpentTube.FLANK, FLANK_SHARE * smoothstep(0.35, 1.0, across)
	)
	var a := x / SCALE_W + y / SCALE_L
	var b := x / SCALE_W - y / SCALE_L
	var fa := fposmod(a, 1.0)
	var fb := fposmod(b, 1.0)
	var inside := minf(minf(fa, 1.0 - fa), minf(fb, 1.0 - fb))
	var cell := fposmod(sin(floorf(a) * 12.9898 + floorf(b) * 78.233) * 43758.5453, 1.0)
	var shade := lerpf(SCALE_DARK, 1.0, smoothstep(0.0, SCALE_EDGE, inside))
	shade *= 1.0 + (cell - 0.5) * SCALE_VARY
	var mark := _spectacle(Vector2(absf(x), y), eye_y)
	var colour := base.lerp(SerpentTube.BAND, rim)
	colour = colour.lerp(SerpentTube.BAND, mark.y).lerp(PALE, mark.x)
	return Color(colour.r * shade, colour.g * shade, colour.b * shade)


## The spectacle at `p` (x from the middle, y down, m): (pale, dark) shares, edges soft over 2.5 cm.
static func _spectacle(p: Vector2, eye_y: float) -> Vector2:
	var soft := 0.025
	var r := p.distance_to(Vector2(EYE_X, eye_y))
	var dark := 1.0 - smoothstep(EYE_OUT - soft, EYE_OUT, r)
	var pale := (
		smoothstep(EYE_IN - soft, EYE_IN, r) * (1.0 - smoothstep(EYE_PALE - soft, EYE_PALE, r))
	)
	var centre := Vector2(0.0, eye_y - BRIDGE_UP)
	if p.y > centre.y and p.x < EYE_X:
		var off := absf(p.distance_to(centre) - BRIDGE_R)
		dark = maxf(dark, 1.0 - smoothstep(BRIDGE_DARK - soft, BRIDGE_DARK, off))
		var bridge := 1.0 - smoothstep(BRIDGE_PALE * 0.5 - soft, BRIDGE_PALE * 0.5, off)
		pale = maxf(pale, bridge * smoothstep(EYE_IN, EYE_PALE, r))  # joins the ring, not the centre
	return Vector2(pale, dark)
