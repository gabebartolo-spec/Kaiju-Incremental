class_name VipView
extends Node3D
## The leader's escape helicopter drawn (D-149): the white-and-gold model flying the sim's path
## (banking into its lap, leaning into its dash), its own lower, louder rotor, its wreck when it
## goes down, and the one news-strip headline each beat gets (lift-off, kill, escape); no marker
## anywhere. The sim (VipHeli) decides everything; this reads its state and events. Numbers:
## tuning "vip". Presentation only; Rampage routes the vip_* events here.

## The rampage's sounds (Rampage sets it): the wreck's crash.
var sfx: Sfx
var _sim: RampageSim
var _cfg: Dictionary
var _model: HelicopterModel
var _rotor: AudioStreamPlayer3D
var _wreck: HeliWreck
var _layer: CanvasLayer
var _strip: NewsTicker
var _strip_left := 0.0


func _init(p_sim: RampageSim, city: CityView, p_sfx: Sfx) -> void:
	_sim = p_sim
	sfx = p_sfx
	_cfg = Content.section("vip")
	_wreck = HeliWreck.new(city, p_sim)
	_wreck.sfx = sfx
	add_child(_wreck)
	_layer = CanvasLayer.new()
	add_child(_layer)


## The leader's model (for the see-through fade when it is between the camera and the kaiju).
func nodes() -> Array:
	var out: Array = []
	if _model != null:
		out.append(_model)
	return out


## Draws a vip_* event (and the leader wreck's crash); true when the event was this view's.
func on_event(event: Dictionary) -> bool:
	match str(event["type"]):
		"vip_spawned":
			_spawn()
			_headline("liftoff", str(event["rank"]))
		"vip_down":
			_down(event)
		"vip_killed":
			_headline("killed", str(event["rank"]))
		"vip_escaped":
			_model.queue_free()
			_model = null
			_headline("escaped", str(event["rank"]))
		"heli_crashed":
			if Num.i(event["heli"]) != VipHeli.ID:
				return false
			_wreck.crashed(event)
		_:
			return false
	return true


## Per frame: the model on the sim's flight, and the headline strip's time.
func _process(delta: float) -> void:
	if _strip != null:
		_strip_left -= delta
		_strip.modulate.a = clampf(_strip_left / 0.5, 0.0, 1.0)
		if _strip_left <= 0.0:
			_strip.queue_free()
			_strip = null
	if _model == null or not _sim.vip.flying():
		return
	var vip := _sim.vip
	var look: Dictionary = _cfg["look"]
	var dir := Vector2.from_angle(vip.heading)
	_model.position = Vector3(vip.pos.x, vip.altitude(), vip.pos.y)
	var yaw := atan2(-dir.x, -dir.y)
	_model.rotation = Vector3(
		-Num.f(look["pitch"]) * vip.speed,
		lerp_angle(_model.rotation.y, yaw, minf(1.0, delta * Num.f(look["turn"]))),
		-Num.f(look["bank"]) * vip.turn_rate
	)


func _spawn() -> void:
	_model = HelicopterModel.new()
	add_child(_model)
	var look: Dictionary = _cfg["look"]
	_model.vip_look(Color(str(look["white"])), Color(str(look["gold"])))
	_model.position = Vector3(_sim.vip.pos.x, _sim.vip.altitude(), _sim.vip.pos.y)
	_rotor = AudioStreamPlayer3D.new()
	_rotor.bus = AudioBuses.of("heli_rotor")
	var source: AudioStreamOggVorbis = load("res://assets/sfx/heli_rotor.ogg")
	var loop := source.duplicate() as AudioStreamOggVorbis  # the gunships' loop stays as it is
	loop.loop = true
	_rotor.stream = loop
	_rotor.pitch_scale = Num.f(_cfg["rotor_pitch"])
	_rotor.volume_db = Num.f(_cfg["rotor_db"])
	_rotor.unit_size = Num.f(_cfg["rotor_unit"])
	_model.add_child(_rotor)
	_rotor.play()


## Shot down: the wreck takes the model (HeliWreck draws the sim's fate); the rotor stops.
func _down(event: Dictionary) -> void:
	if _model == null:
		return
	_rotor.stop()
	_wreck.downed(_model, event)
	_model = null


## One line on the news strip along the bottom of the screen, from data, for a few seconds.
func _headline(key: String, rank: String) -> void:
	var lines: Dictionary = _cfg["headlines"]
	var line := str(lines[key]).replace("{rank}", rank)
	if _strip != null:
		_strip.queue_free()
	_strip = NewsTicker.new(PackedStringArray([line]))
	_strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_strip.offset_top = -NewsTicker.HEIGHT
	_layer.add_child(_strip)
	_strip_left = Num.f(_cfg["headline_seconds"])
