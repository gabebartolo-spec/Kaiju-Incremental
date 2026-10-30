class_name AirstrikeView
extends Node3D
## Time's up (D-263, director 2026-10-31 "Jet run"): the sim's airstrike event flies `jets` olive
## jets (Tripo J01, assets/vehicles/jet) in a V from `from` to `to` in `seconds` at `altitude`, a
## sonic boom as they pass over him. The bombs are BlastFx's (airstrike_bomb). Reads the event;
## decides nothing. Part of PowersView. Looks: data/tuning.json vehicles.jet_height, jet_spacing.

const BASE := "res://assets/vehicles/jet"
const SALT := 61

## Jets flown so far (read by the flow suite and the capture).
var flown := 0
var _sfx: Sfx
## The jets in the air: [node, from, to, seconds, seconds gone, boomed].
var _runs: Array[Array] = []


func _init(sfx: Sfx) -> void:
	_sfx = sfx


## Takes the airstrike event; false for any other.
func on_event(event: Dictionary) -> bool:
	if str(event["type"]) != "airstrike":
		return false
	var cfg := Content.section("vehicles")
	var a: Vector2 = event["from"]
	var b: Vector2 = event["to"]
	var y := Num.f(event["altitude"])
	var along := (b - a).normalized()
	var side := along.orthogonal()
	var spacing := Num.f(cfg["jet_spacing"])
	var parts := VehicleParts.new(BASE, Num.f(cfg["jet_height"]))
	var centre := parts.pivot("body") * Vector3(1, 0, 1)
	for i: int in Num.i(event["jets"]):
		# A V: the lead on the line, the others behind it, one each side in turn.
		var rank := (i + 1) / 2
		var off := side * spacing * rank * (1.0 if i % 2 == 1 else -1.0) - along * spacing * rank
		var jet := Node3D.new()
		jet.add_child(parts.build("body", -centre, SALT))
		jet.rotation.y = atan2(-along.x, -along.y)
		add_child(jet)
		var from := Vector3(a.x + off.x, y, a.y + off.y)
		var to := Vector3(b.x + off.x, y, b.y + off.y)
		jet.position = from
		_runs.append([jet, from, to, Num.f(event["seconds"]), 0.0, i > 0])
		flown += 1
	return true


func _process(delta: float) -> void:
	var left: Array[Array] = []
	for run: Array in _runs:
		var jet: Node3D = run[0]
		run[4] = Num.f(run[4]) + delta
		var share := Num.f(run[4]) / maxf(0.01, Num.f(run[3]))
		if share >= 1.0:
			jet.queue_free()
			continue
		var from: Vector3 = run[1]
		var to: Vector3 = run[2]
		jet.position = from.lerp(to, share)
		if not run[5] and share >= 0.5:  # the lead passes over him
			run[5] = true
			_sfx.play_at("sonic_boom", jet.position)
		left.append(run)
	_runs = left
