extends SceneTree
## Writes what Godot's own RNG and hash() produce, so the C# sim can be checked against them bit
## for bit (D-470 U2). Floats are written as their bits, so nothing rounds on the way.
##
##   godot --headless --path . --script tools/unity/dump_sim_golden.gd
##
## Output: unity/SimTests/golden/rng.json, read by `dotnet run --project unity/SimTests`.

const OUT := "res://unity/SimTests/golden/rng.json"
const STREAM_SEEDS: Array[int] = [0, 1, 42, 0x4B41494A, 4294967295, 1099511627776]
const FLOAT_RANGES: Array[Vector2] = [Vector2(0.0, TAU), Vector2(-3.5, 9.25), Vector2(4.0, 24.0)]
const INT_RANGES: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(-5, 5), Vector2i(7, 7), Vector2i(10, 1), Vector2i(0, 1000003)
]
const ROUNDS := 40
const STRINGS: Array[String] = ["", "a", "city", "1262568778:city:0", "héllo", "炎", "🔥x"]
const VECTORS: Array[Vector4i] = [
	Vector4i(0, 0, 0, 0), Vector4i(4, 6, 8, 12345), Vector4i(-1, 2, -3, 4), Vector4i(7, 11, 13, 91)
]
const ARRAYS: Array[Array] = [[0, 0.0, 0.0], [7, -192.25, 235.5], [20261108, 0.01, -0.0]]
const SEED_ROWS: Array[Array] = [
	["city", 0, 1], ["army", 2, 2], ["breath_bolt", 3, 77], ["fire", 0, 4294967295]
]


func _initialize() -> void:
	var out := {
		"streams": _streams(),
		"strings": _strings(),
		"vectors": _vectors(),
		"arrays": _arrays(),
		"seeds": _seeds(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(out, " "))
	file.close()
	print("golden: wrote ", OUT)
	quit()


func _streams() -> Array:
	var rows := []
	for start: int in STREAM_SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = start
		var steps := []
		for _round: int in ROUNDS:
			steps.append(["randi", str(rng.randi())])
			steps.append(["randf", _bits32(rng.randf())])
			for r: Vector2 in FLOAT_RANGES:
				steps.append(["randf_range", r.x, r.y, _bits32(rng.randf_range(r.x, r.y))])
			for r: Vector2i in INT_RANGES:
				steps.append(["randi_range", r.x, r.y, str(rng.randi_range(r.x, r.y))])
		rows.append({"seed": start, "steps": steps, "state": str(rng.state)})
	return rows


func _strings() -> Array:
	var rows := []
	for text: String in STRINGS:
		rows.append({"text": text, "hash": hash(text)})
	return rows


func _vectors() -> Array:
	var rows := []
	for v: Vector4i in VECTORS:
		rows.append({"v": [v.x, v.y, v.z, v.w], "hash": hash(v)})
	return rows


func _arrays() -> Array:
	var rows := []
	for row: Array in ARRAYS:
		var a: float = row[1]
		var b: float = row[2]
		rows.append({"i": row[0], "a": _bits64(a), "b": _bits64(b), "hash": hash(row)})
	return rows


func _seeds() -> Array:
	var rows := []
	for row: Array in SEED_ROWS:
		var stream: String = row[0]
		var index: int = row[1]
		var salt: int = row[2]
		var made := Seeds.make(stream, index)
		var derived := Seeds.derive(made, salt)
		(
			rows
			. append(
				{
					"stream": stream,
					"index": index,
					"salt": salt,
					"seed": made.seed,
					"derived": derived.seed,
				}
			)
		)
	return rows


## Little-endian bytes, read back as a big-endian hex number.
func _bits32(value: float) -> String:
	return _hex(PackedFloat32Array([value]).to_byte_array())


func _bits64(value: float) -> String:
	return _hex(PackedFloat64Array([value]).to_byte_array())


func _hex(bytes: PackedByteArray) -> String:
	bytes.reverse()
	return bytes.hex_encode()
