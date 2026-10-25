class_name GraphicsPresets
extends RefCounted
## The graphics presets (tuning "display" graphics: potato, low, medium, high, max; research
## 2026-10-21 file 18). Every row holds every key of KEYS and nothing else (errors() says what is
## wrong); apply() puts a row on the window's viewport, the rendering server and every node in
## GROUP (the city's sun and WorldEnvironment, CityEnvironment), reading each key the same way for
## every row. All of it is presentation: nothing here reaches the sim.

## Nodes the presets reach besides the viewport: the city's sun and its WorldEnvironment.
const GROUP := "graphics_preset"
## Each key and the kind of value it takes: "float", "int", "bool" or the name of an enum below.
const KEYS := {
	"scale": "float",  # Viewport.scaling_3d_scale, per axis
	"scaler": "scaler",  # Viewport.scaling_3d_mode
	"msaa": "int",  # Viewport.MSAA: 0 off, 1 = 2x, 2 = 4x
	"screen_aa": "screen_aa",  # Viewport.screen_space_aa
	"shadow_size": "int",  # directional shadow atlas, px
	"shadow_filter": "shadow_filter",  # directional soft shadow quality
	"shadow_distance": "float",  # the sun's shadow max distance, m
	"sun_splits": "sun_splits",  # the sun's shadow mode
	"sun_angular": "float",  # the sun's angular size, degrees (above 0 = soft PCSS shadows)
	"ssao": "bool",
	"ssil": "bool",
	"far_blur": "far_blur",  # the far-only blur's quality (FarDepth); "off" drops it
	# Counts (R 18.3), frozen at each rampage start (start_run) so nothing pops mid-run:
	"debris_pool": "int",  # flying debris pieces (CityView's DebrisField)
	"max_fires": "int",  # fires burning at once (CityView)
	"debris_live": "int",  # carve-physics live bodies (CarvePhysics live_cap)
	"debris_static": "int",  # carve-physics settled pieces (CarvePhysics static_cap)
	"particles": "float",  # every particle system's amount_ratio (Fx, Fire, AbilityFx)
	"crowd_max": "int",  # stadium crowd (CrowdBuild)
	"civilians": "int",  # civilians per building (StreetLife)
}
## The count keys of KEYS (cap()): read once per rampage, never live.
const CAPS: Array[String] = [
	"debris_pool",
	"max_fires",
	"debris_live",
	"debris_static",
	"particles",
	"crowd_max",
	"civilians"
]

const ENUMS := {
	"scaler":
	{
		"bilinear": Viewport.SCALING_3D_MODE_BILINEAR,
		"fsr1": Viewport.SCALING_3D_MODE_FSR,
		"fsr2": Viewport.SCALING_3D_MODE_FSR2,
	},
	"screen_aa":
	{
		"none": Viewport.SCREEN_SPACE_AA_DISABLED,
		"fxaa": Viewport.SCREEN_SPACE_AA_FXAA,
		"smaa": Viewport.SCREEN_SPACE_AA_SMAA,
	},
	"shadow_filter":
	{
		"hard": RenderingServer.SHADOW_QUALITY_HARD,
		"soft_very_low": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"soft_low": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"soft_medium": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"soft_high": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"soft_ultra": RenderingServer.SHADOW_QUALITY_SOFT_ULTRA,
	},
	"far_blur":
	{
		"off": -1,
		"very_low": RenderingServer.DOF_BLUR_QUALITY_VERY_LOW,
		"low": RenderingServer.DOF_BLUR_QUALITY_LOW,
		"medium": RenderingServer.DOF_BLUR_QUALITY_MEDIUM,
		"high": RenderingServer.DOF_BLUR_QUALITY_HIGH,
	},
	"sun_splits":
	{
		"orthogonal": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"pssm2": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"pssm4": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
	},
}

## The counts the running rampage was started with (start_run); empty before the first.
static var _run_caps: Dictionary = {}


## What is wrong with a graphics table: a row missing a key of KEYS, an unknown key, or a value of
## the wrong kind. Empty when every row is whole.
static func errors(table: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if table.is_empty():
		out.append("display.graphics has no rows")
	for name: Variant in table.keys():
		var row: Dictionary = table[name]
		for key: String in KEYS:
			if not row.has(key):
				out.append("graphics %s: missing %s" % [name, key])
			elif not _fits(str(KEYS[key]), row[key]):
				out.append("graphics %s: %s = %s is not a %s" % [name, key, row[key], KEYS[key]])
		for key: Variant in row.keys():
			if not KEYS.has(key):
				out.append("graphics %s: unknown key %s" % [name, key])
	return out


static func _fits(kind: String, value: Variant) -> bool:
	match kind:
		"float", "int":
			return value is float or value is int
		"bool":
			return value is bool
	var names: Dictionary = ENUMS[kind]
	return value is String and names.has(value)


## Puts a row on a viewport (its 3D render), the rendering server's shadow settings and every
## node of GROUP in the viewport's tree.
static func apply(row: Dictionary, view: Viewport) -> void:
	view.scaling_3d_scale = Num.f(row["scale"])
	view.scaling_3d_mode = _enum("scaler", row) as Viewport.Scaling3DMode
	view.msaa_3d = Num.i(row["msaa"]) as Viewport.MSAA
	view.screen_space_aa = _enum("screen_aa", row) as Viewport.ScreenSpaceAA
	RenderingServer.directional_shadow_atlas_set_size(Num.i(row["shadow_size"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		_enum("shadow_filter", row) as RenderingServer.ShadowQuality
	)
	if view.is_inside_tree():
		for node: Node in view.get_tree().get_nodes_in_group(GROUP):
			apply_to(row, node)


## Puts a row's sun and environment keys on one node (a DirectionalLight3D or WorldEnvironment;
## anything else is left alone).
static func apply_to(row: Dictionary, node: Node) -> void:
	if node is DirectionalLight3D:
		var sun := node as DirectionalLight3D
		sun.directional_shadow_max_distance = Num.f(row["shadow_distance"])
		sun.directional_shadow_mode = (_enum("sun_splits", row) as DirectionalLight3D.ShadowMode)
		sun.light_angular_distance = Num.f(row["sun_angular"])
	elif node is WorldEnvironment:
		var env := (node as WorldEnvironment).environment
		if env != null:
			env.ssao_enabled = row["ssao"] == true
			env.ssil_enabled = row["ssil"] == true


## Freezes a row's counts for the rampage starting now (Rampage.setup): every count system reads
## cap() from here until the next start, so a graphics change in pause applies next rampage.
static func start_run(row: Dictionary) -> void:
	_run_caps = {}
	for key: String in CAPS:
		_run_caps[key] = row[key]


## A count of the rampage in play (start_run); before any, the row in use.
static func cap(key: String) -> float:
	if _run_caps.has(key):
		return Num.f(_run_caps[key])
	return Num.f(PlayerSettings.graphics_row()[key])


## The far blur's DOF quality for a row (RenderingServer.DOFBlurQuality), -1 when it is off.
static func far_blur(row: Dictionary) -> int:
	return _enum("far_blur", row)


static func _enum(key: String, row: Dictionary) -> int:
	var names: Dictionary = ENUMS[key]
	return Num.i(names[str(row[key])])
