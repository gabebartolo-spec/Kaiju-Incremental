class_name KaijuCodeBody
extends RefCounted
## The code-built kaiju bodies (KaijuModel, for a species with no sculpt or voxel model): shapes
## in design units drawn into the model's VoxelBuilder at RES cells per unit. Presentation only.

const RES := KaijuModel.RES

var _vox: VoxelBuilder


func _init(vox: VoxelBuilder) -> void:
	_vox = vox


## Draws the species' body into the builder.
func shape(species_id: String) -> void:
	match species_id:
		"insectoid":
			_insectoid()
		"cephalopod":
			_cephalopod()
		_:
			_reptilian()


## Design units -> cells.
func _u(v: Vector3) -> Vector3:
	return v * RES


func _blob(c: Vector3, r: Vector3, key: String) -> void:
	_vox.blob(_u(c), r * RES, key)


func _tube(a: Vector3, b: Vector3, r: Vector2, key: String) -> void:
	_vox.tube(_u(a), _u(b), r * RES, key)


## Pseudo-random 0..99 per cell, for scale and speckle patterns.
func _roll(cell: Vector3i) -> int:
	return absi(hash(cell)) % 100


func _reptilian() -> void:
	for side: int in [-1, 1]:
		_blob(Vector3(side * 2.8, 3.2, 0.2), Vector3(1.8, 3.0, 2.0), "body")  # thighs
		_tube(
			Vector3(side * 2.9, 1.8, 0.4), Vector3(side * 3.0, 0.4, -0.8), Vector2(1.0, 0.8), "body"
		)
		for toe: int in 3:  # three clawed toes
			var x := side * (2.3 + toe * 0.6)
			_tube(Vector3(x, 0.3, -1.2), Vector3(x, 0.15, -2.3), Vector2(0.35, 0.25), "ivory")
		_tube(
			Vector3(side * 3.0, 11.0, -0.8),
			Vector3(side * 4.0, 9.4, -2.8),
			Vector2(0.85, 0.7),
			"body"
		)
		_tube(
			Vector3(side * 4.0, 9.4, -2.8),
			Vector3(side * 4.1, 8.3, -4.5),
			Vector2(0.7, 0.55),
			"body"
		)
		for claw: int in 3:
			var cx := side * (3.7 + claw * 0.35)
			_tube(Vector3(cx, 8.1, -4.7), Vector3(cx, 7.4, -5.4), Vector2(0.25, 0.2), "ivory")
	_blob(Vector3(0, 8.5, 0.5), Vector3(3.4, 5.0, 3.2), "body")  # torso
	_blob(Vector3(0, 8.0, -2.3), Vector3(2.3, 3.8, 1.0), "belly")
	_tube(Vector3(0, 12.0, -0.6), Vector3(0, 14.6, -3.0), Vector2(1.9, 1.6), "body")  # neck
	_blob(Vector3(0, 15.6, -4.3), Vector3(1.9, 1.5, 2.2), "body")  # skull
	_blob(Vector3(0, 15.0, -6.6), Vector3(1.4, 1.0, 1.7), "body")  # snout
	_blob(Vector3(0, 13.9, -5.6), Vector3(1.3, 0.6, 2.0), "belly")  # lower jaw
	_chain_tail()
	_reptile_details()


func _chain_tail() -> void:
	var points: Array[Vector3] = [
		_u(Vector3(0, 6.5, 3.0)),
		_u(Vector3(0, 4.6, 6.8)),
		_u(Vector3(0, 2.6, 10.2)),
		_u(Vector3(0.6, 1.0, 13.4)),
	]
	var radii: Array[float] = [2.5 * RES, 1.8 * RES, 1.1 * RES, 0.35 * RES]
	_vox.chain(points, radii, "body")


func _reptile_details() -> void:
	# Teeth along the mouth line, eyes with pupils, nostrils.
	var mouth_y := roundi(14.45 * RES)
	var z_front := roundi(-8.1 * RES)
	var z_back := roundi(-4.4 * RES)
	for z: int in range(z_front, z_back, 2):  # a row of teeth, the mouth narrowing to the front
		var t := float(z - z_front) / (z_back - z_front)
		for side: int in [-1, 1]:
			var x := side * roundi(RES * lerpf(0.55, 1.2, t))
			_vox.box(Vector3i(x, mouth_y - 1, z), Vector3i(x, mouth_y, z), "ivory")
	for side: int in [-1, 1]:
		var eye := Vector3i(side * roundi(1.75 * RES), roundi(16.0 * RES), roundi(-5.3 * RES))
		_vox.box(eye, eye + Vector3i(0, 2, 2), "eye")
		_vox.box(eye + Vector3i(side, 1, 1), eye + Vector3i(side, 1, 1), "pupil")
		_vox.put(Vector3i(side * 2, roundi(15.6 * RES), roundi(-7.7 * RES)), "pupil")
	# Scales on the hide, bands across the belly.
	_vox.repaint(
		func(cell: Vector3i, key: String) -> String:
			if key == "body" and _roll(cell) < 22:
				return "scale"
			if key == "belly" and cell.y % 3 == 0:
				return "belly_dark"
			return key
	)
	_dorsal_plates()


