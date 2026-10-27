class_name StreetWalk
extends RefCounted
## StreetLife's walk with render_opt.people_buffers and the native extension (render plan item
## 7): every civilian's step in one native call a frame (KaijuWalk.step, StreetLife._walk's math
## bit for bit), then each walker that reached its corner picks the next one (Pavements, from
## the walkers' random stream) in the loop's order, last index first. The few officers step one
## at a time (Police, from its own stream), and the ones far enough away leave once everyone has
## stepped, in the loop's order: the same people, streams and totals as StreetLife's own loop
## (tests/run_street_tests.gd). Without the extension StreetLife walks everyone itself.
## Presentation only.

var native: RefCounted  # KaijuWalk
var _s: StreetLife
var _pavements: Pavements


## Whether this build can walk the street natively (the extension has KaijuWalk).
static func available() -> bool:
	return ClassDB.class_exists("KaijuWalk")


func _init(street: StreetLife, pavements: Pavements) -> void:
	_s = street
	_pavements = pavements
	native = ClassDB.instantiate("KaijuWalk")
	native.call("set_nodes", pavements.nodes)


## Everyone's step this frame. now: StreetLife's clock, then the frame's panic and calm radii,
## gawk seconds and run and walk speeds (StreetLife._walk reads them once a frame).
func frame(delta: float, kaiju: Vector2, now: PackedFloat64Array) -> void:
	var s := _s
	native.call("set_frame", now[1], now[2], now[3], now[4], now[5])
	var out: Array = native.call(
		"step",
		s.pos,
		s.heading,
		s.fleeing,
		s.pinned_until,
		s.from_node,
		s.to_node,
		s.pace,
		s.cop,
		kaiju,
		now[0],
		delta
	)
	var pos: PackedVector2Array = out[0]
	var heading: PackedVector2Array = out[1]
	var fleeing: PackedByteArray = out[2]
	var from: PackedInt32Array = out[4]
	var to: PackedInt32Array = out[5]
	var corners: PackedInt32Array = out[6]
	var startled: int = out[7]
	for i: int in corners:  # last index first, as the loop meets them
		var next := _pavements.next_corner(to[i], from[i], kaiju, fleeing[i] == 1)
		from[i] = to[i]
		to[i] = next
	var gone := _officers(pos, heading, delta, kaiju)
	# A native write copies a column (packed arrays are copy-on-write across the extension): the
	# street keeps the copies.
	s.pos = pos
	s.heading = heading
	s.fleeing = fleeing
	s.pinned_until = out[3]
	s.from_node = from
	s.to_node = to
	s.fled += startled
	for i: int in gone:  # last index first, as the loop removes them
		s.remove(i)


## Each officer's step, last index first (Police moves them): pos and heading take theirs; returns
## the ones that ran far enough to leave, last index first.
func _officers(
	pos: PackedVector2Array, heading: PackedVector2Array, delta: float, kaiju: Vector2
) -> PackedInt32Array:
	var s := _s
	var gone := PackedInt32Array()
	var cop := s.cop
	var i := cop.rfind(1)
	while i >= 0:
		var officer := s.officers[i]
		if s.police.update_cop(officer, delta, kaiju):
			gone.append(i)
		else:
			pos[i] = officer.pos
			heading[i] = officer.heading
		i = cop.rfind(1, i - 1) if i > 0 else -1
	return gone
