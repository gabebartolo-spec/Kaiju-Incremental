extends RefCounted
## The reptilian's tree shows its own branch (its ultimate under the data's one beam name,
## tuning "names"), and no other species' nodes.


static func own_branch(texts: Array[String]) -> bool:
	var beam := str(Content.tuning()["names"]["beam"])
	return texts.has("Tail Sweep") and texts.has("ULTIMATE: %s" % beam) and not texts.has("Scuttle")
