class_name VipBlock
extends RefCounted
## The leader's payout is about a city block (VipHeli, D-149): within LO..HI of the mean block's
## worth for each city size, the worth being the biomass every building in the arena pays at full
## strength, over the blocks that hold any. Seeded by design: city seed 0.

const LO := 0.7
const HI := 1.4


static func run(check: Callable) -> void:
	var payouts: Array = Content.section("vip")["payout"]
	for tier: int in 3:
		var block := mean_block(tier + 1)
		var pay := Num.f(payouts[tier])
		check.call(
			pay >= block * LO and pay <= block * HI,
			"tier %d pays %.1f for a block worth %.1f" % [tier + 1, pay, block]
		)


## The mean worth of a block of the city at size tier `tier`: what its chunks pay when smashed.
static func mean_block(tier: int) -> float:
	var tuning := CityGrowth.tuning_for(Content.tuning(), tier)
	var city: Dictionary = tuning["city"]
	var layout := CityGen.generate(Seeds.make("city", 0), city)
	var blocks: Array = CityGen.map(city)["blocks"]
	var half := CityGen.half_extent(city) + Num.f(city["arena_margin"])
	var held := {}
	var total := 0.0
	for entry: Dictionary in layout:
		var b := Landmarks.building(entry, Num.f(city["chunk_hp"]))
		if not CityBand.touches(b.x, b.z, Vector2(b.w, b.d), half):
			continue
		total += b.frame.alive_count * b.tier * Num.f(city["chunk_rubble"]) * b.rubble_bonus
		for i: int in blocks.size():
			var row: Dictionary = blocks[i]
			var rect: Rect2 = row["rect"]
			if rect.grow(1.0).has_point(Vector2(b.x, b.z)):
				held[i] = true
				break
	return total / maxf(1.0, float(held.size()))
