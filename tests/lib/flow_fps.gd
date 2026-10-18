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


## Graphics quality (lead, 4K GPU follow-up): Balanced renders the 3D at a lower scale with FSR
## and no MSAA, High at full scale with MSAA; the Settings autoload applies it to the window and
## settings.cfg keeps it. Off a 4K screen (headless) the default is High.
static func graphics(runner: SceneTree, check: Callable) -> void:
	var was: String = PlayerSettings.graphics
	var root := runner.root
	var default_level := PlayerSettings.graphics_level()
	PlayerSettings.graphics = ""
	PlayerSettings.next_graphics()
	var stepped := PlayerSettings.graphics_level()
	PlayerSettings.graphics = "balanced"
	await runner.process_frame
	await runner.process_frame
	var balanced := [root.scaling_3d_scale, root.scaling_3d_mode, root.msaa_3d]
	PlayerSettings.graphics = "high"
	await runner.process_frame
	await runner.process_frame
	var high := [root.scaling_3d_scale, root.scaling_3d_mode, root.msaa_3d]
	PlayerSettings.graphics = "balanced"
	PlayerSettings.save()
	PlayerSettings.graphics = ""
	PlayerSettings.load_saved(false)
	var kept := PlayerSettings.graphics_level()
	check.call(
		(
			default_level == "high"
			and stepped == "balanced"
			and is_equal_approx(Num.f(balanced[0]), 0.75)
			and balanced[1] == Viewport.SCALING_3D_MODE_FSR
			and balanced[2] == Viewport.MSAA_DISABLED
			and is_equal_approx(Num.f(high[0]), 1.0)
			and high[2] == Viewport.MSAA_4X
			and kept == "balanced"
		),
		(
			"graphics applies and is kept: default %s, next %s, balanced %s, high %s, kept %s"
			% [default_level, stepped, balanced, high, kept]
		)
	)
	PlayerSettings.graphics = was
	PlayerSettings.save()


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
