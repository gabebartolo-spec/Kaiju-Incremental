class_name RampageSim
extends RefCounted
## One rampage, as pure simulation: the kaiju, the city's buildings as real structures
## (Structure: chunks that fall when unsupported and towers that topple), the army.
## Presentation feeds input to step() and draws the events it returns; it never decides an
## outcome. Ground-plane coordinates are Vector2(x, z); chunk centres are world Vector3.


class Building:
	var x: float
	var z: float
	var w: int
	var d: int
	var height: int
	var tier: int
	var style: int
	var frame: Structure
	## A landmark's id (data/landmarks.json) or ""; rubble_bonus multiplies what its chunks pay.
	var landmark := ""
	var rubble_bonus := 1.0
	## A pool building's model id (data/city_buildings.json, D-256) or "": drawn and carved from
	## its baked model like a landmark, but otherwise an ordinary building. variant: ModelVariant's
	## facing, mirror and stretch; palette: which of its district's shifts it is drawn in.
	var model := ""
	var variant: Dictionary = {}
	var palette := 0
	var hazard := ""  # an explosive site's kind (CityHazards), or ""
	## False past the arena's edge (CityBand): it breaks and pays, but never counts to the fall.
	var in_arena := true
	## What its chunks pay, as a share of a smash: a burnt-out building's (FireSpread) is less.
	var pay_share := 1.0
	## A piece of the railway's viaduct or station (RailLayout: {"piece", "station"}), else empty.
	var rail: Dictionary = {}
	## A piece of a river bridge (BridgeLayout: {"piece", "of", "x", "z"}), else empty.
	var bridge: Dictionary = {}
	## World floor of its local floor 0: a bridge piece stands on the riverbed, under the street.
	var base := 0
	## Chunks it stood with when the rampage began (RunTally reads a landmark's against it).
	var start_chunks := 0

	func is_rail() -> bool:
		return not rail.is_empty()

	func is_bridge() -> bool:
		return not bridge.is_empty()

	## Over a street or the river, on no lot: a railway or a bridge piece.
	func is_span() -> bool:
		return is_rail() or is_bridge()

	## Kept meshed wherever the kaiju is (BuildingStream): a landmark, the railway, a bridge.
	func is_held() -> bool:
		return landmark != "" or is_span()

	## Its local floors for world floors (lo, past hi): a blow that reaches the street reaches a
	## bridge piece down to its riverbed.
	func local_floors(world: Vector2i) -> Vector2i:
		return Vector2i(0 if world.x <= 0 else world.x - base, world.y - base)

	## World centre of chunk c.
	func chunk_world(c: Vector3i) -> Vector3:
		return Vector3(x - w * 0.5 + c.x + 0.5, c.y + 0.5 + base, z - d * 0.5 + c.z + 0.5)

	## World position of a local frame point (e.g. a pivot edge).
	func local_to_world(p: Vector3) -> Vector3:
		return Vector3(x - w * 0.5 + p.x, p.y + base, z - d * 0.5 + p.z)


## A part of a building on its way down: dropping straight, or toppling over an edge.
class Fall:
	var id: int
	var building: int
	var cells: Array[Vector3i]
	var kind: String
	var pivot: Vector3
	var dir: Vector2
	var drop: float
	var height: float
	var width := -1.0  # across a topple, sim units (a carved part's; < 0: from its chunks)
	var t := 0.0
	var duration: float


class Tank:
	var id: int
	var pos: Vector2
	var hp: float
	var cooldown: float
	## Burning or ink-coated: damage per second until coat_t runs out.
	var coat_t := 0.0
	var coat_dps := 0.0
	## Sent flying (TankFlight): height over the street, velocity (y up), bounces taken, and how
	## deep in a Domino chain it is. A tank at rest on a roof keeps its height.
	var flying := false
	var height := 0.0
	var vel := Vector3.ZERO
	var bounces := 0
	var gen := 0
	var tilt := Basis.IDENTITY  # its tumble (TankFlight): off upright, on top of its heading
	var spin := Vector3.ZERO  # axis x rad/s
	var toppled := false  # landed on its side or roof: out of the fight for good


## step() button flags.
const HELD := 1
const ULTIMATE := 2
## The breath's own button (D-280: the lash took the signature; Q / pad X).
const BREATH := 8
## A tank's footprint radius for area hits.
const TANK_RADIUS := 0.6

