extends RefCounted
## The flow suite's frame-cap checks (director's playtest: "my graphics card fan makes insane
## noises"). Menus and pause never run above tuning "display" menu_fps; play runs at the player's
## cap (Settings: 60 / 120 / unlimited, kept in settings.cfg). The Settings autoload applies it
## to Engine.max_fps every frame.


static func caps(runner: SceneTree, check: Callable) -> void:
	var menu := Num.i(Content.section("display")["menu_fps"])
	var was_play := PlayerSettings.in_play
	var was_cap := PlayerSettings.fps_cap
	PlayerSettings.fps_cap = 120
	PlayerSettings.in_play = false
	await runner.process_frame
	await runner.process_frame
	var in_menu := Engine.max_fps
	PlayerSettings.in_play = true
	await runner.process_frame
	await runner.process_frame
	var in_play := Engine.max_fps
	runner.paused = true
	await runner.process_frame
	await runner.process_frame
	var paused := Engine.max_fps
	runner.paused = false
	(
		check
		. call(
			in_menu > 0 and in_menu <= menu and paused > 0 and paused <= menu and in_play == 120,
			(
				"menus and pause are capped at %d fps, play at the player's cap: menu %d, pause %d, play %d"
				% [menu, in_menu, paused, in_play]
			)
		)
	)
	var seen: Array[int] = []
	for _i: int in 3:
		PlayerSettings.next_fps_cap()
		seen.append(PlayerSettings.cap())
	PlayerSettings.fps_cap = 0
	PlayerSettings.save()
	PlayerSettings.fps_cap = -1
	PlayerSettings.load_saved(false)
	check.call(
		seen.has(60) and seen.has(0) and seen.has(120) and PlayerSettings.cap() == 0,
		(
			"the frame cap setting cycles 60 / 120 / unlimited and is kept: %s, reloaded %d"
			% [seen, PlayerSettings.cap()]
		)
	)
	PlayerSettings.fps_cap = was_cap
	PlayerSettings.in_play = was_play
	PlayerSettings.save()


## Graphics presets (research 2026-10-21 file 18): Potato, Low, Medium, High, Max, each a row of
## tuning "display" graphics. Every row applies through the Settings autoload and sets what it says
## on the window (scale, upscaler, MSAA, screen AA) and on the city's sun and environment (shadow
## reach, splits, softness, SSAO, SSIL); Medium runs FSR1 with MSAA 2x; settings.cfg keeps the
## level and an old "balanced" loads as Medium. Off a 4K screen (headless) the default is High.
static func graphics(runner: SceneTree, check: Callable) -> void:
	var was: String = PlayerSettings.graphics
	var root := runner.root
	var table: Dictionary = Content.section("display")["graphics"]
	var default_level := PlayerSettings.graphics_level()
	PlayerSettings.graphics = ""
	PlayerSettings.next_graphics()
	var stepped := PlayerSettings.graphics_level()
	var sun := DirectionalLight3D.new()
	var world_env := WorldEnvironment.new()
	world_env.environment = Environment.new()
	for node: Node in [sun, world_env]:
		node.add_to_group(GraphicsPresets.GROUP)
		root.add_child(node)
	var wrong: Array[String] = []
	for level: Variant in table.keys():
		PlayerSettings.graphics = str(level)
		await runner.process_frame
		await runner.process_frame
		var row: Dictionary = table[level]
		var got := {
			"scale": snappedf(root.scaling_3d_scale, 0.001),
			"scaler": root.scaling_3d_mode,
			"msaa": root.msaa_3d,
			"screen_aa": root.screen_space_aa,
			"shadow_distance": snappedf(sun.directional_shadow_max_distance, 0.001),
			"sun_splits": sun.directional_shadow_mode,
			"sun_angular": snappedf(sun.light_angular_distance, 0.001),
			"ssao": world_env.environment.ssao_enabled,
			"ssil": world_env.environment.ssil_enabled,
		}
		for key: String in got:
			var want: Variant = row[key]
			var kind := str(GraphicsPresets.KEYS[key])
			if GraphicsPresets.ENUMS.has(kind):
				var names: Dictionary = GraphicsPresets.ENUMS[kind]
				want = names[want]
			elif kind == "int":
				want = Num.i(want)
			elif kind == "float":
				want = snappedf(Num.f(want), 0.001)
			if str(got[key]) != str(want):
				wrong.append("%s %s: %s, want %s" % [level, key, got[key], want])
	sun.queue_free()
	world_env.queue_free()
	check.call(
		table.size() == 5 and wrong.is_empty(),
		"each of the %d graphics presets sets what its row says: %s" % [table.size(), wrong]
	)
	var medium: Dictionary = table["medium"]
	check.call(
		medium["scaler"] == "fsr1" and Num.i(medium["msaa"]) == Viewport.MSAA_2X,
		"Medium runs FSR1 with MSAA 2x (FSR1 wants another AA): %s" % [medium]
	)
	var old := ConfigFile.new()
	old.set_value("display", "graphics", "balanced")
	old.save(PlayerSettings.PATH)
	PlayerSettings.graphics = ""
	PlayerSettings.load_saved(false)
	var renamed := PlayerSettings.graphics_level()
	PlayerSettings.graphics = "low"
	PlayerSettings.save()
	PlayerSettings.graphics = ""
	PlayerSettings.load_saved(false)
	var kept := PlayerSettings.graphics_level()
	check.call(
		default_level == "high" and stepped == "max" and renamed == "medium" and kept == "low",
		(
			"graphics default %s, next %s, an old balanced loads as %s, low is kept: %s"
			% [default_level, stepped, renamed, kept]
		)
	)
	PlayerSettings.graphics = was
	PlayerSettings.save()


## Every graphics row holds every preset key: the shipped table is whole, and a row missing one
## (or with a bad value) is named by GraphicsPresets.errors (Settings reports them at start).
static func graphics_rows(check: Callable) -> void:
	var table: Dictionary = Content.section("display")["graphics"]
	var shipped := GraphicsPresets.errors(table)
	var broken := table.duplicate(true)
	var medium: Dictionary = broken["medium"]
	var low: Dictionary = broken["low"]
	medium.erase("msaa")
	low["scaler"] = "fsr9"
	var found := GraphicsPresets.errors(broken)
	check.call(
		(
			shipped.is_empty()
			and found.has("graphics medium: missing msaa")
			and found.has("graphics low: scaler = fsr9 is not a scaler")
			and found.size() == 2
		),
		"the graphics table is whole %s and a broken row is caught: %s" % [shipped, found]
	)


## A settings.cfg from before the 4K default (demo exe 1 saved the resolved cap, 120, as if the
## player had chosen it) must not override the default: an unversioned display section's
## fps_cap is ignored.
static func stale_cap(check: Callable) -> void:
	var was := PlayerSettings.fps_cap
	var old := ConfigFile.new()
	old.set_value("display", "fps_cap", 120)
	old.save(PlayerSettings.PATH)
	PlayerSettings.fps_cap = 60
	PlayerSettings.load_saved(false)
	check.call(
		PlayerSettings.fps_cap == -1,
		(
			"an old settings.cfg's frame cap (120) gives way to the default: %d"
			% PlayerSettings.fps_cap
		)
	)
	PlayerSettings.fps_cap = was
	PlayerSettings.save()
