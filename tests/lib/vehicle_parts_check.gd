class_name VehiclePartsCheck
extends RefCounted
## Each vehicle model (the tank, the gunship, the leader's helicopter) lists every part its class
## builds, and each part has voxels: a renamed or missing part in a .parts.json fails here by name.


static func check(check: Callable) -> void:
	var wanted := {
		TankModel.BASE: ["hull", "turret", "barrel"],
		HelicopterModel.BASE: ["body", "main_rotor", "tail_rotor", "gun"],
		HelicopterModel.VIP_BASE: ["body", "main_rotor", "tail_rotor", "gun"],
	}
	var height := Num.f(Content.section("vehicles")["heli_height"])
	for base: String in wanted:
		var parts := VehicleParts.new(base, height)
		var names: Array = wanted[base]
		for part: String in names:
			var listed := parts._parts.has(part)
			check.call(listed, "%s lists the part %s" % [base, part])
			if listed:
				var cells: int = parts._read(part).frames[0].cells.size()
				check.call(cells > 0, "%s part %s has voxels (%d)" % [base, part, cells])