var stats: Dictionary
var army: Dictionary
var city: Dictionary
var ability_type := "ring"
var buildings: Array[Building] = []
## The buildings filed by ground cell, for questions about one spot (BuildingGrid).
var grid: BuildingGrid
var tanks: Array[Tank] = []
var kaiju_pos := Vector2.ZERO
var facing := Vector2(0, -1)
var hp: float
var max_hp: float
var time_left: float
var rubble: float = 0.0
## The elevated railway and its trains (Rail).
var rail: Rail
var chunks_destroyed := 0
var chunks_total := 0
var falls: Array[Fall] = []
var tanks_destroyed := 0
var ability_ready_in := 0.0
## The breath's cooldown when it has its own button (a lash species).
var breath_ready_in := 0.0
var over := false
var end_reason := ""
## Seconds the rampage has run, and the demo's Endless mode (Endless), null in a normal run.
var elapsed := 0.0
var endless: Endless
var arena_half: float
var next_fall_id := 0
var collapse: Collapse
## The fine destruction grid (Carving): buildings carved cell by cell once first hit.
var carving: Carving
## The tanks' behaviour (Army); the tanks themselves are in `tanks`. Explosives: the red barrels.
var army_units: Army
var flight: TankFlight  # tanks the reptilian sends flying
var explosives: Explosives
## Species powers (SpeciesPowers), the helicopters (AirWing) and the insectoid's young (Brood).
var powers: SpeciesPowers
var air: AirWing
var vip: VipHeli  # the leader's escape helicopter (D-149), beside the air wing
var brood: Brood
var stomp: RampageStomp
var strikes: Strikes  # the reptilian's big attacks, a beat after the press (D-166)
var emerge: Emergence  # the rise from the river that starts a game's run (D-083)
var death: DeathOverload  # how he dies: stagger, stone, shatter
## The body as a solid that breaks what it walks into; it steers the facing with weight.
var body: BodyContact
var tail: TailTouch  # the swinging tail: breaks every building it touches, whatever its size
var news: RunNews  # the big moments (threat level, landmarks, tower totals) as HUD events
var powers_cfg: Dictionary
## How high the kaiju stands (floors): 0 on the street, more on a roof it climbed.
var stand_y := 0.0
## In the air (gliding): no stomps, no blocking.
var airborne := false
var ultimate_ready_in := 0.0
## While set, every chunk and unit _hit_area damages is coated: {"kind", "dps", "seconds"}.
var hit_coat: Dictionary = {}
## While true, _hit_area also reaches helicopters whatever the kaiju's height.
var hit_air := false
## Events of the current step (Collapse appends here too).
var events: Array[Dictionary]:
	get:
		return _events
var _rng: RandomNumberGenerator
var _events: Array[Dictionary] = []


## Set ability_type ("lash", "cone", "leap" or "ring") before the first step.
func _init(
	p_stats: Dictionary, tuning: Dictionary, layout: Array[Dictionary], rng: RandomNumberGenerator
) -> void:
	SimTeardown.note(self)  # a run that drops it without dispose() is cut at the exit
	stats = Growth.stage_stats(p_stats, tuning)
	army = tuning["army"]
	city = tuning["city"]
	powers_cfg = tuning["powers"]
	_rng = rng
	hp = stat("hp")
	max_hp = hp
	time_left = stat("run_seconds")
	arena_half = CityGen.half_extent(city) + Num.f(city["arena_margin"])
	for entry: Dictionary in layout:
		var b := Landmarks.building(entry, Num.f(city["chunk_hp"]))
		b.in_arena = CityBand.touches(b.x, b.z, Vector2(b.w, b.d), arena_half)
		b.start_chunks = b.frame.alive_count
		buildings.append(b)
		chunks_total += b.frame.alive_count if b.in_arena else 0
	var rail_cfg: Dictionary = tuning["rail"]
	var rail_from := RailLayout.add_pieces(buildings, city, rail_cfg)
	var bridge_cfg: Dictionary = tuning["bridge"]
	var bridges_from := BridgeLayout.add_pieces(buildings, city, bridge_cfg)
	grid = BuildingGrid.new(buildings)  # after the rail's and bridges' pieces: buildings too
	kaiju_pos = Vector2(0.0, CityGen.half_extent(city))  # on the ring avenue, at the south edge
	RampageSimParts.make(self, tuning, rng, Vector2i(rail_from, bridges_from))


## The buildings that stand on lots: all but the railway's and the bridges' pieces (is_span).
func lot_buildings() -> Array[Building]:
	return buildings.filter(func(b: Building) -> bool: return not b.is_span())


func stat(stat_name: String) -> float:
	return Num.f(stats.get(stat_name, 0.0))


func size_tier() -> int:
	return Num.i(stat("size"))


## How big the kaiju is drawn and how far its attacks reach (Growth.body_scale).
func body_scale() -> float:
	return Growth.body_scale(stats, city)


func stomp_radius() -> float:
	return stat("stomp_radius") * body_scale()


func ability_reach() -> float:
	return stat("ability_range") * body_scale()


## How high the kaiju can strike: a young one only reaches the lower floors.
func reach_height() -> float:
	return Num.f(city["kaiju_height"]) * body_scale()


## The highest point it can strike from where it stands (a climbed roof adds its height).
func reach_top() -> float:
	return stand_y + reach_height()


## Chunks' worth of how far the city has fallen, as the army and air wing escalate on it.
func escalation() -> int:
	return chunks_destroyed + Endless.escalation(self)


func destruction() -> float:
	return Num.f(chunks_destroyed) / maxf(1.0, Num.f(chunks_total))


