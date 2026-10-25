class_name CreationDish
extends RefCounted
## The dish in Kaiju Creation's cradle (D-207): the agar's clean surface, the steel band round it
## and the glass petri dish ring, built in the cradle's cells. Builders only: CreationLab owns the
## nodes. Sizes and colours: tuning "creation" "lab" "dish" and "colors".


## The dish's agar as one clean surface: the model's lumps above it removed and its top cells one
## even colour (the texture's grain, sampled per block, read as blotches). On it stands the glass
## petri dish (director 2026-10-25: "Glass dish in the cradle"): a low, thin ring of pale glass
## with a bright rim, so it reads as a shallow dish and not a sandpit.
static func clean_dish(cradle: VoxelBuilder) -> void:
	var dish: Dictionary = CreationSet.cfg()["dish"]
	var top := Num.i(dish["surface_y"]) - 1
	var flat := Num.i(dish["flat"])
	var agar := CreationSet.color("agar")
	for cell: Vector3i in cradle.colors.keys():
		var r2 := cell.x * cell.x + cell.z * cell.z
		if r2 <= flat * flat and cell.y > top:
			cradle.cells.erase(cell)
			cradle.colors.erase(cell)
		elif r2 <= Num.i(dish["radius"]) * Num.i(dish["radius"]) and cell.y == top:
			cradle.colors[cell] = agar
	var r := Num.i(dish["radius"])
	for x: int in range(-r, r + 1):
		for z: int in range(-r, r + 1):
			var cell := Vector3i(x, top, z)
			if x * x + z * z <= r * r and not cradle.colors.has(cell):
				cradle.put_color(cell, agar)
	_steel_band(cradle, top)
	_glass_ring(cradle, top + 1)


## The model's beige inner wall round the dish read as brown dirt beside the clear glass (the
## director 2026-10-25: "more clear glass, less brown dirt"): its pale, unsaturated warm blocks
## within band cells of the dish turn steel at the same brightness; the yellow hazard paint is
## saturated and stays.
static func _steel_band(cradle: VoxelBuilder, top: int) -> void:
	var dish: Dictionary = CreationSet.cfg()["dish"]
	var reach := Num.i(dish["radius"]) + Num.i(dish["band"])
	var steel := CreationSet.color("steel")
	for cell: Vector3i in cradle.colors.keys():
		var col: Color = cradle.colors[cell]
		var near := cell.x * cell.x + cell.z * cell.z <= reach * reach and cell.y >= top
		if near and col.h > 0.04 and col.h < 0.22 and col.s < 0.45:
			cradle.colors[cell] = Color.from_hsv(steel.h, steel.s, col.v)


static func _glass_ring(cradle: VoxelBuilder, floor_y: int) -> void:
	var g: Dictionary = CreationSet.cfg()["dish"]["glass"]
	var r0 := Num.f(g["inner"])
	var r1 := Num.f(g["outer"])
	var h := Num.i(g["height"])
	var n := ceili(r1)
	for x: int in range(-n, n + 1):
		for z: int in range(-n, n + 1):
			var r := Vector2(x, z).length()
			if r < r0 or r > r1:
				continue
			for dy: int in h:
				var col := CreationSet.color("glass")
				if dy == h - 1:
					col = (
						CreationSet.color("glint")
						if _in_arc(x, z, g["glint"])
						else CreationSet.color("glass_rim")
					)
				cradle.put_color(Vector3i(x, floor_y + dy, z), col)


## Moves the agar's top cells out of the cradle and draws them in clean tones (_agar_tone): the
## look's per-block colour grain read as speckle on the agar.
static func agar_node(cradle: VoxelBuilder) -> MultiMeshInstance3D:
	var dish: Dictionary = CreationSet.cfg()["dish"]
	var top := Num.i(dish["surface_y"]) - 1
	var r := Num.f(dish["radius"])
	var agar := VoxelBuilder.new()
	for cell: Vector3i in cradle.colors.keys():
		if cell.y == top and Vector2(cell.x, cell.z).length() <= r:
			agar.put_color(cell, CreationSet.color("agar"))
			cradle.cells.erase(cell)
			cradle.colors.erase(cell)
	agar.inset = CreationSet.gapless()
	agar.noise = false
	var node := agar.build(
		{}, CreationSet.voxel_of("cradle"), Num.f(CreationSet.cfg()["glow"]), Vector3.ZERO
	)
	var inner := Num.f(dish["glass"]["inner"])
	for i: int in agar.built_cells.size():
		node.multimesh.set_instance_color(i, _agar_tone(agar.built_cells[i], inner, inner))
	return node


static func _in_arc(x: int, z: int, raw: Variant) -> bool:
	var arc: Array = raw
	var a := fposmod(rad_to_deg(atan2(z, x)), 360.0)
	return a >= Num.f(arc[0]) and a <= Num.f(arc[1])


## The agar's tone at a block: three steps from the middle out and a dark ring against the glass.
static func _agar_tone(c: Vector3i, r: float, inner: float) -> Color:
	var d := Vector2(c.x, c.z).length()
	if d >= inner - 1.0:
		return CreationSet.color("agar_ring")
	if d > r * 0.72:
		return CreationSet.color("agar_rim")
	return CreationSet.color("agar_mid") if d > r * 0.4 else CreationSet.color("agar")
