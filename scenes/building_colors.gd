class_name BuildingColors
extends RefCounted
## Each building's base colour (split out of city_view.gd to keep files small): one of the Look
## styles, picked from its style and where it stands. Presentation only.


## The base colour of every building, in the sim's order.
static func of(sim: RampageSim) -> Array[Color]:
	var colors: Array[Color] = []
	for b: RampageSim.Building in sim.buildings:
		colors.append(base(b))
	return colors


static func base(b: RampageSim.Building) -> Color:
	var styles := Look.styles()
	return styles[posmod(b.style + roundi(b.x * 3.0 + b.z), styles.size())]
