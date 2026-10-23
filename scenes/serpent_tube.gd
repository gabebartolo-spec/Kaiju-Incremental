class_name SerpentTube
extends MeshInstance3D
## The serpent's stand-in body (motion critic round 3: "a smooth plausible rope, not a snake"; round
## 4): one continuous tapered tube along the drawn joints, not boxes. From the snout back it is a
## rounded wedge of a head, a narrow neck, a body that swells to the girth and a long thin tail,
## by the `shape` table in data/tuning.json "serpent" (distance behind the snout in m, width as a
## share of the girth). Rings are laid every tube_step m along a Catmull-Rom curve through the
## joints, so a bend never shows corners. A plain skin: dark back, paler flanks, dark bands that
## ride the body (a slide along it would show), a lighter head with two eyes. Rebuilt each frame
## from the joints; presentation only.

const BACK := Color("3f6d24")
const FLANK := Color("7c9a3c")
const BAND := Color("203a12")
const HEAD := Color("8aa63a")
const EYE := Color("f0d84a")
const TONGUE := Color("c4283c")
## Bands: one every BAND_EVERY m of body, BAND_SHARE of it dark, soft over BAND_SOFT of it.
const BAND_EVERY := 2.6
const BAND_SHARE := 0.28
const BAND_SOFT := 0.08

var _cfg: Dictionary
var _mesh := ArrayMesh.new()
var _shape: Array = []
var _sides: int
var _rings := 0
var _indices := PackedInt32Array()
var _eyes: Array[MeshInstance3D] = []
var _tongue: Array[MeshInstance3D] = []
var _hood := 0.0  # how far the hood is spread (0..1), as last built


func _init(cfg: Dictionary) -> void:
	_cfg = cfg
	_shape = cfg["shape"]
	_sides = Num.i(cfg["tube_sides"])
	name = "SerpentTube"
	mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true  # the colours above are sRGB, as written
	mat.roughness = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = EYE
	eye_mat.roughness = 0.3
	ball.material = eye_mat
	for _i: int in 2:
		var eye := MeshInstance3D.new()
		eye.mesh = ball
		add_child(eye)
		_eyes.append(eye)
	var prong := BoxMesh.new()
	var tongue_mat := StandardMaterial3D.new()
	tongue_mat.albedo_color = TONGUE
	tongue_mat.roughness = 0.4
	prong.material = tongue_mat
	for _i: int in 3:  # the stem, then the two prongs
		var piece := MeshInstance3D.new()
		piece.mesh = prong
		piece.visible = false
		add_child(piece)
		_tongue.append(piece)


## The width of the body (share of the girth) `d` m behind the snout: a rounded snout, then
## eased between the table's rows.
func share_at(d: float) -> float:
	var last := _shape.size() - 1
	if d >= Num.f(_shape[last][0]):
		return Num.f(_shape[last][1])
	for i: int in range(1, _shape.size()):
		var a: Array = _shape[i - 1]
		var b: Array = _shape[i]
		if d <= Num.f(b[0]):
			var t := clampf((d - Num.f(a[0])) / (Num.f(b[0]) - Num.f(a[0])), 0.0, 1.0)
			t = sqrt(1.0 - (1.0 - t) * (1.0 - t)) if i == 1 else smoothstep(0.0, 1.0, t)
			return lerpf(Num.f(a[1]), Num.f(b[1]), t)
	return Num.f(_shape[last][1])


## The widest the body is `d` m behind the snout, as drawn (m), with `swell` (its breath): the
## girth (x girth_scale), the head x head_scale, the hood spread behind it.
func width_at(d: float, swell: float) -> float:
	var width := Num.f(_cfg["girth"]) * Num.f(_cfg["girth_scale"]) * share_at(d) * swell
	return width * _head_k(d) * (1.0 + (Num.f(_cfg["hood_flare"]) - 1.0) * _hood * _hood_at(d))


## The body's height `d` m behind the snout: a share of its width, the head flatter, the hood thin.
func height_at(d: float, swell: float) -> float:
	var flat := lerpf(
		Num.f(_cfg["head_flat"]),
		1.0,
		smoothstep(Num.f(_cfg["head_len"]) * 0.7, Num.f(_cfg["head_len"]) * 1.4, d)
	)
	var width := Num.f(_cfg["girth"]) * Num.f(_cfg["girth_scale"]) * share_at(d) * swell
	var thin := 1.0 - Num.f(_cfg["hood_thin"]) * _hood * _hood_at(d)
	return width * _head_k(d) * Num.f(_cfg["height_share"]) * flat * thin


