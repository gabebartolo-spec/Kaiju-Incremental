extends RefCounted
## The military suite's game-view probe of a cornered tank (split out of military_view.gd to keep
## files small).


## Has the tank at p no road out: every way along every army road it stands on (RoadGraph: the
## plan clipped to the box the army operates in) ends nearer the kaiju's body line than it stands
## now? (A stub out to the box's edge with the kaiju at its mouth.)
static func cornered(sim: RampageSim, p: Vector2) -> bool:
	var graph := sim.army_units.convoy.graph
	var snout: Vector2 = BreathCone.of(sim)["origin"]
	var here := Geometry2D.get_closest_point_to_segment(p, sim.kaiju_pos, snout).distance_to(p)
	for e: int in graph.roads_at(graph.cell_of(p)):
		if not graph.on_edge(p, e):
			continue
		for end: Vector2 in [graph.nodes[graph.edge_a[e]], graph.nodes[graph.edge_b[e]]]:
			var q := Geometry2D.get_closest_point_to_segment(end, sim.kaiju_pos, snout)
			if end.distance_to(p) > 0.5 and end.distance_to(q) > here:
				return false
	return true
