class_name QuitGame
extends RefCounted
## Leaving the game (b2-29: quitting froze the last frame on screen for 2-3 seconds while the
## engine freed the city). The window goes first, so the player sees the game close at once and
## the teardown runs unseen behind it.

## Audio mixes to wait for after the sounds stop (one may already be under way, so two are sure).
const SETTLE_MIXES := 3
## The longest the wait may take (real milliseconds); a dead audio thread never holds a run.
const SETTLE_MAX_MSEC := 1000
const SETTLE_POLL_MSEC := 2


## Hides the window, then quits. The title's and the end card's QUIT buttons and the window's
## own close request (Alt+F4, the X) all come here.
static func now(tree: SceneTree) -> void:
	tree.root.hide()
	tree.quit()


## For a scripted exit whose engine log is read (the smoke runs): stops every sound and lets the audio
## thread let go of it before the script quits. The engine frees a stopped playback in the audio thread's
## next mix and the main loop's next update; a sound still alive when it quits is never freed, and the
## exit prints "4 ObjectDB instances were leaked" and "2 resources still in use" naming the stream, its
## packet sequence and their playbacks, on some runs and not others (CI run 40443431942); the
## dummy audio driver mixes about every 90 ms (three mixes took 270 ms on the runner), so a quit soon
## after a sound stops can beat the mix that would free it.
## The game's own quit (now) skips this: the process ends and nothing reads the log.
static func settle_audio(tree: SceneTree) -> void:
	await tree.process_frame  # a sound whose player is added or started by a deferred call starts first
	await tree.process_frame
	for kind: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for found: Node in tree.root.find_children("*", kind, true, false):
			found.call("stop")
	var started := Time.get_ticks_msec()
	var mixes := 0
	var last := AudioServer.get_time_since_last_mix()
	while mixes < SETTLE_MIXES and Time.get_ticks_msec() - started < SETTLE_MAX_MSEC:
		OS.delay_msec(SETTLE_POLL_MSEC)
		var now := AudioServer.get_time_since_last_mix()
		if now < last:  # the clock restarts at each mix
			mixes += 1
		last = now
	await tree.process_frame  # the main loop's update frees what the mixes released
	await tree.process_frame
