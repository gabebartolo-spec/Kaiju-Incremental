extends SceneTree
@warning_ignore_start("unsafe_call_argument")
## Plays scripted rampages and writes what the sim did on every tick, so the C# sim can be held to
## the same log bit for bit (D-470 U2): `dotnet run --project unity/SimTests` replays the inputs.
## The native voxel extension is off: its GDScript fallback is the reference until U3.
##
##   godot --headless --path . --script tools/unity/dump_sim_log.gd
##
## Set SIM_LOG_TEXT=<dir> to also write each run's full text there, to diff against the C# one.

const OUT := "res://unity/SimTests/golden/log.json"
const DT := 1.0 / 60.0
const SPECIES := "reptilian"
const TICKS := 3600
## (city tier, seed, signature, toughness): the abilities' four shapes on three sizes of city.
## The toughness keeps a walking croc alive to reach the buildings; one run dies at its own pace.
const RUNS: Array[Array] = [
	[1, 1, "lash", 20.0], [2, 5, "cone", 20.0], [3, 9, "leap", 20.0], [2, 12, "ring", 1.0]
]
## How long one held input lasts (ticks), how often it is a button, how far off the city's heading.
const HOLD := Vector2i(30, 150)
const BUTTON_CHANCE := 0.5
const HEADING := PI / 2.0
const SPREAD := 1.2
const STATE_EVERY := 30


func _initialize() -> void:
	VoxelSupport.use_native = false
	var rows: Array[Dictionary] = []
	for row: Array in RUNS:
		rows.append(_run(int(row[0]), int(row[1]), str(row[2]), float(row[3])))
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"dt": _hex(DT), "runs": rows}, "", false))
	file.close()
	print("wrote ", OUT)
	quit(0)


func _run(tier: int, run_seed: int, ability: String, toughness: float) -> Dictionary:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def(SPECIES), UpgradeTree.new(Content.upgrades())
	)
	stats["hp"] = float(stats["hp"]) * toughness
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", run_seed))
	var sim := RampageSim.new(
		stats, CityGrowth.tuning_for(Content.tuning(), tier), layout, Seeds.make("army", run_seed)
	)
	sim.ability_type = ability
	sim.emerge.start(sim)
	var script := _script(Seeds.make("golden", run_seed))
	var digests := PackedStringArray()
	var text := PackedStringArray()
	var tally := {}
	var at := 0
	for tick: int in TICKS:
		while at + 1 < script.size() and int(script[at + 1][0]) <= tick:
			at += 1
		var seg: Array = script[at]
		var move := Vector2(_float32(str(seg[1])), _float32(str(seg[2])))
		var events := sim.step(DT, move, tick == int(seg[0]) and bool(seg[3]), int(seg[4]))
		var line := _line(sim, events, tick)
		digests.append(line.md5_text())
		text.append(line)
		for e: Dictionary in events:
			var kind: String = e.get("type", "?")
			tally[kind] = int(tally.get(kind, 0)) + 1
	_write_text(text, tier, run_seed)
	print(
		(
			"run tier=%d seed=%d %s: chunks %d, hp %s, %d event kinds"
			% [tier, run_seed, ability, sim.chunks_destroyed, sim.hp, tally.size()]
		)
	)
	var row := {"tier": tier, "seed": run_seed, "ability": ability, "species": SPECIES}
	row["toughness"] = _hex(toughness)
	row.merge({"script": script, "digests": digests, "tally": tally})
	return row


## [from tick, move x bits, move y bits, signature, buttons] for each held input.
func _script(rng: RandomNumberGenerator) -> Array:
	var out := []
	var tick := 0
	while tick < TICKS:
		var angle := HEADING + rng.randf_range(-SPREAD, SPREAD)
		var move := Vector2.from_angle(angle)
		var buttons := 0
		if rng.randf() < BUTTON_CHANCE:
			var pick := [RampageSim.HELD, RampageSim.ULTIMATE, RampageSim.BREATH, Dash.BUTTON]
			buttons = int(pick[rng.randi_range(0, pick.size() - 1)])
		out.append([tick, _hex32(move.x), _hex32(move.y), rng.randf() < BUTTON_CHANCE, buttons])
		tick += rng.randi_range(HOLD.x, HOLD.y)
	return out


