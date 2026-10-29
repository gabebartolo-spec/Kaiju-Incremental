class_name Landmarks
extends RefCounted
## Builds a rampage's buildings from the city layout's entries (CityGen). An entry with a
## "landmark" id is a landmark: its Structure keeps only the chunks its baked model fills
## ("chunks", from data/landmarks.json via tools/landmarks/bake.py), so it stands and breaks in
## its own shape, and its chunks pay "rubble_bonus" times the usual rubble. A ring landmark's
## "arcs" (Arcs) make a breach bring down a whole section of it. Pure sim.


## A building from one layout entry: x, z (centre), w, d, h, tier, style, and for a landmark
## landmark, chunks, rubble_bonus; for a pool building (CityPool) model, facing, mirror, stretch,
## palette. Its chunks are chunk_hp x tier tough.
static func building(entry: Dictionary, chunk_hp: float) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.x = Num.f(entry["x"])
	b.z = Num.f(entry["z"])
	b.w = Num.i(entry["w"])
	b.d = Num.i(entry["d"])
	b.height = Num.i(entry["h"])
	b.tier = Num.i(entry["tier"])
	b.style = Num.i(entry["style"])
	b.frame = Structure.new(b.w, b.d, b.height, chunk_hp * b.tier)
	b.landmark = str(entry.get("landmark", ""))
	b.rubble_bonus = Num.f(entry.get("rubble_bonus", 1.0))
	b.hazard = str(entry.get("hazard", ""))
	if entry.has("model"):  # a pool building: its baked model's chunks, turned as placed
		b.model = str(entry["model"])
		b.variant = ModelVariant.of(entry)
		b.palette = Num.i(entry.get("palette", 0))
		var row := ModelVariant.row_of(b.model)
		if not row.is_empty():
			b.frame.keep(ModelVariant.chunks(row, b.variant))
	elif entry.has("chunks"):
		var shape: Array = entry["chunks"]
		b.frame.keep(shape)
	if entry.has("arcs"):
		var arcs: Dictionary = entry["arcs"]
		b.frame.arcs = Arcs.build(b.frame, arcs)
	return b
