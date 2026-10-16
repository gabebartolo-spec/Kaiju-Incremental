extends Node
## The one source of randomness, at runtime. Streams come from Seeds (sim/seeds.gd), which
## code that must compile without autoloads (sim, scenes, tests) calls directly.


func make(stream: String, index: int = 0) -> RandomNumberGenerator:
	return Seeds.make(stream, index)
