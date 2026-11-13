extends SceneTree
## Writes where Godot's wet streets (scenes/weather_view.gd _place_smears) lay their smears in the
## rain at night (the streetlights are lit only then): the young croc's first city, a fixed grid of
## streetlights (a few out), the camera at a few places, so the Unity port
## (unity/Assets/Scripts/Rampage/WetStreets.cs) can be checked against it smear for smear.
## Windowed: the headless dummy renderer keeps no MultiMesh instance data.
##
##   bash C:/kt/gpu_slot.sh godot --path . --windowed
##     --script tools/unity/dump_wet_streets_golden.gd
##
## Output: unity/SimTests/golden/wet_streets.txt, read by WetStreetsCheck
## (`dotnet run --project unity/SimTests`). W: the rain layer's wet and window_lit; O: a camera
## place (index, x, z) and how many smears; M: one smear (index, x, y, z, r, g, b, a, width,
## length).

const OUT := "res://unity/SimTests/golden/wet_streets.txt"
const TIME := "night"  # dusk has lamp_energy 0: no lamp smears to check
const LAMPS_X := 15  # the lamp grid: 15 x 12, every 13 m by 17 m, from (-90, -80)
const LAMPS_Z := 12
const LAMP_STEP := Vector2(13.0, 17.0)
const LAMP_FROM := Vector2(-90.0, -80.0)
const LAMP_OUT_EVERY := 7  # every 7th lamp is out (energy 0)
const ORIGINS: Array[Vector2] = [
	Vector2(3.7, 11.3), Vector2(-41.2, 27.9), Vector2(66.4, -58.1), Vector2(400.3, 400.7)
]
const HOLDER := "extends Node3D\nvar sim: RampageSim\n"

var _lines: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Content.set_time(TIME)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	var script := GDScript.new()
	script.source_code = HOLDER
	script.reload()
	var holder := Node3D.new()
	holder.set_script(script)
	holder.set("sim", sim)
	root.add_child(holder)
	for i: int in LAMPS_X * LAMPS_Z:
		var light := PooledLight.new("lamp")
		light.light_color = Color("ffd59a")
		light.set_energy(0.0 if i % LAMP_OUT_EVERY == 3 else Look.value("lamp_energy"))
		var at := LAMP_FROM + Vector2(i % LAMPS_X, i / LAMPS_X) * LAMP_STEP
		light.position = Vector3(at.x, 2.4, at.y)
		holder.add_child(light)
	var view := WeatherView.new()
	view.layer = {"wet": WeatherView.layer_of("rain")["wet"]}  # no "rain": no particles headless
	holder.add_child(view)
	view.set_process(false)
	view._build_smears()
	_lines.append("W %.4f %.4f" % [Num.f(view.layer["wet"]), Look.value("window_lit")])
	var mm := view.smears.multimesh
	for k: int in ORIGINS.size():
		var o := ORIGINS[k]
		view._place_smears(Vector3(o.x, 30.0, o.y))
		var n := view._smear_used
		_lines.append("O %d %.4f %.4f %d" % [k, o.x, o.y, n])
		for i: int in n:
			var p := mm.get_instance_transform(i).origin
			var c := mm.get_instance_color(i)
			var d := mm.get_instance_custom_data(i)
			_lines.append(
				(
					"M %d %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f"
					% [i, p.x, p.y, p.z, c.r, c.g, c.b, c.a, d.r, d.g]
				)
			)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("wrote %s (%d lines)" % [OUT, _lines.size()])
	quit()
