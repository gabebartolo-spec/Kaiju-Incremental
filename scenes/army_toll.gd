class_name ArmyToll
extends RefCounted
## What the army's own stray shells killed (StrayShell, director comments #18): people on the
## streets and fans in a stadium are the army's casualties, never the kaiju's (StreetLife).

## Civilians the strays killed, and of those the players and fans in a stadium.
var killed := 0
var fans := 0


## A reading of the street's death counts before a stray lands: [people killed, stadium dead].
static func read(street: StreetLife) -> Vector2i:
	return Vector2i(street.killed, street.civilians_killed() - street.killed + street.toll.fans)


## The stray has landed: what it killed since `before` (read) is the army's, not the kaiju's.
func take(street: StreetLife, before: Vector2i) -> void:
	var now := read(street)
	var people := now.x - before.x
	var stands := now.y - before.y
	street.killed -= people
	killed += people + stands
	fans += stands
