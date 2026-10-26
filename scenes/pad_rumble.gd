class_name PadRumble
extends RefCounted
## Pad rumble (director 2026-10-26, D-259 "Yes, scaled by size, with a toggle"): each footfall
## thuds, harder at every growth stage; a landed stomp and a toppled building jolt; the breath and
## the ultimate beam buzz while they burn. Every number is a row of tuning "rumble"; Settings >
## ACCESSIBILITY > Rumble turns it off (PlayerSettings.rumble). Presentation only: Rampage calls
## it with the sim's events and the kaiju's footfalls; it decides nothing.

## Where a rumble goes: (weak, strong, seconds). Tests swap in a recorder; the game shakes every
## connected pad.
var sink: Callable
## The rumbles sent (weak, strong, seconds) this rampage, for the tests.
var sent: Array[Vector3] = []
var _cfg: Dictionary
var _sim: RampageSim


func _init(sim: RampageSim) -> void:
	_sim = sim
	sink = _shake_pads
	_cfg = Content.section("rumble")


## A foot came down (KaijuModel.foot_planted): its stage's thud. A tail slam is not a footfall.
func footfall(side: String, _strength: float, _at: Vector3) -> void:
	if side != "tail":
		_send(_staged("footfall"))


## A stomp landed under its foot: its stage's jolt.
func stomp() -> void:
	_send(_staged("stomp"))


## The sim's events: a toppled building lands (collapse), the breath fires, the beam starts.
func on_event(event: Dictionary) -> void:
	match str(event["type"]):
		"fall_land":
			if str(event.get("kind", "")) == "topple":
				_send(_row("collapse"))
		"ability":
			if str(event.get("kind", "")) == "cone":
				_send(_row("breath"))
		"beam_start":
			var row := _row("breath").duplicate()
			row["seconds"] = Num.f(event.get("seconds", row["seconds"]))
			_send(row)


func _row(key: String) -> Dictionary:
	return _cfg[key]


## The row of a per-stage list for the kaiju's growth stage now (1 = baby).
func _staged(key: String) -> Dictionary:
	var rows: Array = _cfg[key]
	return rows[clampi(_sim.size_tier() - 1, 0, rows.size() - 1)]


func _send(row: Dictionary) -> void:
	if not PlayerSettings.rumble:
		return
	var r := Vector3(Num.f(row["weak"]), Num.f(row["strong"]), Num.f(row["seconds"]))
	sent.append(r)
	sink.call(r)


static func _shake_pads(r: Vector3) -> void:
	for pad: int in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, r.x, r.y, r.z)
