class_name CrowdBuild
extends RefCounted
## What StadiumCrowd is made of, read off the baked stadium once: where the seats are, what the
## fans wear, and the buffer of their seat transforms. Pure functions of the model and
## data/tuning.json "crowd"; split out of StadiumCrowd to keep files small.

## A kit shirt this unsaturated (and bright) reads as an empty seat from above.
const PALE := 0.25
## Floats per instance: the 3x4 transform, then the custom data (fall start, flee time, landing
## height, linger; crowd.gdshader).
const STRIDE := 16


## Seats: the model's seat-coloured voxels open to the sky, one per `spacing` square of plan,
## shuffled and capped at "max".
static func seats(
	vox: VoxelBuilder, cfg: Dictionary, rng: RandomNumberGenerator
) -> Array[Vector3i]:
	var keys: Array = cfg["seats"]
	var near := Num.f(cfg["seat_match"]) / 255.0
	var spacing := float(Num.i(cfg["spacing"]))
	var pick: Dictionary = {}
	for cell: Vector3i in vox.colors:
		if vox.colors.has(cell + Vector3i.UP):
			continue
		var c: Color = vox.colors[cell]
		var seat := false
		for key: String in keys:
			var s := Color(key)
			seat = seat or maxf(absf(c.r - s.r), maxf(absf(c.g - s.g), absf(c.b - s.b))) <= near
		var key := Vector2i(floori(cell.x / spacing), floori(cell.z / spacing))
		if seat and not pick.has(key):
			pick[key] = cell
	var out: Array[Vector3i] = []
	for cell: Vector3i in pick.values():
		out.append(cell)
	for i: int in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := out[i]
		out[i] = out[j]
		out[j] = swap
	return out.slice(0, mini(out.size(), int(GraphicsPresets.cap("crowd_max"))))


## Every (shirt, skin) outfit: the kits' colours then the neutral shirts, on street trousers
## and hair. A pale kit shirt (cricket whites) reads as an empty grey seat from above, so its
## fans wear the kit's trim (its "hair" colour: caps and helmets) instead.
static func outfits(kits: Array, neutral: Array) -> Array[Dictionary]:
	var shirts: Array[String] = []
	for kit: Dictionary in kits:
		var shirt := Color(str(kit["shirt"]))
		shirts.append(str(kit["hair"]) if shirt.s < PALE and shirt.v > 0.7 else str(kit["shirt"]))
	for n: Dictionary in neutral:
		shirts.append(str(n["shirt"]))
	var out: Array[Dictionary] = []
	for i: int in shirts.size():
		var street: Dictionary = neutral[i % neutral.size()]
		for skin: String in StadiumMatch.SKINS:
			out.append(
				{"shirt": shirts[i], "pants": street["pants"], "hair": street["hair"], "skin": skin}
			)
	return out


## A full buffer of `count` instances, the fans' first, each facing `centre`, feet at its seat,
## no fall begun (custom data zero).
static func transforms(group: Array, count: int, centre: Vector2) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(count * STRIDE)
	var i := 0
	for fan: StadiumCrowd.Fan in group:
		var facing := (centre - Vector2(fan.pos.x, fan.pos.z)).normalized()
		var c := -facing.y  # the yaw that turns -Z onto the facing
		var s := -facing.x
		buf[i] = c
		buf[i + 2] = s
		buf[i + 3] = fan.pos.x
		buf[i + 5] = 1.0
		buf[i + 7] = fan.pos.y
		buf[i + 8] = -s
		buf[i + 10] = c
		buf[i + 11] = fan.pos.z
		i += STRIDE
	return buf


## The fans of stadium `b`: one on each seat its model gives, in a kit's colours or a neutral
## shirt, with a skin each. Draws the run's presentation stream (the seats' shuffle first).
static func sit(
	b: RampageSim.Building, kits: Array, cfg: Dictionary, rng: RandomNumberGenerator
) -> Array[StadiumCrowd.Fan]:
	var v := BuildingVoxels.VOXEL
	var corner := Vector2(b.x, b.z) - Vector2(b.w, b.d) * 0.5
	var origin := Vector3(corner.x + v * 0.5, 0.0, corner.y + v * 0.5)
	var neutral: Array = cfg["neutral"]
	var share := Num.f(cfg["team_share"])
	var skins := StadiumMatch.SKINS.size()
	var out: Array[StadiumCrowd.Fan] = []
	for cell: Vector3i in seats(LandmarkVoxels.voxels(b.landmark), cfg, rng):
		var fan := StadiumCrowd.Fan.new()
		fan.pos = origin + Vector3(cell.x, cell.y + 1, cell.z) * v
		var shirt := (
			rng.randi_range(0, kits.size() - 1)
			if rng.randf() < share
			else rng.randi_range(kits.size(), kits.size() + neutral.size() - 1)
		)
		fan.outfit = shirt * skins + rng.randi_range(0, skins - 1)
		out.append(fan)
	return out


