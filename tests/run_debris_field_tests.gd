extends "res://tests/lib/runner.gd"
## Debris field (frame rate, MultiMesh for debris): the flying fragments of breaking floors and
## falling trees draw through one MultiMesh per piece size, the colour on each instance, not one
## node and draw call per piece. A collapse's worth of pieces: every live body is drawn once, in
## its own lightened colour, through far fewer meshes than pieces; a field without shadows casts
## none; each piece shrinks away and is gone after its 5-8 s, as before.
##   godot --headless --path . --script tests/run_debris_field_tests.gd
## Seeded: Seeds "fx" 0; time is stepped by hand (the field's own _process is off).

const DT := 1.0 / 30.0
const PIECES := 300
const COLORS: Array[Color] = [Color(0.6, 0.3, 0.2), Color(0.2, 0.4, 0.6), Color(0.5, 0.5, 0.45)]


func suite_name() -> String:
	return "Debris field"


func run_checks() -> void:
	await _t("_check_pieces_draw_through_few_meshes")


func _check_pieces_draw_through_few_meshes() -> void:
	var field := DebrisField.new(Seeds.make("fx", 0), PIECES)
	field.lift = 0.1
	field.shadows = false
	root.add_child(field)
	field.set_process(false)
	for k: int in PIECES:
		field.spawn(Vector3(k % 10, 20.0, k / 10), COLORS[k % COLORS.size()], Vector3.RIGHT)
	while field.pending() > 0:
		field._process(DT)
	await process_frame
	var drawn: Array[Color] = _drawn(field)
	var mmis := field.find_children("*", "MultiMeshInstance3D", false, false)
	check(_live(field) == PIECES, "every piece was thrown (%d)" % _live(field))
	check(drawn.size() == _live(field), "every live piece is drawn once (%d)" % drawn.size())
	check(mmis.size() * 10 < PIECES, "%d pieces draw through %d meshes" % [PIECES, mmis.size()])
	check(field.find_children("*", "MeshInstance3D", true, false).is_empty(), "no node per piece")
	var lit: Array = COLORS.map(func(c: Color) -> Color: return c.lightened(0.1))
	check(drawn.all(func(c: Color) -> bool: return _near(lit, c)), "pieces keep colours")
	var shadowless := 0
	for m: MultiMeshInstance3D in mmis:
		shadowless += 1 if m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0
	check(shadowless == mmis.size(), "a field without shadows casts none")
	for _f: int in roundi(4.9 / DT):
		field._process(DT)
	check(_live(field) == PIECES, "no piece goes before 5 s")
	for _f: int in roundi(4.0 / DT):
		field._process(DT)
	check(_live(field) == 0, "every piece shrank away by 8.8 s")
	check(_drawn(field).size() == 0, "nothing is left drawn")
	field.queue_free()


## The live pieces' bodies.
func _live(field: DebrisField) -> int:
	var bodies: Array = field.get("_bodies")
	return bodies.size()


## The colour of every instance the field's MultiMeshes draw .
func _drawn(field: DebrisField) -> Array[Color]:
	var colors: Array[Color] = []
	var bufs: Array[PackedFloat32Array] = field.get("_bufs")
	var meshes: Array[MultiMesh] = field.get("_meshes")
	for view: int in meshes.size():
		var buf := bufs[view]
		for o: int in range(
			0, meshes[view].visible_instance_count * CarveRubble.FLOATS, CarveRubble.FLOATS
		):
			colors.append(Color(buf[o + 12], buf[o + 13], buf[o + 14], buf[o + 15]))
	return colors


## True when `c` is one of `colors` (to the buffer's precision).
func _near(colors: Array, c: Color) -> bool:
	return colors.any(func(o: Color) -> bool: return o.is_equal_approx(c))
