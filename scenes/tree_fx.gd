class_name TreeFx
extends RefCounted
## The tree screen's juice as pure state (tuning "tree" "skin" "fx"): what is playing and how far
## along, advanced by the frames' delta, so the tree suite checks it headless and a capture
## replays the same. Surges run down tubes, motes fly to a bought node, flashes light a node,
## a rim flares when a ring opens, bolts tear the plate on an evolution. Drawing is TreeArea's
## (under the nodes) and TreeFxLayer's (over them).

var cfg: Dictionary
## Seconds since the screen opened (ambient effects are functions of this).
var time := 0.0
## {from: String, to: String, t: float}: Special K running down the tube from -> to.
var surges: Array[Dictionary] = []
## {at: Vector2 (canvas start), to: String, t: float, delay: float, side: float}.
var motes: Array[Dictionary] = []
## id -> seconds left of the node's white flash.
var flashes: Dictionary = {}
## {ring: int, t: float}: a ring's rim flaring open.
var ring_opens: Array[Dictionary] = []
## {to: String, t: float, seed: int}: an evolution's bolts from the centre to the node.
var bolts: Array[Dictionary] = []
## The plate's white flash (0..1).
var plate_flash := 0.0


func _init(p_cfg: Dictionary) -> void:
	cfg = p_cfg


func enabled() -> bool:
	return cfg["enabled"] == true


func f(key: String) -> float:
	return Num.f(cfg[key])


## A node was bought: Special K surges down every tube out of it (`children`), motes fly from
## `from` (canvas units) and the node flashes.
func buy(id: String, children: Array[String], from: Vector2) -> void:
	if not enabled():
		return
	for child: String in children:
		surges.append({"from": id, "to": child, "t": 0.0})
	var n := Num.i(cfg["mote_count"])
	for i: int in n:
		var share := float(i) / maxf(1.0, float(n - 1))
		(
			motes
			. append(
				{
					"at": from,
					"to": id,
					"t": 0.0,
					"delay": share * f("mote_spread_s"),
					"side": (1.0 if i % 2 == 0 else -1.0) * (0.3 + 0.7 * share),
				}
			)
		)
	flashes[id] = f("flash_s")


func ring_open(ring: int) -> void:
	if enabled():
		ring_opens.append({"ring": ring, "t": 0.0})


func evolve(id: String) -> void:
	if not enabled():
		return
	bolts.append({"to": id, "t": 0.0, "seed": hash(id)})
	plate_flash = f("flash_alpha")


## True while anything but the ambient is playing.
func busy() -> bool:
	return (
		not surges.is_empty()
		or not motes.is_empty()
		or not flashes.is_empty()
		or not ring_opens.is_empty()
		or not bolts.is_empty()
		or plate_flash > 0.0
	)


func advance(delta: float) -> void:
	time += delta
	_run(surges, delta, f("surge_s"))
	_run(motes, delta, f("mote_s") + f("mote_spread_s"))
	_run(ring_opens, delta, f("ring_open_s"))
	_run(bolts, delta, f("bolt_s"))
	for id: String in flashes.keys():
		flashes[id] = Num.f(flashes[id]) - delta
		if Num.f(flashes[id]) <= 0.0:
			flashes.erase(id)
	if plate_flash > 0.0:
		plate_flash = maxf(0.0, plate_flash - delta * f("flash_alpha") / f("bolt_s"))


static func _run(list: Array[Dictionary], delta: float, length: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		list[i]["t"] = Num.f(list[i]["t"]) + delta
		if Num.f(list[i]["t"]) >= length:
			list.remove_at(i)
		i -= 1


## A mote's place along its bow from `at` to `to_point`, 0..1 along; null before its delay.
func mote_progress(mote: Dictionary) -> float:
	var t := Num.f(mote["t"]) - Num.f(mote["delay"])
	if t < 0.0:
		return -1.0
	return minf(1.0, t / f("mote_s"))


## A jagged bolt from `from` to `to`, deterministic from `seed` and `which`.
func bolt_points(from: Vector2, to: Vector2, seed: int, which: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + which * 7919
	var segments := Num.i(cfg["bolt_segments"])
	var along := to - from
	var side := Vector2(-along.y, along.x).normalized() * along.length() * f("bolt_jitter")
	var out := PackedVector2Array([from])
	for i: int in range(1, segments):
		var share := float(i) / float(segments)
		var wobble := rng.randf_range(-1.0, 1.0) * sin(share * PI)
		out.append(from + along * share + side * wobble)
	out.append(to)
	return out