## Stands every seated fan up, each with its own moment to start running (a share of
## flee_delay by its slot) and the time it is through an exit; returns them.
static func rise(
	fans: Array[StadiumCrowd.Fan], cfg: Dictionary, centre: Vector2, half: Vector2
) -> Array[StadiumCrowd.Fan]:
	var speed := Num.f(cfg["flee_speed"])
	var delay := Num.f(cfg["flee_delay"])
	var exit_r := Num.f(cfg["exit_r"])
	var sink := Num.f(cfg["sink"])
	var risen: Array[StadiumCrowd.Fan] = []
	for fan: StadiumCrowd.Fan in fans:
		if fan.state != StadiumCrowd.State.SEATED:
			continue
		fan.state = StadiumCrowd.State.UP
		fan.leaves = fmod(fan.slot * StadiumCrowd.GOLDEN, 1.0) * delay
		fan.run = run_out(Vector2(fan.pos.x, fan.pos.z) - centre, half, exit_r)
		fan.out_at = fan.leaves + (fan.run + sink) / speed
		risen.append(fan)
	return risen


## How far a fan at `at` (from the stadium's middle) runs, straight out, to normalised radius
## exit_r (as the shader does): the root of |q + d m| = exit_r, q its seat and d its direction over
## the half size `half`.
static func run_out(at: Vector2, half: Vector2, exit_r: float) -> float:
	var q := at / half
	var d := at.normalized() / half
	var a := d.dot(d)
	var b := q.dot(d)
	var c := q.dot(q) - exit_r * exit_r
	return maxf(0.0, (-b + sqrt(maxf(0.0, b * b - a * c))) / a)


## The chunk of the stadium (corner `corner` in plan) that world point `at` lies in.
static func chunk(at: Vector3, corner: Vector2) -> Vector3i:
	var v := BuildingVoxels.VOXEL
	return Vector3i(floori(at.x - corner.x), floori(at.y - v * 0.5), floori(at.z - corner.y))


## The fans seated in each chunk of `frame`, by chunk index, until it goes.
static func hosts(fans: Array[StadiumCrowd.Fan], frame: Structure, corner: Vector2) -> Dictionary:
	var out: Dictionary = {}
	for fan: StadiumCrowd.Fan in fans:
		var c := chunk(fan.pos, corner)
		if frame.inside(c):
			var at := frame.index(c)
			var seated: Array = out.get(at, [])
			seated.append(fan)
			out[at] = seated
	return out


## The grid index of the fine cell (Carving's VoxelFrame `f` of the stadium, corner `corner`)
## that world point `at` stands on: the highest solid cell from just under it down `reach`
## metres, or -1 when there is none (nothing under the feet, or outside the grid).
static func under(f: VoxelFrame, at: Vector3, corner: Vector2, reach: float) -> int:
	var c := Vector3i(
		floori((at.x - corner.x) * f.res),
		floori(at.y * f.res - 0.5),
		floori((at.z - corner.y) * f.res)
	)
	c -= f.offset
	if c.x < 0 or c.z < 0 or c.x >= f.w or c.z >= f.d:
		return -1
	var plan := f.w * f.d
	var col := c.x + c.z * f.w
	for y: int in range(mini(c.y, f.h - 1), maxi(-1, c.y - ceili(reach * f.res) - 1), -1):
		if f.cells[col + y * plan] != VoxelFrame.EMPTY:
			return col + y * plan
	return -1


## The y of the highest standing chunk below chunk `c` (0: the ground) in `frame`, whose chunk
## health is `hp`: where a fan whose stand has gone lands.
static func land(frame: Structure, hp: PackedFloat32Array, c: Vector3i) -> int:
	if not frame.inside(c):
		return 0
	var plan := frame.w * frame.d
	var col := c.x + c.z * frame.w
	for y: int in range(mini(c.y, frame.h) - 1, -1, -1):
		if hp[col + y * plan] > 0.0:
			return y + 1
	return 0


## The shader material every outfit's MultiMesh draws with (crowd.gdshader), from tuning "crowd".
static func material(
	cfg: Dictionary, city: Dictionary, centre: Vector2, half: Vector2
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = StadiumCrowd.SHADER
	mat.set_shader_parameter("bob", Num.f(cfg["bob"]))
	var hz: Array = cfg["bob_hz"]
	mat.set_shader_parameter("bob_hz", Vector2(Num.f(hz[0]), Num.f(hz[1])))
	mat.set_shader_parameter("centre", centre)
	mat.set_shader_parameter("half_size", half)
	mat.set_shader_parameter("exit_r", Num.f(cfg["exit_r"]))
	mat.set_shader_parameter("speed", Num.f(cfg["flee_speed"]))
	mat.set_shader_parameter("slope", Num.f(cfg["flee_slope"]))
	mat.set_shader_parameter("delay", Num.f(cfg["flee_delay"]))
	mat.set_shader_parameter("sink", Num.f(cfg["sink"]))
	mat.set_shader_parameter("fall_g", Num.f(city["fall_gravity"]))
	mat.set_shader_parameter("shrink", Num.f(cfg["shrink"]))
	mat.set_shader_parameter("topple", StadiumCrowd.TOPPLE)
	return mat


## One outfit's static MultiMesh holder: its fans' seats written once (see transforms), drawn
## with `mat`, casting no shadow.
static func holder(
	outfit: Dictionary, group: Array, mat: ShaderMaterial, centre: Vector2
) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = VoxelPerson.seated(outfit, Num.f(Content.section("street")["person_voxel"]))
	mm.instance_count = maxi(1, group.size())
	mm.buffer = transforms(group, mm.instance_count, centre)
	mm.visible_instance_count = group.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a third of their cost
	return mmi