## One tick as text: the events, the body, the RNG; every STATE_EVERY ticks all buildings too.
func _line(sim: RampageSim, events: Array[Dictionary], tick: int) -> String:
	var parts := PackedStringArray()
	parts.append(_canon(events))
	parts.append(_canon(sim.kaiju_pos))
	parts.append(_canon(sim.facing))
	parts.append(_canon(sim.stand_y))
	parts.append(_canon(sim.hp))
	parts.append(_canon(sim.time_left))
	parts.append(_canon(sim.chunks_destroyed))
	parts.append(str(sim._rng.state))
	if tick % STATE_EVERY == 0:
		var alive := PackedInt64Array()
		for b: RampageSim.Building in sim.buildings:
			alive.append(b.frame.alive_count if b.frame != null else -1)
		parts.append(_canon(alive))
		parts.append(_canon(sim.result()))
	return " ".join(parts)


## A value as text in one exact form, written the same way by Sim/Verify/SimLog.cs.
func _canon(v: Variant) -> String:
	var text := _canon_scalar(v)
	if text == "":
		text = _canon_geometry(v)
	if text == "":
		text = _canon_container(v)
	if text == "":
		push_error("sim log: no text form for type %d" % typeof(v))
		quit(1)
	return text


func _canon_scalar(v: Variant) -> String:
	var text := ""
	match typeof(v):
		TYPE_NIL:
			text = "n"
		TYPE_BOOL:
			text = "b1" if v else "b0"
		TYPE_INT:
			text = "i%d" % v
		TYPE_FLOAT:
			text = "f" + _hex(v)
		TYPE_STRING, TYPE_STRING_NAME:
			text = "s" + JSON.stringify(str(v))
		TYPE_OBJECT:
			text = "o"
	return text


func _canon_geometry(v: Variant) -> String:
	var text := ""
	match typeof(v):
		TYPE_VECTOR2:
			text = "V(%s,%s)" % [_hex(v.x), _hex(v.y)]
		TYPE_VECTOR2I:
			text = "I(%d,%d)" % [v.x, v.y]
		TYPE_VECTOR3:
			text = "V(%s,%s,%s)" % [_hex(v.x), _hex(v.y), _hex(v.z)]
		TYPE_VECTOR3I:
			text = "I(%d,%d,%d)" % [v.x, v.y, v.z]
		TYPE_RECT2, TYPE_RECT2I:
			text = "R(%s,%s)" % [_canon(v.position), _canon(v.size)]
		TYPE_AABB:
			text = "A(%s,%s)" % [_canon(v.position), _canon(v.size)]
		TYPE_COLOR:
			text = "C(%s,%s,%s,%s)" % [_hex(v.r), _hex(v.g), _hex(v.b), _hex(v.a)]
	return text


func _canon_container(v: Variant) -> String:
	if v is Dictionary:
		var items := PackedStringArray()
		for key: Variant in v:
			items.append(_canon(key) + ":" + _canon(v[key]))
		return "{" + ",".join(items) + "}"
	if typeof(v) >= TYPE_ARRAY:
		return _list(v)
	return ""


func _list(v: Variant) -> String:
	var items := PackedStringArray()
	for item: Variant in v:
		items.append(_canon(item))
	return "[" + ",".join(items) + "]"


func _write_text(text: PackedStringArray, tier: int, run_seed: int) -> void:
	var dir := OS.get_environment("SIM_LOG_TEXT")
	if dir == "":
		return
	var file := FileAccess.open("%s/godot_%d_%d.txt" % [dir, tier, run_seed], FileAccess.WRITE)
	file.store_string("\n".join(text))
	file.close()


func _hex(value: Variant) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, float(value))
	return bytes.hex_encode()


func _hex32(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	return bytes.hex_encode()


func _float32(hex: String) -> float:
	return hex.hex_decode().decode_float(0)
