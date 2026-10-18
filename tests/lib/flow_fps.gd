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
