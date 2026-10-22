class_name CityCurve
extends RefCounted
## The shape of the city's sound over one rampage (D-155, "panic then eerie quiet"), as pure
## functions of tuning "city_sound": no node, no clock, nothing decided. CitySound and MusicLayers
## ask it where the rampage is (phase) and how loud each bed should be there; the tests ask it
## the same, so the curve in data/tuning.json is the one thing that shapes the mix.


## How far into its ruin the city is, 0..1: the share of the city destroyed and the share of its
## people who have fled, each scaled to its "full" value and capped, blended by destruction_weight.
## Both only ever grow, so the phase never goes back.
static func phase(destruction: float, fled: int, population: float, cfg: Dictionary) -> float:
	var p: Dictionary = cfg["phase"]
	var by_city := clampf(destruction / Num.f(p["destruction_full"]), 0.0, 1.0)
	var share := float(fled) / maxf(1.0, population)
	var by_people := clampf(share / Num.f(p["fled_full"]), 0.0, 1.0)
	var weight := Num.f(p["destruction_weight"])
	return by_city * weight + by_people * (1.0 - weight)


## The bed's level in dB at `at` (a phase): its curve's keys are [phase, dB], ascending, and the
## level is linear between them (and held flat before the first and after the last).
static func level(bed: String, at: float, cfg: Dictionary) -> float:
	var keys: Array = cfg["beds"][bed]["curve"]
	return along(keys, at)


## The value of a [x, y] key list at x = `at`, linear between keys, flat beyond the ends.
static func along(keys: Array, at: float) -> float:
	var first: Array = keys[0]
	if at <= Num.f(first[0]):
		return Num.f(first[1])
	for i: int in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if at <= Num.f(b[0]):
			var span := maxf(Num.f(b[0]) - Num.f(a[0]), 0.0001)
			return lerpf(Num.f(a[1]), Num.f(b[1]), (at - Num.f(a[0])) / span)
	var last: Array = keys[keys.size() - 1]
	return Num.f(last[1])


## How far through its fade-in a music stem is at `at`: 0 before enter, 1 from full on. The
## stem's level is its dB between silent_db and 0 on that share.
static func stem_db(stem: Dictionary, at: float, silent_db: float) -> float:
	var enter := Num.f(stem["enter"])
	var full := Num.f(stem["full"])
	var share := clampf((at - enter) / maxf(full - enter, 0.0001), 0.0, 1.0)
	return lerpf(silent_db, 0.0, share)
