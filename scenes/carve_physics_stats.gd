class_name CarvePhysicsStats
extends Node3D
## The city-wide read-outs of CarvePhysics (split out to keep files small): live and total
## bodies, rubble, lowest point, lifts, skid and the other figures the captures read, over the
## per-building debris and the islands. Nothing here moves a body.

var _cfg: Dictionary
var _sites: Dictionary = {}  # key -> CarveSite
var _debris: Dictionary = {}  # key -> CarveDebris
var _islands: Array[IslandBody] = []


func live_bodies() -> int:
	var n := 0
	for island: IslandBody in _islands:
		if not island.settled_now:
			n += 1
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		n += d.live()
	return n


## Every Jolt body this view holds (live, fading, islands and static rubble colliders).
func all_bodies() -> int:
	var n := _islands.size()
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		n += d.bodies() + d.static_bodies()
	return n


func rubble_pieces() -> int:
	var n := 0
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		n += d.rubble()
	return n


## The lowest point of any debris piece or rubble, city-wide (a ground check for captures).
func lowest_point() -> float:
	var low := INF
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		low = minf(low, d.lowest_point())
	return low


## Live pieces reaching more than `depth` below the ground, city-wide.
func sunk(depth: float) -> int:
	var n := 0
	var y := Num.f(_cfg["ground_y"]) - depth
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		n += d.sunk(y)
	return n


## Pieces lifted out of the road so far and the deepest lift, city-wide: [count, depth].
func raised() -> Array:
	var n := 0
	var deepest := 0.0
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		n += d.raised
		deepest = maxf(deepest, d.max_raise)
	return [n, deepest]


## Horizontal skid of settled pieces, in their own widths (captures):
## [max, mean, count, over 5 widths].
func skid() -> Array:
	var worst := 0.0
	var total := 0.0
	var n := 0
	var over := 0
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		over += d.skid_over
		worst = maxf(worst, d.skid_max)
		total += d.skid_sum
		n += d.skid_n
	return [worst, total / maxi(1, n), n, over]


## The most rubble pieces any one building holds.
func rubble_max() -> int:
	var most := 0
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		most = maxi(most, d.rubble())
	return most


## Rubble pieces dropped past rubble_cap so far, city-wide.
func rubble_dropped() -> int:
	var n := 0
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		n += d.dropped()
	return n


## Pieces that vanished at full size in one frame so far, city-wide (should stay 0).
func vanished() -> int:
	var n := 0
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		n += d.vanished()
	return n


## Pieces faded out because they lay indoors, city-wide (captures).
func culled() -> int:
	var n := 0
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		n += d.culled
	return n


## Pieces whose centre lies inside a building's box shrunk by `margin` and above the street
## by `margin` (captures: debris left hovering inside a glass tower).
func enclosed(margin: float) -> int:
	var n := 0
	for key: int in _debris:
		var s: CarveSite = _sites[key]
		var box := AABB(s.origin, Vector3(s.size) / s.res).grow(-margin)
		var d: CarveDebris = _debris[key]
		n += d.inside(box)
	return n


## The fastest live piece's speed, city-wide.
func live_speed() -> float:
	var fastest := 0.0
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		fastest = maxf(fastest, d.fastest())
	return fastest


func islands() -> Array[IslandBody]:
	return _islands
