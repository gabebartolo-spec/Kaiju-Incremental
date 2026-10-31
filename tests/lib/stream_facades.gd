extends RefCounted
## D-415 (director 2026-10-31: stand-in boxes show the real facade, the swap invisible): a
## streamed building's stand-in box shows exactly the lit windows its voxels show. On: every
## lit window cell a sampled building's layout shows from outside (no proud voxel in front) is
## a lit texel of its baked strip, and no other texel is; a second bake of the same city reads
## the disk cache back byte for byte. Off (render_opt.facade_bake false): the boxes keep the
## invented pattern (custom x >= 0), so none shows its real windows.

const SAMPLES := 24
const LIT: Array[String] = ["lit", "shop_lit"]


static func check(sim: RampageSim, check_fn: Callable) -> void:
	var colors: Array[Color] = []
	for b: RampageSim.Building in sim.buildings:
		colors.append(Color.GRAY)
	var party := BuildingView.party_walls(sim.buildings)
	var bake := FacadeBake.new(sim.buildings, colors, party)
	bake.start()
	bake.finish()
	check_fn.call(bake.atlas != null, "facade bake: an atlas")
	if bake.atlas == null:
		return
	var sampled := 0
	var shown := 0
	var lit_cells := 0
	var stray := 0
	var res := BuildingVoxels.RES
	var lit_share := Look.value("window_lit")
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if not FacadeBake.plain(b) or sampled >= SAMPLES:
			continue
		sampled += 1
		var cells := BuildingLayout.new(b, res, party[n], lit_share).cells
		var corner := bake.corner(n)
		var w := b.w * res
		var d := b.d * res
		var at := 0
		for side: Vector2i in BuildingLayout.SIDES:
			var length := d if side.x != 0 else w
			for p: int in length:
				for y: int in b.height * res:
					var front := ""
					for layer: int in FacadeBake.LAYERS:
						var key: Variant = cells.get(FacadeBake._cell(side, p, y, layer, w, d))
						if key != null:
							front = key
							break
					var texel := bake.atlas.get_pixel(corner.x + at + p, corner.y + y)
					var tagged := absf(texel.a - WindowPalette.TAG) < 0.5 / 255.0
					if front in LIT:
						lit_cells += 1
						shown += 1 if tagged else 0
					elif tagged:
						stray += 1
			at += length
	check_fn.call(
		lit_cells > 0 and shown == lit_cells and stray == 0,
		(
			"facade bake on: %d buildings, %d of %d lit window cells lit on the box, %d stray"
			% [sampled, shown, lit_cells, stray]
		)
	)
	var again := FacadeBake.new(sim.buildings, colors, party)
	again.start()
	again.finish()
	check_fn.call(
		(
			again.atlas != null
			and again.atlas.get_data() == bake.atlas.get_data()
			and again.origin == bake.origin
		),
		"facade bake: the second load reads the cache back unchanged"
	)
	var boxes := StreamStandIns.new(sim.buildings)
	var node := boxes.build(colors)
	var invented := 0
	for n: int in sim.buildings.size():
		if node.multimesh.get_instance_custom_data(n).r >= 0.0:
			invented += 1
	check_fn.call(
		invented == sim.buildings.size(),
		(
			"facade bake off: %d of %d boxes keep the invented pattern"
			% [invented, sim.buildings.size()]
		)
	)
	node.free()
