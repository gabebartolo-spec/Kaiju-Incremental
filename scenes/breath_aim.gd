class_name BreathAim
extends MeshInstance3D
## Atomic Breath's aim (director playtest: "doesnt feel aimed, its hard to know where its going
## to land"), presentation only: while the breath is ready, a faint wedge on the street shows the
## very cone the sim burns when it fires (RampageSim.cone(): from the feet along the facing, out
## to the ability's reach), outlined, with a line down its middle. It follows the kaiju's turns,
## so the player aims by facing; it hides while the breath cools down. Drawn over the city, so a
## building between the kaiju and the camera never hides where the breath will land.

const SEGMENTS := 24  # the far arc's pieces
const EDGE := 0.04  # outline and middle line width, as a share of the reach
const FILL_ALPHA := 0.12
const LINE_ALPHA := 0.55
const LIFT := 0.15  # drawn this far over the kaiju's footing (no z-fight with the street)
const PULSE_HZ := 1.2  # the outline breathes gently while ready

var _sim: RampageSim
var _tint: Color
var _built := Vector2(-1.0, -1.0)  # (reach, half angle) the mesh was built for
var _material: StandardMaterial3D
var _age := 0.0


func _init(sim: RampageSim, tint: Color) -> void:
	_sim = sim
	_tint = tint
	name = "BreathAim"
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.disable_fog = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.render_priority = 1
	material_override = _material


## True while the reticle shows: a cone breath, ready to fire, the run going.
func showing() -> bool:
	return _sim.ability_type == "cone" and _sim.ability_ready_in <= 0.0 and not _sim.over


## The cone as drawn (as RampageSim.cone(): origin, dir, reach, half_angle), for the flow suite.
func drawn() -> Dictionary:
	var forward := Vector2(basis.z.x, basis.z.z).normalized()
	var at := Vector2(position.x, position.z)
	return {"origin": at, "dir": forward, "reach": _built.x, "half_angle": _built.y}


## Runs after Rampage stepped the sim this frame (a child processes after its parent).
func _physics_process(_delta: float) -> void:
	visible = showing()
	if not visible:
		return
	var aim := _sim.cone()
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
	_material.albedo_color = Color(1, 1, 1, 0.75 + 0.25 * sin(_age * TAU * PULSE_HZ))


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
