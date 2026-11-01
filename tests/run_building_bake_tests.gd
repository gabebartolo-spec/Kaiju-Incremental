extends "res://tests/lib/runner.gd"
## Building bake suite (director 2026-11-02, "lets make the game playable": the title waited ~4 s on
## the GDScript bake of its buildings). BuildingNative bakes a plain BuildingVoxels in native code
## (KaijuBuilding); on vs off, every building of the stage-2 city bakes the same shell, slabs and
## debris samples byte for byte, and the kinds with their own face_mask stay in the GDScript.
## Seeded by design: the tuning's map seed; no RNG, no clock.
##   godot --headless --path . --script tests/run_building_bake_tests.gd

const Harbour := preload("res://tests/lib/city_harbour.gd")
## Buildings compared (the oracle costs ~0.1 s a building): the first of the city's list, which
## holds every kind of lot the title draws.
const COMPARED := 40

var _native := false


func suite_name() -> String:
	return "Building bake"


func run_checks() -> void:
	_native = ClassDB.class_exists("KaijuBuilding")
	await _t("_check_native_loaded")
	await _t("_check_native_matches_oracle")


func _check_native_loaded() -> void:
	if _native:
		check(true, "the KaijuBuilding class is registered by the extension")
	elif OS.get_environment("KAIJU_NATIVE_REQUIRED") == "1":
		check(false, "native library is required (KAIJU_NATIVE_REQUIRED=1); KaijuBuilding missing")
	else:
		print("SKIP: KaijuBuilding is not registered; build native/ to run the native checks")
		check(true, "native library not built: native checks skipped on purpose")


## On, a plain building bakes natively and its arrays and samples equal the GDScript's; off, or a
## kind with its own face_mask, the GDScript bakes (BuildingNative.bake declines).
func _check_native_matches_oracle() -> void:
	if not _native:
		return
	var sim := Harbour._fresh(2, Num.i(Content.section("city")["map_seed"]))
	var bs: Array[RampageSim.Building] = sim.buildings
	var party := BuildingView.party_walls(bs)
	var finish := VoxelAO.finish_table()
	var noise := Look.value("color_noise")
	var plain := 0
	var masked := 0
	var same := 0
	var declined := 0
	var wrong: Array[int] = []
	var first: BuildingVoxels = null
	for k: int in bs.size():
		if plain >= COMPARED and masked > 0:
			break
		var v := BuildingView.voxels_of(bs[k], Color.GRAY, party[k])
		var is_plain: bool = v.get_script() == BuildingVoxels
		if not is_plain:
			masked += 1
			if BuildingNative.bake(v, finish, noise) == null:
				declined += 1
			continue
		if plain >= COMPARED:
			continue
		plain += 1
		if first == null:
			first = v
		BuildingNative.use_native = false
		var off := BuildingMesher.new(v)
		BuildingNative.use_native = true
		var on := BuildingMesher.new(v)
		if _digest(off) == _digest(on):
			same += 1
		else:
			wrong.append(k)
	BuildingNative.use_native = true
	check(BuildingNative.bake(first, finish, noise) != null, "on: a plain building bakes natively")
	BuildingNative.use_native = false
	check(BuildingNative.bake(first, finish, noise) == null, "off: the native bake declines")
	BuildingNative.use_native = true
	sim.dispose()
	check(plain == COMPARED, "%d plain buildings compared" % plain)
	check(same == plain, "native == GDScript bake on %d of %d (differ: %s)" % [same, plain, wrong])
	check(
		masked > 0 and declined == masked,
		"%d of %d masked kinds left to GDScript" % [declined, masked]
	)


func _digest(m: BuildingMesher) -> PackedByteArray:
	return var_to_bytes([m._shell_arrays, m._slab_arrays, m.samples])
