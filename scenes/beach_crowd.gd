class_name BeachCrowd
extends RefCounted
## The people on the fixed beachfront's sand (D-381, board v4: "crowded sand"), the game's own
## StreetLife people: some by each umbrella (BeachProps.spots), standing seaward of it facing the
## sea, and a game of volleyball on each court, two a side facing the net; city "harbour" "props"
## "crowd". They stand still (HELD) until his head breaks the water, then, a moment apart
## (crowd "release"), act like every civilian: the near ones gawk and run, the rest walk off to
## the nearest pavement corner. Presentation only.

const HELD := 1.0e9  # pinned_until while the beach waits (StreetLife's clock never gets here)


## Adds the beach's people within `view` of the centre (|x|) to `street`.
static func gather(
	street: StreetLife, plan: Dictionary, view: float, rng: RandomNumberGenerator
) -> void:
	if not plan.has("harbour"):
		return
	var nodes := street.ring_nodes()
	if nodes.is_empty():
		return
	var h: Dictionary = plan["harbour"]["h"]
	var cfg: Dictionary = h["props"]["crowd"]
	var share := Num.f(cfg["per_umbrella"])
	var stand: Array = cfg["stand"]
	var near := Num.f(stand[0])
	var far := Num.f(stand[1])
	var spread := Num.f(cfg["spread"])
	for at: Vector2 in BeachProps.spots(plan, view):
		if rng.randf() < share:
			var off := Vector2(rng.randf_range(-spread, spread), -rng.randf_range(near, far))
			_place(street, nodes, at + off, Vector2(0, -1), rng)
	var court: Array = h["props"]["court"]
	var quarter := Vector2(Num.f(court[0]), Num.f(court[1])) * 0.25
	for at: Vector2 in BeachProps.courts(plan):
		if absf(at.x) > view:
			continue
		for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
			_place(street, nodes, at + corner * quarter, Vector2(-corner.x, 0), rng)


## Every beach person still HELD walks free once his head is out of the water (or at once when
## the run did not rise from the sea), each `release` seconds apart at most.
static func release(street: StreetLife, clock: float, rng: RandomNumberGenerator) -> void:
	var h: Dictionary = street.sim.city["harbour"]
	var after := Num.f(h["props"]["crowd"]["release"])
	for i: int in street.pinned_until.size():
		if street.pinned_until[i] >= HELD:
			street.pinned_until[i] = clock + rng.randf_range(0.0, after)


static func _place(
	street: StreetLife,
	nodes: PackedVector2Array,
	at: Vector2,
	facing: Vector2,
	rng: RandomNumberGenerator
) -> void:
	var near := 0
	for n: int in nodes.size():
		if nodes[n].distance_squared_to(at) < nodes[near].distance_squared_to(at):
			near = n
	var i := street.add_person()
	street.pos[i] = at
	street.heading[i] = facing
	street.from_node[i] = (near & ~3) + ((near + 3) & 3)  # as if coming from the corner before it
	street.to_node[i] = near
	street.outfit[i] = rng.randi_range(0, VoxelPerson.COP - 1)
	street.phase[i] = rng.randf()
	street.pace[i] = rng.randf_range(1.0 - StreetLife.PACE_SPREAD, 1.0 + StreetLife.PACE_SPREAD)
	street.pinned_until[i] = HELD
