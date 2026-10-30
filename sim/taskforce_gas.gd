class_name TaskforceGas
extends RefCounted
## The Taskforce's gas grenades (D-143, D-145, D-152): a gas soldier throws one at the kaiju's feet
## and a blue-black cloud about one street wide stands where it lands for `seconds`. While the
## kaiju stands in a cloud his special powers are locked (the signature, the breath and the
## ultimate cannot be pressed and a running Thunder Beam stops); the dash and every physical attack still work, and
## the cloud does no damage. Part of Taskforce; pure. Events: gas_launched, gas_cloud, gas_cleared,
## gas_lock (on: true / false).

var sim: RampageSim
var cfg: Dictionary
## Clouds standing: [seconds left, centre (x, z)].
var clouds: Array[Array] = []
## Grenades in the air: [seconds left, where it lands (x, z)].
var grenades: Array[Array] = []
## Whether the kaiju stood in a cloud at the last step (his specials are locked).
var locked := false


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## Whether the kaiju is within a thrower's range (`dist` from the agent, ground plane).
func reaches(dist: float) -> bool:
	return dist <= Num.f(cfg["range"])


## A cloud's radius: `streets` street widths across.
func radius() -> float:
	return Num.f(sim.city["street_width"]) * Num.f(cfg["streets"]) * 0.5


## An agent at `from` throws a gas grenade at the kaiju's feet now.
func launch(agent: int, from: Vector3) -> void:
	var feet := sim.kaiju_pos
	grenades.append([Num.f(cfg["flight_s"]), feet])
	sim.events.append(
		{"type": "gas_launched", "agent": agent, "from": from, "x": feet.x, "z": feet.y}
	)


func step(dt: float) -> void:
	var flying: Array[Array] = []
	for grenade: Array in grenades:
		grenade[0] = Num.f(grenade[0]) - dt
		if Num.f(grenade[0]) > 0.0:
			flying.append(grenade)
		else:
			var landed: Vector2 = grenade[1]
			_cloud(landed)
	grenades = flying
	var standing: Array[Array] = []
	for cloud: Array in clouds:
		cloud[0] = Num.f(cloud[0]) - dt
		if Num.f(cloud[0]) > 0.0:
			standing.append(cloud)
		else:
			var at: Vector2 = cloud[1]
			sim.events.append({"type": "gas_cleared", "x": at.x, "z": at.y})
	clouds = standing
	_lock()


## Whether ground point `p` is inside a standing cloud.
func inside(p: Vector2) -> bool:
	for cloud: Array in clouds:
		var at: Vector2 = cloud[1]
		if at.distance_to(p) <= radius():
			return true
	return false


func _cloud(at: Vector2) -> void:
	clouds.append([Num.f(cfg["seconds"]), at])
	sim.events.append(
		{"type": "gas_cloud", "x": at.x, "z": at.y, "radius": radius(), "seconds": cfg["seconds"]}
	)


## In a cloud the specials stay a moment from ready (`hold` seconds, so no press gets through and
## no cooldown is spent) and the Thunder Beam's stream stops.
func _lock() -> void:
	var now := inside(sim.kaiju_pos)
	if now != locked:
		locked = now
		sim.events.append({"type": "gas_lock", "on": now})
	if not now:
		return
	var hold := Num.f(cfg["hold"])
	sim.ability_ready_in = maxf(sim.ability_ready_in, hold)
	sim.ultimate_ready_in = maxf(sim.ultimate_ready_in, hold)
	sim.breath_ready_in = maxf(sim.breath_ready_in, hold)  # the croc's own breath button (D-400)
	if sim.powers.beam_left > 0.0:
		sim.powers.beam_left = 0.0
		sim.events.append({"type": "beam_end"})
