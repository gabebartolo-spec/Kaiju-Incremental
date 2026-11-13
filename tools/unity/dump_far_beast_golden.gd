extends SceneTree
## Writes where Godot's far beast (the insectoid adult KaijuModel, HexapodGait) puts its feet down, standing and
## walking, so the Unity port (unity/Assets/Scripts/Rampage/FarBeast*.cs) can be checked against it frame for frame.
##
##   godot --headless --fixed-fps 60 --path . --script tools/unity/dump_far_beast_golden.gd
##
## Output: unity/SimTests/golden/far_beast.txt, read by FarBeastCheck (`dotnet run --project unity/SimTests`).
## One line per footfall: mode, frame, foot, strength, x, y, z (the model's own units); END the thorax at the last frame.

const OUT := "res://unity/SimTests/golden/far_beast.txt"
const FRAMES := 300
const WALK_SPEED := 0.9  # model units a second, along +x, facing it

var _frame := 0
var _lines: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for mode: String in ["stand", "walk"]:
		var def: Dictionary = Content.species_def(str(Content.section("skyline_rampage")["species"]))
		var colors: Dictionary = def["colors"]
		var model := KaijuModel.new(str(Content.section("skyline_rampage")["species"]), colors, "adult")
		root.add_child(model)
		await process_frame
		model.foot_planted.connect(_planted.bind(mode))
		var dt := 1.0 / 60.0
		for f: int in FRAMES:
			_frame = f
			if mode == "walk":
				model.position.x += WALK_SPEED * dt
				model.rotation.y = PI * 0.5
			model.animate(dt, 1.0)
		var rig := model.find_children("*", "KaijuRig", true, false)[0] as KaijuRig
		var p: Vector3 = rig.bone("thorax0").global_position
		_lines.append("END %s thorax %.4f %.4f %.4f" % [mode, p.x, p.y, p.z])
		model.queue_free()
		await process_frame
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("wrote %s (%d lines)" % [OUT, _lines.size()])
	quit()


func _planted(id: String, strength: float, at: Vector3, mode: String) -> void:
	_lines.append("FF %s %d %s %.4f %.4f %.4f %.4f" % [mode, _frame, id, strength, at.x, at.y, at.z])
