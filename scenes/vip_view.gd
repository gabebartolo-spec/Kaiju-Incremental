class_name VipView
extends Node3D
## The leader's escape helicopter drawn (D-149): the white-and-gold model flying the sim's path
## (banking into its lap, leaning into its dash), its own lower, louder rotor, its wreck when it
## goes down, and the one news-strip headline each beat gets (lift-off, kill, escape); no marker
## anywhere. The sim (VipHeli) decides everything; this reads its state and events. Numbers:
## tuning "vip". Presentation only; PowersView owns it and routes the vip_* events here.

## The rampage's sounds (PowersView passes them): the wreck's crash.
var sfx: Sfx
var _sim: RampageSim
var _cfg: Dictionary
var _model: HelicopterModel
var _rotor: AudioStreamPlayer3D
var _wreck: HeliWreck
var _layer: CanvasLayer
var _strip: NewsTicker
var _strip_left := 0.0
var _beacon: Node3D
var _clock := 0.0


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
			_model.queue_free()  # and its lamp with it
			_model = null
			_beacon = null
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
	_clock += delta
	if _beacon != null:
		var lamp: Dictionary = _cfg["beacon"]
		_beacon.visible = fposmod(_clock, Num.f(lamp["period"])) < Num.f(lamp["on"])
	if _strip != null:
		_strip_left -= delta
		var slide := Num.f(_cfg["slide_seconds"])  # the last moments it slides down off the screen
		var gone := 1.0 - clampf(_strip_left / slide, 0.0, 1.0)
		_strip.offset_top = -NewsTicker.HEIGHT * (1.0 - gone)
		_strip.offset_bottom = NewsTicker.HEIGHT * gone
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
	_beacon = _lamp()
	_model.add_child(_beacon)


## A blinking gold lamp on the mast and its light on the roofs: it reads in the dark as the leader,
## unlike the gunships.
func _lamp() -> Node3D:
	var lamp: Dictionary = _cfg["beacon"]
	var look: Dictionary = _cfg["look"]
	var gold := Color(str(look["gold"]))
	var holder := Node3D.new()
	holder.position = Vector3(0.0, Num.f(lamp["height"]), 0.0)
	var bulb := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = Num.f(lamp["size"])
	ball.height = ball.radius * 2.0
	ball.material = CityView.glow(gold, Num.f(lamp["energy"]))
	bulb.mesh = ball
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(bulb)
	var light := OmniLight3D.new()
	light.light_color = gold
	light.light_energy = Num.f(lamp["light"])
	light.omni_range = Num.f(lamp["range"])
	light.shadow_enabled = false
	holder.add_child(light)
	return holder


## Shot down: the wreck takes the model (HeliWreck draws the sim's fate); the rotor stops.
func _down(event: Dictionary) -> void:
	if _model == null:
		return
	_rotor.stop()
	_beacon.queue_free()
	_beacon = null
	_wreck.downed(_model, event)
	_model = null


## One line on the news strip along the bottom of the screen, from data, for a few seconds.
func _headline(key: String, rank: String) -> void:
	var lines: Dictionary = _cfg["headlines"]
	var line := str(lines[key]).replace("{rank}", rank)
	if _strip != null:
		_strip.queue_free()
	_strip = NewsTicker.new(PackedStringArray([line]), false)
	_strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_strip.offset_top = -NewsTicker.HEIGHT
	_layer.add_child(_strip)
	# the swatted headline stays up killed_seconds with play running on, then slides away
	_strip_left = Num.f(_cfg["killed_seconds" if key == "killed" else "headline_seconds"])
