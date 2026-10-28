class_name RailWreck
extends RefCounted
## What a derailed train does after the hit (Rail owns the trains; this is their physics): the cars
## slide on against friction, slew, roll towards their side, fall off the deck where it is gone, and
## a car closing on the one ahead shares its speed (the concertina). Every number: tuning "rail".

const GRAVITY := 9.8

var _rail: Rail


func _init(rail: Rail) -> void:
	_rail = rail


## A wreck's cars slide on against friction, slew, roll towards their side, fall off the deck.
func slide(train: Rail.Train, dt: float) -> void:
	var cfg := _rail.cfg
	var mu := Num.f(cfg["friction"]) * GRAVITY
	var half_deck := Num.f(cfg["deck_width"]) * 0.5
	for i: int in train.cars.size():
		var c := train.cars[i]
		var on_deck := (
			absf(c.pos.x - _rail._x) <= half_deck and c.y >= _rail.deck_y - 0.01 and _deck_under(c)
		)
		if on_deck or c.y <= 0.0:
			var speed := c.vel.length()
			c.vel = c.vel.normalized() * maxf(0.0, speed - mu * dt) if speed > 0.0 else c.vel
			c.yaw_rate = move_toward(c.yaw_rate, 0.0, Num.f(cfg["spin_damp"]) * dt)
		else:
			c.vy -= GRAVITY * dt
		c.pos += c.vel * dt
		c.y = maxf(0.0, c.y + c.vy * dt)
		if c.y <= 0.0 and c.vy < 0.0:
			c.vy = 0.0
			c.vel *= Num.f(cfg["land_keep"])
		c.yaw += c.yaw_rate * dt
		c.roll = clampf(c.roll + c.roll_rate * dt, -PI * 0.5, PI * 0.5)
		if i > 0:
			_concertina(train.cars[i - 1], c)


## Whether the deck still stands under a car's middle (no break within half a car of it).
func _deck_under(c: Rail.Car) -> bool:
	var at := _rail._along(c.pos)
	for s: float in _rail._breaks:
		if absf(s - at) < Num.f(_rail.cfg["car_length"]) * 0.5:
			return false
	return true


## A car closing on the one ahead shares its speed and slews further (the pile-up).
func _concertina(front: Rail.Car, back: Rail.Car) -> void:
	var cfg := _rail.cfg
	if back.pos.distance_to(front.pos) >= Num.f(cfg["car_length"]) * Num.f(cfg["pile_share"]):
		return
	var shared := (front.vel + back.vel) * 0.5
	front.vel = shared
	back.vel = shared
	back.yaw_rate += signf(back.yaw_rate if back.yaw_rate != 0.0 else 1.0) * 0.2