## What the rampage did, for the results screen and the save's bests (RunTally.result).
func result() -> Dictionary:
	var out := RunTally.result(self)
	out.merge(vip.summary())
	return out


## Advances the rampage by dt (move, signature pressed, button flags HELD/ULTIMATE/BREATH and
## Dash.BUTTON).
func step(dt: float, move: Vector2, signature_pressed: bool, buttons: int = 0) -> Array[Dictionary]:
	var signature_held := buttons & HELD != 0
	_events = []
	if death.holds(dt) or emerge.step(self, dt):
		return _events
	time_left -= dt
	elapsed += dt
	hp = minf(max_hp, hp + stat("regen") * dt)
	var old_facing := facing
	var moving := move.length() > 0.05 and not body.dash.on()  # a leap takes no stick
	var stride := body.steer(dt, move.limit_length(1.0) * float(moving))  # a stick at rest: zero
	if moving:  # along the body's heading as it turns (BodyContact.steer): a turn walks an arc
		var speed := stat("speed") * powers.speed_mult() * stride
		kaiju_pos = _ashore(kaiju_pos, clamp_to_arena(kaiju_pos + body.heading * speed * dt))
		body.walked(speed * dt, dt)
	powers.after_move(dt, old_facing, moving)
	body.step(dt, buttons & Dash.BUTTON != 0)
	tail.step(dt)
	strikes.step(dt)
	stomp.step(dt)
	SignatureStrike.step_buttons(self, dt, signature_pressed, buttons)
	powers.step(dt, signature_held)
	brood.step(dt)
	collapse.step(dt)
	explosives.step(dt)
	_step_ground(dt)
	_step_sky(dt)
	rail.step(dt)
	Endless.step(self, dt)
	news.step(_events)
	var why := Endless.over_reason(self)
	if why != "":
		end(why)
	return _events


## Lets go of the rings between the sim and its parts (SimTeardown, D-179) so a dropped sim is
## freed: Godot never frees objects that count each other (a rampage kept 240 MB, tools/pacing.gd).
## Call it when the rampage is over for good, after result() is read; it cannot be stepped again.
func dispose() -> void:
	SimTeardown.cut(self)


## Ends the rampage for `reason` (also the pause menu's End Rampage, "ended"); earnings are kept.
## A death plays his overload first (DeathOverload ends it with now = true); `now` ends it at once.
func end(reason: String, now := false) -> void:
	if not now and death.begin(reason):
		return
	over = true
	end_reason = reason
	hp = maxf(0.0, hp)
	_events.append({"type": "run_over", "reason": reason})


func clamp_to_arena(pos: Vector2) -> Vector2:
	return pos.clamp(Vector2(-arena_half, -arena_half), Vector2(arena_half, arena_half))


## A step from `from` to `to` kept out of the sea bay's water (Emergence.wet): into it, the step
## slides along the shore on whichever axis stays dry, else it stands.
func _ashore(from: Vector2, to: Vector2) -> Vector2:
	for p: Vector2 in [to, Vector2(to.x, from.y), Vector2(from.x, to.y)]:
		if not emerge.wet(p):
			return p
	return from


## The tanks: the flung ones fly (TankFlight), then the army drives and fires the rest.
func _step_ground(dt: float) -> void:
	flight.step(dt)
	army_units.step(dt)


## The helicopters: the air wing's gunships, then the leader's escape (D-149).
func _step_sky(dt: float) -> void:
	air.step(dt)
	vip.step(dt)


## Full force within `radius`, fading to nothing at twice the radius: a harder blow breaks a
## wider crater, because more of the fading edge still beats what a chunk can take.
static func falloff(distance: float, radius: float) -> float:
	if distance <= radius:
		return 1.0
	return clampf(1.0 - (distance - radius) / radius, 0.0, 1.0)


## An area blow on chunks, tanks, squads and helicopters (SimDamage.area).
func hit_area(force: Callable, damage: float, y_lo: int = 0, y_hi: int = -1) -> void:
	SimDamage.area(self, force, damage, y_lo, y_hi)


## Nearest standing ground-floor chunk in the arena to `from` (an attacker's goal), or INF.
func nearest_standing(from: Vector2) -> Vector2:
	return StandingChunks.nearest(self, from)


## Damages chunks of one building by the same amount each.
func damage_chunks(index: int, cells: Array[Vector3i], amount: float) -> int:
	var amounts := PackedFloat32Array()
	amounts.resize(cells.size())
	amounts.fill(amount)
	return damage_cells(index, cells, amounts)


## Damages chunks of one building, each by its own amount (SimDamage.cells). Returns chunks broken.
func damage_cells(index: int, cells: Array[Vector3i], amounts: PackedFloat32Array) -> int:
	return SimDamage.cells(self, index, cells, amounts)


func pay(b: Building, chunks: int, bonus: float) -> void:
	chunks_destroyed += chunks if b.in_arena else 0
	var mult := bonus * b.rubble_bonus * b.pay_share * stat("rubble_mult")
	rubble += chunks * b.tier * Num.f(city["chunk_rubble"]) * mult
