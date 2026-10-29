class_name BreathAim
extends MeshInstance3D
## Atomic Breath's aim (director playtest: "doesnt feel aimed, its hard to know where its going
## to land"), presentation only: while the breath is ready, a faint wedge on the street shows the
## very cone the sim burns when it fires (BreathCone.of(): from the snout along the facing, out
## to the ability's reach), outlined, with a line down its middle. It follows the kaiju's turns,
## so the player aims by facing; it hides while the breath cools down. A solid, steady wash on
## the street, layered behind the kaiju and anything else in front of it, never over him
## (director 2026-10-25: "the aim wedge should also be more opaque, its too loud"; "the wedge
## should be layered behind the kaiju").

const SEGMENTS := 24  # the far arc's pieces
const EDGE := 0.04  # outline and middle line width, as a share of the reach
const FILL_ALPHA := 0.22
const LINE_ALPHA := 0.6
const LIFT := 0.15  # drawn this far over the kaiju's footing (no z-fight with the street)
const PULSE_HZ := 1.2  # the outline breathes gently while ready
const PULSE := 0.05  # how far the alpha breathes either side of 0.95

var _sim: RampageSim
var _tint: Color
var _built := Vector2(-1.0, -1.0)  # (reach, half angle) the mesh was built for
var _material: StandardMaterial3D
var _age := 0.0
var _shown := 0.0  # 0 to 1 over intro "aim_fade_seconds" once it shows (no pop after the intro)


func _init(sim: RampageSim, tint: Color) -> void:
	_sim = sim
	_tint = tint
	name = "BreathAim"
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.disable_fog = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material


## True while the reticle shows: a cone breath, ready to fire, the run going.
func showing() -> bool:
	var ready := _sim.ability_ready_in <= 0.0 and not _sim.over
	return _sim.ability_type == "cone" and ready and not _sim.emerge.active  # none in the intro


## The cone as drawn (as BreathCone.of(): origin, dir, reach, half_angle), for the flow suite.
func drawn() -> Dictionary:
	var forward := Vector2(basis.z.x, basis.z.z).normalized()
	var at := Vector2(position.x, position.z)
	return {"origin": at, "dir": forward, "reach": _built.x, "half_angle": _built.y}


## Runs after Rampage stepped the sim this frame (a child processes after its parent).
func _physics_process(_delta: float) -> void:
	visible = showing()
	if not visible:
		_shown = 0.0
		return
	var aim := BreathCone.of(_sim)
	var reach := Num.f(aim["reach"])
	var half := Num.f(aim["half_angle"])
	if not is_equal_approx(_built.x, reach) or not is_equal_approx(_built.y, half):
		mesh = _wedge(reach, half)
		_built = Vector2(reach, half)
	var origin: Vector2 = aim["origin"]
	var dir: Vector2 = aim["dir"]
	position = Vector3(origin.x, _sim.stand_y + LIFT, origin.y)
	basis = Basis(Vector3.UP, atan2(dir.x, dir.y))  # mesh +Z runs along the facing


func _process(delta: float) -> void:
	_age += delta
	_shown = move_toward(_shown, 1.0, delta / Num.f(Content.section("intro")["aim_fade_seconds"]))
	var alpha := 0.95 + PULSE * sin(_age * TAU * PULSE_HZ)
	_material.albedo_color = Color(1, 1, 1, alpha * _shown)


## A flat wedge (+Z forward, apex at the origin) of this reach and half angle: a faint fill, its
## two edges and far arc outlined, and a line down the middle.
func _wedge(reach: float, half: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fill := Color(_tint, FILL_ALPHA)
	var line := Color(_tint.lightened(0.4), LINE_ALPHA)
	var width := reach * EDGE
	var arc: Array[Vector3] = []
	for k: int in SEGMENTS + 1:
		var a := lerpf(-half, half, k / float(SEGMENTS))
		arc.append(Vector3(sin(a), 0.0, cos(a)) * reach)
	for k: int in SEGMENTS:
		_tri(st, fill, [Vector3.ZERO, arc[k], arc[k + 1]])
		_strip(st, line, [arc[k], arc[k + 1]], width)
	_strip(st, line, [Vector3.ZERO, arc[0]], width)
	_strip(st, line, [Vector3.ZERO, arc[SEGMENTS]], width)
	_strip(st, line, [Vector3.ZERO, Vector3(0, 0, reach)], width * 0.6)
	return st.commit()


static func _tri(st: SurfaceTool, color: Color, corners: Array[Vector3]) -> void:
	for p: Vector3 in corners:
		st.set_color(color)
		st.add_vertex(p)


## A flat band `width` wide along ends[0] -> ends[1].
static func _strip(st: SurfaceTool, color: Color, ends: Array[Vector3], width: float) -> void:
	var a := ends[0]
	var b := ends[1]
	var side := (b - a).cross(Vector3.UP).normalized() * width * 0.5
	_tri(st, color, [a - side, a + side, b + side])
	_tri(st, color, [a - side, b + side, b - side])
