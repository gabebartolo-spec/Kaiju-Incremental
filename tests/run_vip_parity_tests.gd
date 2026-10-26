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


func suite_name() -> String:
	return "Vip parity"


func run_checks() -> void:
	await _t("_check_on_vs_off")


## One idle rampage of SECONDS; `leader` false takes the leader out (no roof to lift off from).
func _play(leader: bool) -> Played:
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
	while t < SECONDS:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			var kind := str(event["type"])
			if not kind.begins_with("vip_") and Num.i(event.get("heli", 0)) != VipHeli.ID:
				out.types.append(kind)
		t += DT
	out.rubble = sim.rubble - sim.vip.paid
	out.tanks = sim.tanks_destroyed
	out.helis = sim.air.destroyed
	out.vip = sim.vip.state
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