## Dorsal plates: flat triangles rooted on the spine, biggest over the shoulders.
func _dorsal_plates() -> void:
	for i: int in 10:
		var z := roundi((-1.0 + i * 1.4) * RES)
		var root := _vox.top(0, z, ["accent", "accent_edge"])
		if root < -999:
			continue
		var height := roundi((1.0 + 1.8 * sin(PI * clampf((i + 1) / 8.0, 0.0, 1.0))) * RES)
		for h: int in height:
			var half := maxi(0, roundi((height - h) * 0.45))
			for dz: int in range(-half, half + 1):
				var key := "accent_edge" if h == height - 1 or absi(dz) == half else "accent"
				_vox.put(Vector3i(0, root + 1 + h, z + dz), key)


func _insectoid() -> void:
	_blob(Vector3(0, 4.6, 6.0), Vector3(2.8, 2.4, 3.8), "body")  # abdomen
	_blob(Vector3(0, 5.2, 0.6), Vector3(1.6, 1.6, 2.0), "body")  # thorax
	_tube(Vector3(0, 5.6, -1.2), Vector3(0, 5.9, -2.4), Vector2(1.0, 0.9), "body")  # neck
	_blob(Vector3(0, 6.0, -4.2), Vector3(2.2, 1.9, 2.0), "belly")  # head
	for side: int in [-1, 1]:
		_insect_side(side)
	_vox.repaint(
		func(cell: Vector3i, key: String) -> String:
			if key == "body" and cell.z > roundi(3.0 * RES) and cell.z % 4 == 0:
				return "scale"  # abdomen segments
			if key == "eye" and posmod(cell.x * 3 + cell.y * 5 + cell.z * 7, 6) == 0:
				return "pupil"  # compound-eye facets
			return key
	)


## One side of the insectoid: its compound eye, mandible and tip, antenna and three legs.
func _insect_side(side: int) -> void:
	_blob(Vector3(side * 1.8, 6.6, -4.8), Vector3(0.8, 0.9, 0.9), "eye")  # compound eyes
	_tube(
		Vector3(side * 1.3, 5.0, -5.8),
		Vector3(side * 0.5, 4.8, -8.0),
		Vector2(0.45, 0.25),
		"accent"
	)
	_tube(
		Vector3(side * 0.6, 4.8, -7.9), Vector3(side * 0.1, 4.8, -8.4), Vector2(0.2, 0.2), "ivory"
	)
	var antenna: Array[Vector3] = [
		_u(Vector3(side * 0.8, 7.6, -5.0)),
		_u(Vector3(side * 2.4, 10.6, -7.0)),
		_u(Vector3(side * 3.4, 11.6, -6.0)),
	]
	var thin: Array[float] = [0.4, 0.3, 0.3]
	_vox.chain(antenna, thin, "accent")
	for leg: int in 3:  # six legs: up to a high knee, splayed out and down to the ground
		var hip := Vector3(side * 1.2, 5.0, -0.4 + leg)
		var knee := Vector3(side * 5.0, 8.0, -2.0 + leg * 2.5)
		var foot := Vector3(side * 8.0, 0.0, -4.0 + leg * 4.0)
		_tube(hip, knee, Vector2(0.5, 0.45), "accent")
		_tube(knee, foot, Vector2(0.45, 0.3), "accent")
		_blob(knee, Vector3.ONE * 0.6, "joint")


func _cephalopod() -> void:
	_blob(Vector3(0, 10.0, 1.0), Vector3(3.6, 5.5, 3.6), "body")  # mantle
	_blob(Vector3(0, 5.5, 0.0), Vector3(2.8, 1.8, 2.8), "body")  # head under the mantle
	_tube(Vector3(0, 4.6, -2.4), Vector3(0, 4.0, -3.2), Vector2(0.6, 0.5), "belly")  # siphon
	for side: int in [-1, 1]:
		var eye := Vector3i(side * roundi(2.75 * RES), roundi(6.1 * RES), roundi(-0.6 * RES))
		_vox.blob(Vector3(eye), Vector3(1.0, 0.75, 0.75) * RES, "eye")
		_vox.box(eye + Vector3i(side * 2, 0, -2), eye + Vector3i(side * 2, 0, 2), "pupil")
	for i: int in 8:  # tentacles: thick at the head, tapering over the ground
		var angle := TAU * i / 8.0 + 0.2
		var dir := Vector3(sin(angle), 0, -cos(angle))
		var side := dir.cross(Vector3.UP)
		var points: Array[Vector3] = [
			_u(dir * 2.0 + Vector3(0, 4.2, 0)),
			_u(dir * 4.5 + Vector3(0, 1.6, 0)),
			_u(dir * 7.5 + Vector3(0, 0.6, 0) + side * 0.6),
			_u(dir * 10.0 + side * 1.6),
		]
		var radii: Array[float] = [1.0 * RES, 0.8 * RES, 0.55 * RES, 0.2 * RES]
		_vox.chain(points, radii, "body")
	_vox.repaint(
		func(cell: Vector3i, key: String) -> String:
			if key != "body":
				return key
			if cell.y > roundi(6.0 * RES) and _roll(cell) < 12:
				return "accent"  # mantle speckles
			if cell.y <= 1 and (cell.x + cell.z) % 2 == 0:
				return "belly"  # suckers on the undersides
			return key
	)