## How much the head is scaled `d` m behind the snout (head_scale over the head, 1 past the neck).
func _head_k(d: float) -> float:
	var head := Num.f(_cfg["head_len"])
	return lerpf(Num.f(_cfg["head_scale"]), 1.0, smoothstep(head, head * 1.8, d))


## The hood's shape along the neck `d` m behind the snout (0..1): it spreads from the back of the
## head, widest hood_peak m behind it, and narrows back into the neck over hood_len m.
func _hood_at(d: float) -> float:
	var head := Num.f(_cfg["head_len"])
	var peak := head + Num.f(_cfg["hood_peak"])
	var end := head + Num.f(_cfg["hood_len"])
	return smoothstep(head * 0.9, peak, d) * (1.0 - smoothstep(peak, end, d))


## Rebuilds the tube along `joints` (ground plane x, z; head first, a segment apart), joint j raised
## `lifts[j]` m above the ground, `swell`: the girth's breath, `tongue`: how far the tongue is out,
## `hood`: how far the cobra's hood is spread (0..1). Each ring is set square to the tube's own
## way in 3D, so a neck that rises steeply stays round.
func build(
	joints: PackedVector2Array,
	lifts: PackedFloat32Array,
	swell: float,
	tongue: float,
	hood := 0.0
) -> void:
	_hood = hood
	var seg := Num.f(_cfg["length"]) / Num.f(_cfg["segments"])
	var per := maxi(1, ceili(seg / Num.f(_cfg["tube_step"])))
	var count := (joints.size() - 1) * per + 1
	var mids := PackedVector3Array()
	var flats := PackedVector3Array()  # each ring's ground-plane side
	mids.resize(count)
	flats.resize(count)
	for r: int in count:
		var at := float(r) / per
		var i := mini(int(at), joints.size() - 2)
		var f := at - i
		var centre := _curve(joints, i, f)
		var tan2 := _tangent(joints, i, f)
		var raised := lerpf(lifts[i], lifts[i + 1], f)
		# the snout's tip sits at the head's own height, not on the ground
		var y := height_at(maxf(at * seg, 1.2), swell) * 0.5 + raised
		mids[r] = Vector3(centre.x, y, centre.y)
		flats[r] = Vector3(tan2.y, 0.0, -tan2.x)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(count * _sides)
	norms.resize(count * _sides)
	cols.resize(count * _sides)
	for r: int in count:
		var d := float(r) / per * seg
		var w := width_at(d, swell)
		var h := height_at(d, swell)
		var mid := mids[r]
		var way := (mids[mini(r + 1, count - 1)] - mids[maxi(r - 1, 0)]).normalized()
		var side := (flats[r] - way * flats[r].dot(way)).normalized()
		var up := way.cross(side).normalized()
		var band := _band(d)
		for s: int in _sides:
			var a := TAU * s / _sides
			var c := cos(a)
			var u := sin(a)
			var k := r * _sides + s
			verts[k] = mid + side * (w * 0.5 * c) + up * (h * 0.5 * u)
			var n := side * (c / maxf(w * 0.5, 0.01)) + up * (u / maxf(h * 0.5, 0.01))
			norms[k] = n.normalized()
			cols[k] = _skin(d, c, u, band)
		_place_eyes(d, mid, side, up, Vector2(w, h))
		if r == 0:
			_place_tongue(mid, -way, up, tongue)
	if _rings != count:
		_rings = count
		_index(count)
	_mesh.clear_surfaces()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Both eyes sit on the head ring nearest eye_at m behind the snout (`size`: its width, height).
func _place_eyes(d: float, mid: Vector3, side: Vector3, up: Vector3, size: Vector2) -> void:
	var step := Num.f(_cfg["tube_step"])
	if absf(d - Num.f(_cfg["eye_at"])) > step * 0.5:
		return
	var ball := Num.f(_cfg["eye_size"]) * 2.0 * Num.f(_cfg["head_scale"])
	for e: int in 2:
		var sign := 1.0 if e == 0 else -1.0
		var at := mid + side * (size.x * 0.5 * 0.82 * sign) + up * (size.y * 0.5 * 0.55)
		_eyes[e].transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * ball), at)


