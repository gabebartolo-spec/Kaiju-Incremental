extends RefCounted
## The view half of the ASSETS audit (tools/audit/asset_audit.gd): builds one city's decor
## (CityDecor) and street life (StreetLife) headless, as the city suite does, and counts what
## they place: props by kind, parked cars by paint, civilians by outfit, the stadium's sport.
## A prop's kind is told by the palette keys its voxels use (PROP_KEYS, first match wins); a
## prop matching none is counted as "prop:other:<keys>", so a new prop kind shows up unlisted.

const PROP_KINDS: Array[String] = [
	"traffic_island",
	"bollard",
	"quay_crates",
	"car",
	"streetlight",
	"playground",
	"flower_bed",
	"tree",
	"bush"
]
## kind -> a palette key prefix that marks it (tree: a prop that fells, see _kind).
const PROP_KEYS := {
	"traffic_island": "island_kerb",
	"bollard": "island_bollard",
	"quay_crates": "quay_crate",
	"car": "wheel",
	"streetlight": "pole",
	"playground": "play_",
	"flower_bed": "flower_",
	"bush": "bush",
}
const VIEW_KINDS: Array[String] = ["prop", "car", "civilian", "sport"]


static func needs_view(kind: String) -> bool:
	return kind in VIEW_KINDS


## city: [layout, index]. Returns {asset id: count}.
static func count(root: Node, base: Dictionary, tier: int, city: Array) -> Dictionary:
	var index: int = city[1]
	var tuning := CityGrowth.tuning_for(base, tier)
	var cfg: Dictionary = tuning["city"]
	var map_seed: int = preload("res://tools/audit/road_audit.gd").seeds(index + 1)[index]
	cfg["map_seed"] = map_seed
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var layout: Array[Dictionary] = city[0]
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", index))
	var holder := Node3D.new()
	root.add_child(holder)
	var decor := CityDecor.new(sim, Seeds.make("decor", index))
	holder.add_child(decor)
	var fx := Fx.new()
	holder.add_child(fx)
	var street := StreetLife.new(
		sim, fx, Seeds.make("civilians", index), Seeds.make("sport", index)
	)
	holder.add_child(street)
	await root.get_tree().process_frame
	var out := {}
	for group: Dictionary in decor._props._groups:
		_add(out, "prop:" + _kind(group))
		for key: String in group.get("keys", PackedStringArray()):
			if key.begins_with("car") and key.substr(3).is_valid_int():
				_add(out, "car:" + key)
				break
	for i: int in street.outfit.size():
		if street.outfit[i] < VoxelPerson.COP:
			_add(out, "civilian:%d" % street.outfit[i])
	for m: StadiumMatch in street.matches:
		_add(out, "sport:" + str(m.sport["id"]))
	holder.free()
	return out


static func _kind(group: Dictionary) -> String:
	var keys: PackedStringArray = group.get("keys", PackedStringArray())
	for kind: String in PROP_KINDS:
		if kind == "tree":
			if group.get("fells", false):
				return kind
			continue
		var mark: String = PROP_KEYS[kind]
		for key: String in keys:
			if key.begins_with(mark):
				return kind
	var unique := {}
	for key: String in keys:
		unique[key] = true
	var names := unique.keys()
	names.sort()
	return "other:" + "+".join(names)


static func _add(out: Dictionary, id: String) -> void:
	out[id] = Num.i(out.get(id, 0)) + 1
