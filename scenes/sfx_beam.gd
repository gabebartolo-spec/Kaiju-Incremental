class_name SfxBeam
extends Node
## The Thunder Beam's sound (lead, 2026-10-23): a thunder crack on the beam's start (thunder_beam),
## a seamless loop under it for as long as it burns (thunder_beam_loop, faded in under the crack,
## stopped with a short fade), and a crack and rumble when it ends (thunder_beam_end). The two
## one-shots go through Sfx.play (hero voices, volumes and buses from tuning "sfx" / "audio");
## the loop is this node's own player, like the helicopters' rotor. Presentation only.

const LOOP := "thunder_beam_loop"
## How long the loop takes to fade in under the crack, and to fade out when the beam ends (s).
const FADE_IN := 0.6
const FADE_OUT := 0.15
const SILENT_DB := -60.0

var _sfx: Sfx
var _loop := AudioStreamPlayer.new()
var _tween: Tween


func _init(sfx: Sfx) -> void:
	_sfx = sfx
	var stream: AudioStreamOggVorbis = load("res://assets/sfx/%s.ogg" % LOOP)
	stream.loop = true
	_loop.stream = stream
	_loop.bus = AudioBuses.of(LOOP)
	add_child(_loop)


## The beam begins: the crack, and the loop coming in under it.
func start() -> void:
	_sfx.play("thunder_beam")
	if not _sfx.live:
		return
	var levels: Dictionary = Content.section("sfx")["volume_db"]
	_sfx.played.append(LOOP)
	_fade(Num.f(levels[LOOP]), FADE_IN)
	if not _loop.playing:  # already crackling under the charge-up: carries straight on
		_loop.play()


## The beam ends: the loop out, the closing crack and rumble.
func stop() -> void:
	_sfx.play("thunder_beam_end")
	charge_end()


## A lightning power is pressed (D-357): the same crackle loop swells under the charge-up over the
## `seconds` to its strike (the beam's crack then lands on top of it; no new sound).
func charge(seconds: float) -> void:
	if not _sfx.live:
		return
	var levels: Dictionary = Content.section("sfx")["volume_db"]
	_sfx.played.append(LOOP)
	_fade(Num.f(levels[LOOP]), maxf(seconds, FADE_IN))
	if not _loop.playing:
		_loop.play()


## The crackle out (the breath's charge-up is spent, or the beam ended).
func charge_end() -> void:
	if _loop.playing:
		_fade(SILENT_DB, FADE_OUT)
		_tween.tween_callback(_loop.stop)


func _fade(to_db: float, seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	if to_db > SILENT_DB and not _loop.playing:
		_loop.volume_db = SILENT_DB
	_tween = create_tween()
	_tween.tween_property(_loop, "volume_db", to_db, seconds)
