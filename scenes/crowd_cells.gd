class_name CrowdCells
extends RefCounted
## The stadium crowd on the stands' fine cells (StadiumCrowd): seats lost with the cells under
## them, fans seated on cells and falling to the cells below.


## The stadium carves: on its first look each seated fan is put on the fine cell under its
## seat; after that, whenever the grid loses cells, every seated fan in a chunk that lost some
## whose cell has gone falls (the frame it went, as with chunks).
static func lose_cells(c: StadiumCrowd) -> void:
	if c._cells == null:
		if not c._sim.carving.promoted(c._index):
			return
		c._cells = c._sim.carving.grids[c._index]
		seat_on_cells(c)
	var f := c._cells.frame
	if f.alive_count == c._fine_alive:
		return
	c._fine_alive = f.alive_count
	c._puffs = 0
	for ch: int in c._on_cells.keys():
		if c._cells.live[ch] == c._live[ch]:
			continue
		c._live[ch] = c._cells.live[ch]
		var left: Array = []
		for fan: StadiumCrowd.Fan in c._on_cells[ch]:
			if (
				fan.state != StadiumCrowd.State.SEATED
				and not (fan.state == StadiumCrowd.State.UP and c._since <= fan.leaves)
			):
				continue
			if f.cells[fan.under] == VoxelFrame.EMPTY:
				fall_to_cells(c, fan, fan.pos)
			else:
				left.append(fan)
		if left.is_empty():
			c._on_cells.erase(ch)
		else:
			c._on_cells[ch] = left


static func seat_on_cells(c: StadiumCrowd) -> void:
	var f := c._cells.frame
	c._live = c._cells.live.duplicate()
	for fan: StadiumCrowd.Fan in c.fans:
		if fan.is_dead():
			continue
		fan.under = CrowdBuild.under(f, fan.pos, c._corner, StadiumCrowd.FOOT)
		if fan.under < 0:
			continue
		var ch := c._cells.chunk(fan.under)
		var seated: Array = c._on_cells.get(ch, [])
		seated.append(fan)
		c._on_cells[ch] = seated


## A fan whose cell has gone from under it at `at` falls to the cells still below, or the ground.
static func fall_to_cells(c: StadiumCrowd, fan: StadiumCrowd.Fan, at: Vector3) -> void:
	var f := c._cells.frame
	var below := CrowdBuild.under(f, at, c._corner, at.y + 1.0)
	var land := float(below / (f.w * f.d) + 1 + f.offset.y) / f.res if below >= 0 else 0.0
	c._die(fan, at, minf(land, at.y))
	c.fallen += 1