## The forked tongue at the snout: a stem and two prongs, out `out` (0..1) of its full length.
func _place_tongue(snout: Vector3, forward: Vector3, up: Vector3, out: float) -> void:
	var length := Num.f(_cfg["tongue_len"]) * Num.f(_cfg["head_scale"])
	var thick := Num.f(_cfg["tongue_width"]) * Num.f(_cfg["head_scale"])
	var fan := Num.f(_cfg["tongue_fork"])
	var basis := Basis.looking_at(forward, up)
	var stem := length * 0.55 * out
	var prong := length * 0.45 * out
	var shown := out > 0.01
	for i: int in _tongue.size():
		_tongue[i].visible = shown
	if not shown:
		return
	var origin := snout + forward * 0.1
	_tongue[0].transform = Transform3D(
		basis.scaled_local(Vector3(thick, thick, stem)), origin + forward * (stem * 0.5)
	)
	var tip := origin + forward * stem
	for e: int in 2:
		var sign := 1.0 if e == 0 else -1.0
		var turn := basis.rotated(up, sign * fan)
		var along := -turn.z  # looking_at points -z toward `forward`
		_tongue[e + 1].transform = Transform3D(
			turn.scaled_local(Vector3(thick, thick, prong)), tip + along * (prong * 0.5)
		)


func _index(count: int) -> void:
	_indices.resize((count - 1) * _sides * 6)
	var n := 0
	for r: int in count - 1:
		for s: int in _sides:
			var a := r * _sides + s
			var b := r * _sides + (s + 1) % _sides
			var c := (r + 1) * _sides + s
			var d := (r + 1) * _sides + (s + 1) % _sides
			_indices[n] = a
			_indices[n + 1] = c
			_indices[n + 2] = b
			_indices[n + 3] = b
			_indices[n + 4] = c
			_indices[n + 5] = d
			n += 6


## 1 inside a dark band `d` m behind the snout, 0 outside, soft edged; none on the head.
func _band(d: float) -> float:
	var head := Num.f(_cfg["head_len"])
	if d < head:
		return 0.0
	var phase := fposmod(d / BAND_EVERY, 1.0)
	var edge := BAND_SOFT
	var inside := (
		smoothstep(0.0, edge, phase) * (1.0 - smoothstep(BAND_SHARE, BAND_SHARE + edge, phase))
	)
	return inside * smoothstep(head, head + 1.0, d)


## The skin at a ring `d` back, where `c`, `u` are the cosine and sine round the section.
func _skin(d: float, c: float, u: float, band: float) -> Color:
	var back := BACK.lerp(
		FLANK, smoothstep(0.35, 0.95, absf(c)) * 0.8 + smoothstep(0.0, -1.0, u) * 0.6
	)
	var head := 1.0 - smoothstep(Num.f(_cfg["head_len"]) * 0.8, Num.f(_cfg["head_len"]) * 1.3, d)
	return back.lerp(BAND, band * 0.8).lerp(HEAD, head * 0.7)


## Point at fraction `f` of joint `i` to `i + 1` on the Catmull-Rom curve through the joints.
static func _curve(p: PackedVector2Array, i: int, f: float) -> Vector2:
	var p0 := _at(p, i - 1)
	var p1 := p[i]
	var p2 := p[i + 1]
	var p3 := _at(p, i + 2)
	return (
		0.5
		* (
			2.0 * p1
			+ (p2 - p0) * f
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
			+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f
		)
	)


## The curve's unit tangent there, running from the snout toward the tail.
static func _tangent(p: PackedVector2Array, i: int, f: float) -> Vector2:
	var p0 := _at(p, i - 1)
	var p1 := p[i]
	var p2 := p[i + 1]
	var p3 := _at(p, i + 2)
	var d := (
		0.5
		* (
			(p2 - p0)
			+ (2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3)) * f
			+ (3.0 * (3.0 * p1 - p0 - 3.0 * p2 + p3)) * f * f
		)
	)
	return d.normalized() if d.length() > 0.0 else Vector2(0, 1)


## Joint `i` clamped to the ends, an end extended straight (so the curve ends along the chain).
static func _at(p: PackedVector2Array, i: int) -> Vector2:
	if i < 0:
		return 2.0 * p[0] - p[1]
	if i >= p.size():
		return 2.0 * p[p.size() - 1] - p[p.size() - 2]
	return p[i]
