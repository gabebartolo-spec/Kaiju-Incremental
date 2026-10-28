extends "res://tests/lib/powers_base.gd"
## Leader's helicopter parity (VipHeli, D-149; kaiju-sim-review packet): the leader has its own
## seeded stream and only touches the sim through hit/step, so the same seeded rampage with the
## leader flying (on) and with no leader at all (off, state "none") plays the same army, air wing,
## rubble and non-vip events while the kaiju stands idle. Seeded by design: army seed 0.
##   godot --headless --path . --script tests/run_vip_parity_tests.gd

const KAIJU_AT := Vector2(-4.0, 0.0)
const SECONDS := 90.0


## What one idle rampage came to.
class Played:
	var types: Array[String] = []
	var rubble := 0.0
	var tanks := 0
	var helis := 0
	var vip := ""
	var chunks := 0
	var fates: Array[String] = []  # each forced gunship kill: id, fate, fall time, drift, crew


func suite_name() -> String:
	return "Vip parity"


func run_checks() -> void:
	await _t("_check_on_vs_off")
	await _t("_check_vip_kill_leaves_gunship_falls")


## One idle rampage of SECONDS; `leader` false takes the leader out (no roof to lift off from).
func _play(leader: bool, kill_at := -1.0) -> Played:
	var tree := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), tree
	)
	var city: Dictionary = Content.tuning()["city"]
	var layout := CityGen.generate(Seeds.make("city", 0), city)
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.ability_type = str(Content.species_def("reptilian")["ability"]["type"])
	sim.kaiju_pos = KAIJU_AT
	sim.facing = EAST
	if leader:
		sim.vip._spawn_at = 1.0
	else:
		sim.vip.state = "none"
	var out := Played.new()
	var t := 0.0
	var killed_vip := false
	var round_at := kill_at
	while t < SECONDS:
		if kill_at >= 0.0 and t >= round_at:
			if leader and not killed_vip:
				killed_vip = true
				sim.vip.down(false, "blow")
			out.fates.append_array(_shoot_down_gunships(sim))
			round_at += 10.0
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			var kind := str(event["type"])
			if not kind.begins_with("vip_") and Num.i(event.get("heli", 0)) != VipHeli.ID:
				out.types.append(kind)
		t += DT
	out.rubble = sim.rubble - sim.vip.paid
	out.tanks = sim.tanks_destroyed
	out.helis = sim.air.destroyed
	out.vip = sim.vip.state
	out.chunks = sim.chunks_destroyed
	return out


func _check_on_vs_off() -> void:
	var on := _play(true)
	var off := _play(false)
	var line := "VIP_PARITY on: %s %d events, rubble %.2f, tanks %d, helis %d "
	line += "| off: %s %d events, rubble %.2f"
	print(
		(
			line
			% [
				on.vip,
				on.types.size(),
				on.rubble,
				on.tanks,
				on.helis,
				off.vip,
				off.types.size(),
				off.rubble
			]
		)
	)
	check(on.vip != "waiting" and on.vip != "none", "on: the leader flew (%s)" % on.vip)
	check(off.vip == "none", "off: no leader (%s)" % off.vip)
	var counts := [on.types.size(), off.types.size()]
	check(on.types == off.types, "same non-vip events: %d vs %d" % counts)
	check(
		is_equal_approx(on.rubble, off.rubble), "same rubble %.2f vs %.2f" % [on.rubble, off.rubble]
	)
	var armies := [on.tanks, off.tanks, on.helis, off.helis]
	check(on.tanks == off.tanks and on.helis == off.helis, "same tanks %d/%d, helis %d/%d" % armies)


## Two gunships are called in, then every gunship in the sky falls to a light blow (it spins
## down, which draws the fall stream); returns what each one's fate came to.
func _shoot_down_gunships(sim: RampageSim) -> Array[String]:
	var fates: Array[String] = []
	for _i in 2:
		sim.air.spawn()  # an idle kaiju draws none this early: call two in
	var mark: int = sim.events.size()
	for heli: AirWing.Heli in sim.air.helis:
		heli.hp = 0.0
		heli.last_blow = 0.0
	sim.air.clear_dead()
	for i in range(mark, sim.events.size()):
		var event: Dictionary = sim.events[i]
		if str(event["type"]) == "heli_destroyed":
			var line := "%d %s %s %.4f %.4f %s"
			line = (
				line
				% [
					Num.i(event["heli"]),
					event.get("fate"),
					event.get("seconds"),
					Num.f(event.get("dx", 0.0)),
					Num.f(event.get("dz", 0.0)),
					event.get("crew")
				]
			)
			fates.append(line)
	return fates


## The leader shot down mid-flight, gunships up: every later gunship fall (drift, crew) is the
## same as in a rampage with no leader, because the leader's wreck draws from its own stream.
func _check_vip_kill_leaves_gunship_falls() -> void:
	var on := _play(true, 10.0)
	var off := _play(false, 10.0)
	print("VIP_KILL_PARITY fates on %d, off %d" % [on.fates.size(), off.fates.size()])
	check(on.fates.size() >= 3, "gunships fell after the leader (%d)" % on.fates.size())
	# The wreck falls like any gunship's and may smash city where it lands, which raises the
	# escalation the air wing's cap reads: then the leader run launches one more gunship late. So
	# every fate the leaderless run drew must come out the same (draws, drifts, crew) and extra
	# ones are allowed only after the wreck smashed more (this city: 776 chunks against 635).
	var same := on.fates.slice(0, off.fates.size()) == off.fates
	var smashed := on.chunks > off.chunks
	check(
		same and (on.fates.size() == off.fates.size() or smashed),
		(
			"same gunship fates and drifts with the leader killed (%d vs %d fates; chunks %d/%d)"
			% [on.fates.size(), off.fates.size(), on.chunks, off.chunks]
		)
	)
