class_name RampageSimParts
extends RefCounted
## Builds the run's parts on a new RampageSim, in order (each may read the ones before it): the
## collapse, carving, army, powers, air wing, body, rail, news, death and strikes. Each takes its
## own seed from the run's rng (Seeds.derive), so a run replays exactly.


## pieces: the railway's own pieces in s.buildings, x to y (RailLayout.add_pieces).
static func make(
	s: RampageSim, tuning: Dictionary, rng: RandomNumberGenerator, pieces: Vector2i
) -> void:
	s.collapse = Collapse.new(s, tuning, Seeds.derive(rng, 0xFA11))
	s.carving = Carving.new(s, tuning)
	s.army_units = Army.new(s, rng)
	var flight_cfg: Dictionary = s.army["flight"]
	s.flight = TankFlight.new(s, flight_cfg, Seeds.derive(rng, 0xF117))
	s.explosives = Explosives.new(s, tuning, Seeds.derive(rng, 0xE7))
	s.powers = SpeciesPowers.new(s, Seeds.derive(rng, 0x5EED))
	var air_cfg: Dictionary = tuning["air"]
	s.air = AirWing.new(s, air_cfg, Seeds.derive(rng, 0xA1))
	var vip_cfg: Dictionary = tuning["vip"]
	s.vip = VipHeli.new(s, vip_cfg, Seeds.derive(rng, 0x71B))
	s.brood = Brood.new(s, Seeds.derive(rng, 0xB0))
	s.stomp = RampageStomp.new(s)
	s.emerge = Emergence.new(s.city, tuning)
	s.water = WaterSim.new(s.city, tuning)
	s.body = BodyContact.new(s, tuning)
	s.tail = TailTouch.new(s, s.body.cfg)
	s.rail = Rail.new(s, tuning, Seeds.derive(rng, 0x7A11))
	for n: int in range(pieces.x, pieces.y):
		s.rail.add_piece(n)
	s.news = RunNews.new(s, tuning)
	s.death = DeathOverload.new(s, tuning, Seeds.derive(rng, 0xDEAD))
	var strike_cfg: Dictionary = tuning["strike"]
	s.strikes = Strikes.new(s, strike_cfg)
