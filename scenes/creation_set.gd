class_name CreationSet
extends RefCounted
## The Kaiju Creation lab set (D-207, the board approved 2026-10-25): Tripo props voxelised to the
## game's blocks (assets/lab/*.kvox, one block size), a block bench and back wall, a cold key lamp,
## a warm rim and the screens' glow, under Shader Cinematic (D-104). The rack's vials are painted
## per titan (unlocked: its genome glowing; locked: dark) and the croc's vial cells lift out so it
## can pour; the monitor screens are painted as lit readouts. Builders only: CreationLab owns the
## nodes. Every size, place and colour: tuning "creation" "lab".


static func cfg() -> Dictionary:
	return Content.section("creation")["lab"]


static func color(key: String) -> Color:
	var colors: Dictionary = cfg()["colors"]
	return Color(str(colors[key]))


static func energy(key: String) -> float:
	var energies: Dictionary = cfg()["energy"]
	return Num.f(energies[key])


static func vec(raw: Variant) -> Vector3:
	var xyz: Array = raw
	return Vector3(Num.f(xyz[0]), Num.f(xyz[1]), Num.f(xyz[2]))


## The prop's voxels from its .kvox (empty if the file is missing).
static func read(name: String) -> VoxelBuilder:
	var props: Dictionary = cfg()["props"]
	var row: Dictionary = props[name]
	var kv := Kvox.read(str(row["path"]))
	return kv.frames[0] if not kv.frames.is_empty() else VoxelBuilder.new()


## A node placed and turned by the prop's data row, holding `vox` built as one MultiMesh. A .kvox
## faces -Z; the yaw is added to a half turn so the prop's front faces the camera.
static func place(parent: Node3D, name: String, vox: VoxelBuilder) -> Node3D:
	var props: Dictionary = cfg()["props"]
	var row: Dictionary = props[name]
	var holder := Node3D.new()
	holder.name = name.capitalize()
	holder.position = vec(row["at"])
	holder.rotation_degrees.y = Num.f(row["yaw"]) + 180.0
	parent.add_child(holder)
	var voxel := Num.f(cfg()["voxel"])
	vox.inset = gapless()
	holder.add_child(vox.build({}, voxel, Num.f(cfg()["glow"]), Vector3.ZERO))
	return holder


## The lab's blocks are drawn whole: the look's inset grid lines, fine on a city block seen from
## afar, read as speckle on blocks this small this close.
static func gapless() -> float:
	return 1.0 / maxf(Look.value("voxel_inset"), 0.01)


## The dish's agar as one clean surface: the model's lumps above it removed and its top cells one
## even colour (the texture's grain, sampled per block, read as blotches). On it stands the glass
## petri dish (director 2026-10-25: "Glass dish in the cradle"): a low, thin ring of pale glass
## with a bright rim, so it reads as a shallow dish and not a sandpit.
static func clean_dish(cradle: VoxelBuilder) -> void:
	var dish: Dictionary = cfg()["dish"]
	var top := Num.i(dish["surface_y"]) - 1
	var flat := Num.i(dish["flat"])
	var agar := color("agar")
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
	_glass_ring(cradle, top + 1)


static func _glass_ring(cradle: VoxelBuilder, floor_y: int) -> void:
	var g: Dictionary = cfg()["dish"]["glass"]
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
				var col := color("glass_rim") if dy == h - 1 else color("glass")
				cradle.put_color(Vector3i(x, floor_y + dy, z), col)


## Moves the agar's top cells out of the cradle and draws them flat, darkening softly to the rim:
## the look's per-block colour grain read as speckle on the agar.
static func agar_node(cradle: VoxelBuilder) -> MultiMeshInstance3D:
	var dish: Dictionary = cfg()["dish"]
	var top := Num.i(dish["surface_y"]) - 1
	var r := Num.f(dish["radius"])
	var agar := VoxelBuilder.new()
	for cell: Vector3i in cradle.colors.keys():
		if cell.y == top and Vector2(cell.x, cell.z).length() <= r:
			agar.put_color(cell, color("agar"))
			cradle.cells.erase(cell)
			cradle.colors.erase(cell)
	agar.inset = gapless()
	var node := agar.build({}, Num.f(cfg()["voxel"]), Num.f(cfg()["glow"]), Vector3.ZERO)
	for i: int in agar.built_cells.size():
		var c := agar.built_cells[i]
		var k := smoothstep(0.5, 1.0, Vector2(c.x, c.z).length() / r)
		node.multimesh.set_instance_color(i, color("agar").lerp(color("agar_rim"), k))
	return node


