class_name GroundRiver
extends RefCounted
## The river on the city ground (CityGround): its channel and the bridges' stone abutments.


## The river (CityRiver): a channel sunk city "river_depth" below the street, water the same
## colour as the sea's between stone quay walls, running on under its bridges:
## a deck at street level with a parapet along each side for every street that crosses it.
static func river(g: CityGround, channels: Array[Rect2], asphalt: Color, stone: Color) -> void:
	var depth := Num.f(g.cfg.get("river_depth", 0.0))
	var bridges := CityRiver.bridges(g.plan, g.cfg)
	var wall := Vector2(CityGround.PAVE_TOP, depth + 0.5)
	for channel: Rect2 in channels:
		g.add_child(g._sheet(channel, -depth, Look.color("water")))
		var x0 := channel.position.x
		var z0 := channel.position.y
		var banks: Array[Rect2] = [
			Rect2(x0, z0, channel.size.x, CityGround.RIVER_QUAY),
			Rect2(x0, channel.end.y - CityGround.RIVER_QUAY, channel.size.x, CityGround.RIVER_QUAY)
		]
		# No wall where a bridge's inlet opens off the river (or the river into the inlet).
		var open: Array[Rect2] = []
		open.assign(bridges)
		for other: Rect2 in channels:
			if other != channel:
				open.append(other.grow(CityGround.RIVER_QUAY))
		var diagonal := DiagonalPaving.band(g.plan, g.cfg, 0.0)
		for side: Rect2 in GroundKit.cut(banks, open):
			if (
				DiagonalPaving.pieces(side, diagonal).size() == 1
				and CityGround._whole(side, diagonal)
			):
				g._face(side, wall, stone, -depth)
			else:
				g.cut_walls.append(side)
		g._face(Rect2(x0, z0, CityGround.RIVER_QUAY, channel.size.y), wall, stone, -depth)
		g._face(
			Rect2(channel.end.x - CityGround.RIVER_QUAY, z0, CityGround.RIVER_QUAY, channel.size.y),
			wall,
			stone,
			-depth
		)
	var over := CityRiver.diagonal_deck(g.plan, g.cfg)
	if not over.is_empty():
		g._diagonal_deck(over, channels[0], [asphalt, stone])
	for deck: Rect2 in bridges:
		g._bridge(deck, channels, stone)


## The bank walls carried on under a bridge deck, from its underside down to the channel floor, so
## nothing under it shows the clear colour behind (a pale slit at the deck's sides).
static func abutments(
	g: CityGround, deck: Rect2, channels: Array[Rect2], depth: float, stone: Color
) -> void:
	for channel: Rect2 in channels:
		if not channel.intersects(deck):
			continue
		for z: float in [channel.position.y, channel.end.y - CityGround.RIVER_QUAY]:
			g._face(
				Rect2(deck.position.x, z, deck.size.x, CityGround.RIVER_QUAY),
				Vector2(-0.4, depth),
				stone,
				-depth
			)
