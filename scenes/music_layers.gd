class_name MusicLayers
extends Node
## The city's music in layers (D-125, "Layers build up"): one track per city, split into stems
## that fade in as the destruction ramps up, on one locked tempo. The stems are the sub-streams
## of ONE AudioStreamSynchronized on ONE player, so they start together, stay together and loop
## together; fading a stem only changes its volume, never its position. Tempo, bar count and the
## stem list live in tuning "music". A stem whose file is not there yet plays as silence of the
## exact bar length, so the director's Suno stems drop in at their file paths with no code change.
## Presentation only: it follows the phase CitySound hands it and decides nothing.

## Per stem, in track order: its fade-in window and current level (dB), read by tests.
var stems: Array[Dictionary] = []
var levels: Array[float] = []
## Which stems are still silent placeholders (no file at their path yet).
var placeholders: Array[bool] = []
var track: Dictionary
var player: AudioStreamPlayer
var stream: AudioStreamSynchronized
var _cfg: Dictionary


## track: one row of tuning "music" "tracks"; cfg: the "music" section.
func _init(row: Dictionary, cfg: Dictionary) -> void:
	track = row
	_cfg = cfg


func _ready() -> void:
	var rows: Array = track["stems"]
	stream = AudioStreamSynchronized.new()
	stream.stream_count = rows.size()
	var quiet := silence(track, _cfg)  # one stand-in shared by every stem without a file
	for i: int in rows.size():
		var stem: Dictionary = rows[i]
		var file := str(stem["file"])
		var real := ResourceLoader.exists(file)
		var source: AudioStream = load(file) if real else quiet
		if source is AudioStreamOggVorbis:
			source.loop = true  # each stem loops in place; the sync stream keeps them together
		stream.set_sync_stream(i, source)
		stream.set_sync_stream_volume(i, Num.f(_cfg["silent_db"]))
		stems.append(stem)
		levels.append(Num.f(_cfg["silent_db"]))
		placeholders.append(not real)
	var off := lock_error(_streams(), track)
	if off > Num.f(_cfg["lock_tolerance_s"]):
		push_warning("music %s: a stem is %.3f s off the bar grid" % [track["id"], off])
	player = AudioStreamPlayer.new()
	player.bus = StringName(str(_cfg["bus"]))
	player.stream = stream
	add_child(player)
	player.play()


## One frame: each stem moves toward its level at `phase` (the same phase the city beds follow),
## at fade_db_per_s so a stem swells in rather than switching on.
func follow(phase: float, delta: float) -> void:
	var silent := Num.f(_cfg["silent_db"])
	for i: int in stems.size():
		var goal := CityCurve.stem_db(stems[i], phase, silent)
		levels[i] = move_toward(levels[i], goal, Num.f(_cfg["fade_db_per_s"]) * delta)
		stream.set_sync_stream_volume(i, levels[i])


func _streams() -> Array:
	var out: Array = []
	for i: int in stream.stream_count:
		out.append(stream.get_sync_stream(i))
	return out


## The length in seconds of one pass of `row`'s track: bars * beats per bar * 60 / bpm.
static func track_seconds(row: Dictionary) -> float:
	var beats := Num.f(row["bars"]) * Num.f(row["beats_per_bar"])
	return beats * 60.0 / Num.f(row["bpm"])


## A silent looping stand-in exactly one pass of `row` long, for a stem with no file yet.
static func silence(row: Dictionary, cfg: Dictionary) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	var rate := Num.i(cfg["placeholder_rate"])
	var frames := roundi(track_seconds(row) * rate)
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	var silence_data := PackedByteArray()
	silence_data.resize(frames * 2)  # resize zero-fills: 16-bit silence
	wav.data = silence_data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = frames
	return wav


## How far the worst stem is from the track's bar grid, in seconds: 0 when every stem is exactly
## bars * beats * 60 / bpm long. A stem off the grid drifts against the others at every loop, so
## anything over tuning "music" "lock_tolerance_s" is not locked.
static func lock_error(streams: Array, row: Dictionary) -> float:
	var worst := 0.0
	for s: AudioStream in streams:
		worst = maxf(worst, absf(s.get_length() - track_seconds(row)))
	return worst
