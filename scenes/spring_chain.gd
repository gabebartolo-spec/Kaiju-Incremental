class_name SpringChain
extends RefCounted
## A run of physics bones (tail, antenna, tentacle) simulated as Verlet points (RigChains).
## Presentation only.

var names: Array[String] = []
var stiffness := Num.f(Content.section("chain")["stiffness"])
var gravity_scale := 1.0
## Extra rotation per bone on top of its rest pose: how the gait steers the chain.
var drive: Array[Basis] = []
## Joint world positions this frame and last frame (index 0 is the root).
var pos := PackedVector3Array()
var prev := PackedVector3Array()
## When set, the joint at that index is pinned to this world point (a tentacle tip gripping).
var pins: Dictionary = {}
## Joints never sink below this world height (a tentacle lying on the street).
var ground := -INF
## Whole-chain contraction (1 = rest length): a gripping tentacle shortens as it hauls.
var contract := 1.0


## Throws every joint (more towards the tip): a stomp whips the tail.
func kick(velocity: Vector3, dt: float) -> void:
	for i: int in range(1, pos.size()):
		prev[i] -= velocity * dt * float(i) / (pos.size() - 1)