## Repaints every cell of `vox` through fn(cell, colour) -> colour.
static func paint(vox: VoxelBuilder, fn: Callable) -> void:
	for cell: Vector3i in vox.colors.keys():
		var col: Color = vox.colors[cell]
		vox.colors[cell] = fn.call(cell, col)


## Which of the rack's three vials a cell belongs to (0 = the left vial seen from the front).
static func slot(cell: Vector3i) -> int:
	var v: Dictionary = cfg()["vials"]
	if cell.x > Num.i(v["split_hi"]):
		return 0
	return 1 if cell.x >= Num.i(v["split_lo"]) else 2


static func is_liquid(col: Color) -> bool:
	var v: Dictionary = cfg()["vials"]
	var hues: Array = v["hue_range"]
	return (
		col.s > Num.f(v["min_saturation"])
		and col.v > Num.f(v["min_value"])
		and col.h > Num.f(hues[0])
		and col.h < Num.f(hues[1])
	)


## The rack's liquid per titan: an unlocked genome glows evenly in the colour it pours (lighter
## streaks read as white specks, a lighter tint glowed cream), a locked one is dark glass.
static func vial_color(cell: Vector3i, col: Color, titans: Array[Dictionary]) -> Color:
	var v: Dictionary = cfg()["vials"]
	var by: Array = v["box_y"]
	if cell.y > Num.i(by[1]) and col.v < Num.f(v["cap_dark"]):
		return color("rack_cap")
	if not is_liquid(col) and not _helix_print(cell, col):
		return col
	var i := titan_in(slot(cell))
	if i < 0 or i >= titans.size() or titans[i]["locked"] == true:
		return color("locked")
	var genome: Color = titans[i]["genome"]
	return Color(genome, 0.0)


## The model's white DNA print inside the liquid (pale, unsaturated, so not caught as liquid): it
## stood out as white specks in the dark locked vials, so it takes the liquid's colour too. Only
## inside the liquid columns, so the rack frame's highlights keep their colour.
static func _helix_print(cell: Vector3i, col: Color) -> bool:
	var v: Dictionary = cfg()["vials"]
	var by: Array = v["box_y"]
	var bz: Array = v["column_z"]
	var inside := cell.y >= Num.i(by[0]) and cell.y <= Num.i(by[1])
	inside = (
		inside
		and _within(cell.x, v["columns_x"])
		and cell.z >= Num.i(bz[0])
		and cell.z <= Num.i(bz[1])
	)
	return inside and col.v > Num.f(v["print_value"]) and col.s < Num.f(v["min_saturation"])


## Which titan of the rack list fills vial `slot` (-1: none).
static func titan_in(vial: int) -> int:
	var slots: Array = cfg()["vials"]["titan_slots"]
	for i: int in slots.size():
		if Num.i(slots[i]) == vial:
			return i
	return -1


## The vial titan `index` fills.
static func vial_of(index: int) -> int:
	var slots: Array = cfg()["vials"]["titan_slots"]
	return Num.i(slots[index])


## The middle of a vial's liquid column (x, z in the rack's cells): where the needle goes down.
static func vial_centre(vial: int) -> Vector2:
	var v: Dictionary = cfg()["vials"]
	var xs: Array = v["columns_x"][vial]
	var zs: Array = v["column_z"]
	return Vector2(Num.f(xs[0]) + Num.f(xs[1]), Num.f(zs[0]) + Num.f(zs[1])) * 0.5


## Moves vial `vial`'s painted liquid (the glowing cells) out of `rack`; returns cell -> the dark
## glass it shows once drained. Also cuts the port in the rack's top over it for the needle.
static func take_liquid(rack: VoxelBuilder, vial: int) -> Dictionary:
	var v: Dictionary = cfg()["vials"]
	var centre := vial_centre(vial)
	var radius := Num.f(v["port_radius"])
	var empties := {}
	for cell: Vector3i in rack.colors.keys():
		var col: Color = rack.colors[cell]
		var near := Vector2(cell.x, cell.z).distance_to(centre) <= radius
		if near and cell.y >= Num.i(v["port_from_y"]):
			rack.cells.erase(cell)
			rack.colors.erase(cell)
		elif col.a < 0.5 and slot(cell) == vial:
			empties[cell] = color("locked")
			rack.cells.erase(cell)
			rack.colors.erase(cell)
	return empties


