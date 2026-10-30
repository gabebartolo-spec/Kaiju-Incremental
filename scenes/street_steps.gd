class_name StreetSteps
extends RefCounted
## How the street's people walk each frame (StreetLife): the step clock, a cop's beat, the startle
## and the panic radius around the kaiju.


## Everyone's step this frame, last first (a removal moves the last in); officers go to Police.
static func walk(s: StreetLife, delta: float, kaiju: Vector2) -> void:
	var panic := panic_radius(s)
	var calm := panic * Num.f(s._cfg["calm_radius"]) / Num.f(s._cfg["panic_radius"])
	var gawk := Num.f(s._cfg["panic_gawk"])
	var run := Num.f(s._cfg["run_speed"])
	var walk := Num.f(s._cfg["walk_speed"])
	if s._walker != null:  # render plan item 7: every civilian's step in one native call
		s._walker.frame(delta, kaiju, PackedFloat64Array([s._clock, panic, calm, gawk, run, walk]))
		return
	# Without the extension, far people step every few frames (StreetLod, D-254).
	var speeds := PackedFloat64Array([walk, run])
	for i: int in range(s.pos.size() - 1, -1, -1):
		if s.cop[i] == 1:
			walk_cop(s, i, delta, kaiju)
			continue
		if s.pinned_until[i] > s._clock:
			continue
		var at := s.pos[i]
		var dt := step_time(s, i, at, kaiju, delta)
		if dt < 0.0:  # a far person's frame off
			continue
		var d := at.distance_to(kaiju)
		if s.fleeing[i] == 0 and d < panic:
			startle(s, i, at, kaiju, gawk)
		elif s.fleeing[i] == 1 and d > calm:
			s.fleeing[i] = 0
		var to := s._nodes[s.to_node[i]] - at
		var step := speeds[s.fleeing[i]] * s.pace[i] * dt  # fleeing 1: running
		if to.length() > step:
			var dir := to.normalized()
			s.heading[i] = dir
			s.pos[i] = at + dir * step
			continue
		s.pos[i] = s._nodes[s.to_node[i]]
		var next := s._pavements.next_corner(s.to_node[i], s.from_node[i], kaiju, s.fleeing[i] == 1)
		s.from_node[i] = s.to_node[i]
		s.to_node[i] = next


## Person i's step time this frame (StreetLod, D-254): far from the kaiju and the camera, one step
## every far_every frames covering them all, -1 on the frames between.
static func step_time(s: StreetLife, i: int, at: Vector2, kaiju: Vector2, delta: float) -> float:
	var far2 := s._lod.far2
	if at.distance_squared_to(kaiju) <= far2 or at.distance_squared_to(s._lod.cam) <= far2:
		return delta
	if (i + s._lod.tick) % s._lod.far_every != 0:
		return -1.0
	return delta * s._lod.far_every


## Officer i takes its police step (Police.update_cop), or leaves when its job is done.
static func walk_cop(s: StreetLife, i: int, delta: float, kaiju: Vector2) -> void:
	var officer := s.officers[i]
	if s.police.update_cop(officer, delta, kaiju):
		s.remove(i)
	else:
		s.pos[i] = officer.pos
		s.heading[i] = officer.heading


## Person i sees the kaiju: a moment (gawk) facing it, then runs; one walking toward it turns.
static func startle(s: StreetLife, i: int, at: Vector2, kaiju: Vector2, gawk: float) -> void:
	s.fleeing[i] = 1
	s.fled += 1
	s.pinned_until[i] = s._clock + gawk
	s.heading[i] = (kaiju - at).normalized()
	if (s._nodes[s.to_node[i]] - at).dot(kaiju - at) > 0.0:
		var swap := s.from_node[i]
		s.from_node[i] = s.to_node[i]
		s.to_node[i] = swap


## How near the kaiju comes before people run: panic_per_scale x body scale, at most panic_radius.
static func panic_radius(s: StreetLife) -> float:
	var r := Num.f(s._cfg["panic_per_scale"]) * s.sim.body_scale()
	return minf(Num.f(s._cfg["panic_radius"]), r)
