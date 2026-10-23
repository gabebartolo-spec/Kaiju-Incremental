class_name BodyClass
extends RefCounted
## A kaiju's weight class (tuning "body_class", D-196: the Komodo is heavy): its sim pace (D-201),
## footfall, tail and aim (D-200). The sim (HeavyContact) and the drawn body (ClipGait, the
## rampage's footfall) read the same block. Pure.


## The class block of rig kind `kind` ("reptilian_adult") in a body_class table, or {} for none.
static func of(table: Dictionary, kind: String) -> Dictionary:
	var by_kind: Dictionary = table.get("kaiju", {})
	if not by_kind.has(kind):
		return {}
	var classes: Dictionary = table["classes"]
	var found: Dictionary = classes[str(by_kind[kind])]
	return found


## The class block of rig kind `kind` in the game's tuning.
static func of_kind(kind: String) -> Dictionary:
	return of(Content.section("body_class"), kind)
