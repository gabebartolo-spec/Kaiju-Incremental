extends RefCounted
## No freeway deck stands in the fixed front (director 2026-11-01, D-432: "i really hate this
## bridge, i have no idea why its even in the game, remove it entirely"). The skyline's elevated
## waterfront expressway ran 9 m inside the old quay; once the sea came in to the coast (D-381)
## it stood on pillars across the whole bay, read as a bridge, and the two inland freeways
## started in the water beside it. The city suite's check, called from its D-062 loop for each
## stage and map_seed: with a harbour, no skyline concrete box (a deck, parapet or pillar;
## CitySkyline.plain_drawn) and no skyline lamp has its centre between the bay's mouth (the
## coast, where the open sea begins; the far shore's own quay lies well past it) and the front's
## back street. Before the fix every city failed it (about 160 shore segments); after it none does.


static func check(
	tier: int, map_seed: int, sim: RampageSim, skyline: CitySkyline, check_fn: Callable
) -> void:
	var front := CityHarbour.rect_of(sim.city)
	if not front.has_area():
		return
	var mouth := Num.f(CityGen.map(sim.city)["harbour"]["mouth"])
	var edge := front.end.y  # the back street: the random grid starts south of it
	var decks := 0
	var first := ""
	for box: Dictionary in skyline.plain_drawn():
		if not box["concrete"]:
			continue
		var t: Transform3D = box["t"]
		if t.origin.z >= mouth and t.origin.z < edge:
			decks += 1
			if first.is_empty():
				first = str(t.origin)
	var lamps := 0
	for at: Vector3 in skyline._lamps:
		if at.z >= mouth and at.z < edge:
			lamps += 1
	check_fn.call(
		decks == 0 and lamps == 0,
		(
			"stage %d, map_seed %d: no freeway in the front (z %.0f to %.0f): %d concrete boxes"
			+ " (first at %s), %d lamps"
		)
		% [tier, map_seed, mouth, edge, decks, first, lamps]
	)