## Moves the Special K canister's liquid (its violet glass) out of `vox`; returns cell -> the dark
## glass it shows once drawn, and cuts the port in its lid for the needle.
static func take_canister_liquid(vox: VoxelBuilder) -> Dictionary:
	var c: Dictionary = cfg()["canister"]
	var hues: Array = c["hue"]
	var radius := Num.f(c["port_radius"])
	var empties := {}
	for cell: Vector3i in vox.colors.keys():
		var col: Color = vox.colors[cell]
		if Vector2(cell.x, cell.z).length() <= radius and cell.y >= Num.i(c["port_from_y"]):
			vox.cells.erase(cell)
			vox.colors.erase(cell)
		elif (
			col.h > Num.f(hues[0]) and col.h < Num.f(hues[1]) and col.s > Num.f(c["min_saturation"])
		):
			empties[cell] = color("locked")
			vox.cells.erase(cell)
			vox.colors.erase(cell)
	return empties


## The monitor screens: the glass on the front face inside the data's rectangles turns dark green,
## with rows of lit readout bars.
static func screen_color(cell: Vector3i, col: Color) -> Color:
	var s: Dictionary = cfg()["screens"]
	if cell.z > Num.i(s["front_z"]) or not (_within(cell.x, s["x"]) and _within(cell.y, s["y"])):
		return col
	var bar := absi(hash(Vector2i(cell.y, floori(cell.x / 6.0)))) % 3 != 0
	if cell.y % 4 == 0 and bar:
		return Color(color("screen"), 0.0)
	return color("screen_glass")


static func _within(v: int, raw: Variant) -> bool:
	var ranges: Array = raw
	for r: Array in ranges:
		if v >= Num.i(r[0]) and v <= Num.i(r[1]):
			return true
	return false


## A flat slab of blocks one cell thick (the bench, lying; the wall, standing), centred on `at`.
static func slab(parent: Node3D, key: String, standing: bool) -> void:
	var row: Dictionary = cfg()[key]
	var size: Array = row["size"]
	var voxel := Num.f(cfg()["voxel"])
	var nx := roundi(Num.f(size[0]) / voxel)
	var ny := roundi(Num.f(size[1]) / voxel)
	var vox := VoxelBuilder.new()
	var base := color(key)
	for i: int in nx:
		for j: int in ny:
			var cell := Vector3i(
				i - floori(nx * 0.5), j if standing else -1, 0 if standing else j - floori(ny * 0.5)
			)
			vox.put_color(cell, Look.jitter(base, cell, 207))
	var holder := Node3D.new()
	holder.position = vec(row["at"])
	parent.add_child(holder)
	vox.inset = gapless()
	holder.add_child(vox.build({}, voxel, 0.0, Vector3.ZERO))


## The world: a near-black room, the look's AO, glow, contrast and saturation, a thin haze.
static func environment(parent: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = color("background")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = color("ambient")
	env.ambient_light_energy = energy("ambient")
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_intensity = Look.value("ssao")
	env.ssao_power = Look.value("ssao_power")
	env.glow_enabled = Look.value("glow") > 0.0
	env.glow_intensity = Look.value("glow")
	env.glow_hdr_threshold = Look.value("glow_threshold")
	env.adjustment_enabled = true
	env.adjustment_saturation = Look.value("saturation")
	env.adjustment_contrast = Look.value("contrast")
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = Num.f(cfg()["fog"])
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.add_to_group(GraphicsPresets.GROUP)
	GraphicsPresets.apply_to(PlayerSettings.graphics_row(), world_env)
	parent.add_child(world_env)


## The cold key lamp over the dish (shadows on) and the warm rim behind the set.
static func lights(parent: Node3D) -> void:
	var key := SpotLight3D.new()
	key.light_color = color("key")
	key.light_energy = energy("key")
	key.spot_range = 6.0
	key.spot_angle = 58.0
	key.shadow_enabled = true
	parent.add_child(key)
	key.position = Vector3(0.1, 2.4, 0.4)
	key.look_at(Vector3(0.0, 0.0, -0.2))
	var rim := OmniLight3D.new()
	rim.light_color = color("rim")
	rim.light_energy = energy("rim")
	rim.omni_range = 2.0
	rim.position = Vector3(-0.2, 1.1, -1.25)
	parent.add_child(rim)
