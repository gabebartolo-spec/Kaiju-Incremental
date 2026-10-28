class_name IslandSplit
extends RefCounted
## The chunks an IslandBody splits into on a hard hit (IslandBody._split, moved here to keep that
## file under the size cap): its bricks are grouped into seeded chunks of about split_chunk bricks
## (each brick joins the nearest of seeded seed bricks); a lone brick breaks into half-brick pieces.
## The chunks keep piece_keep of the speed before the hit, spread from the centre at up to
## split_spread and spin by up to split_spin. Reads the body, never changes it.

## The chunks, each {"cells", "mats" (parallel), "xf" (the chunk body's transform), "v", "w",
## "layers": [layer, mask]}.
var parts: Array[Dictionary] = []
## The half-brick pieces of the lone bricks (what IslandBody.broke carries).
var pieces: Array[Dictionary] = []
var _body: IslandBody
var _bricks: Dictionary
var _com: Vector3


func _init(body: IslandBody, bricks: Dictionary, com: Vector3) -> void:
	_body = body
	_bricks = bricks
	_com = com


## Splits at velocity `v` before the hit, with the RNG seeded by `seed_value`, from the
## carve_physics section `cfg`; fills `parts` and `pieces`.
func run(seed_value: int, v: Vector3, cfg: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var groups := IslandFracture.group_bricks(_bricks.keys(), rng, Num.f(cfg["split_chunk"]))
	var xf := _body.global_transform
	var motion := [
		v * Num.f(cfg["piece_keep"]), Num.f(cfg["split_spread"]), Num.f(cfg["split_spin"])
	]
	for group: Array in groups:
		if group.size() == 1:
			var lone: Vector3i = group[0]
			var own: PackedInt32Array = _bricks[lone]
			var frame := [xf, _com, v]
			IslandFracture.pieces_of(_body.site, _body.cells, _body.mats, own, frame, pieces)
			continue
		parts.append(_chunk(group, xf, rng, motion))


## One chunk of `group`'s bricks; `motion` is [the speed it keeps, the spread, the spin].
func _chunk(group: Array, xf: Transform3D, rng: RandomNumberGenerator, motion: Array) -> Dictionary:
	var keep: Vector3 = motion[0]
	var spread: float = motion[1]
	var spin: float = motion[2]
	var own := PackedInt32Array()
	var own_mats := PackedByteArray()
	var com := Vector3.ZERO
	for key: Vector3i in group:
		var ks: PackedInt32Array = _bricks[key]
		for k: int in ks:
			own.append(_body.cells[k])
			own_mats.append(_body.mats[k])
			com += _body.site.world(_body.site.cell(_body.cells[k]))
	com /= own.size()
	var at := xf * (com - _com)
	var out := at - _body.global_position
	out.y = 0.0
	out = out.normalized() * spread * rng.randf_range(0.5, 1.0)
	var w := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	return {
		"cells": own,
		"mats": own_mats,
		"xf": Transform3D(xf.basis, at),
		"v": keep + out + _body.angular_velocity.cross(at - _body.global_position),
		"w": _body.angular_velocity + w * spin,
		"layers": [_body.collision_layer, _body.collision_mask],
	}
