class_name ClawSwipe
extends RefCounted
## Claws (D-095): every few seconds the reptilian rakes the space in front of it with one arm,
## the arms alternating. The rake is a band ahead of the body (from the chest to past the snout,
## up to arm height) that slashes building fronts, tanks and soldiers at full force. Each Claws
## level hits harder (swipe_damage) and rakes wider (swipe_width); a body without the stats never
## swipes. Part of SpeciesPowers; pure, no randomness.

var sim: RampageSim
var cfg: Dictionary
## Swipes so far, and the chunks they broke themselves (not what falls after).
var swipes := 0
var cut := 0
var _timer := 0.0
var _side := 1.0


## cfg: the "powers" tuning (swipe_interval, swipe_near, swipe_far, swipe_top).
func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg
	_timer = Num.f(cfg["swipe_interval"])


func step(dt: float) -> void:
	if sim.stat("swipe_damage") <= 0.0:
		return
	_timer -= dt
	if _timer > 0.0 or sim.airborne:
		return
	_timer += Num.f(cfg["swipe_interval"])
	_rake()


func _rake() -> void:
	var bs := sim.body_scale()
	var near := Num.f(cfg["swipe_near"]) * bs
	var far := Num.f(cfg["swipe_far"]) * bs
	var half := sim.stat("swipe_width") * bs
	var top := sim.stand_y + Num.f(cfg["swipe_top"]) * bs
	var centre := sim.kaiju_pos
	var ahead := sim.facing
	var across := ahead.orthogonal()
	_side = -_side
	swipes += 1
	sim.events.append(
		{"type": "swipe", "side": _side, "near": near, "far": far, "width": half, "top": top}
	)
	var before := sim.chunks_destroyed
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			var to := p - centre
			var along := to.dot(ahead)
			var inside := along >= near - r and along <= far + r
			return 1.0 if inside and absf(to.dot(across)) <= half + r else 0.0,
		sim.stat("swipe_damage") * sim.powers.hit_mult(),
		maxi(0, floori(sim.stand_y)),
		ceili(top)
	)
	cut += sim.chunks_destroyed - before
