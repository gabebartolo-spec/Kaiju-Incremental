class_name BuildStages
extends RefCounted
## Builds a scene over several frames (b2-30): each finished stage is drawn, with its loading
## screen's meter moved, before the next one starts. Off, `next` returns at once and the build is
## one call, as the tests and captures want it.

var on := false
var overlay: LoadingOverlay


## Called after each stage by the node that builds. False when that node left the tree meanwhile
## (the build stops). `counts` false: a wait that is not a finished stage (the meter stays).
func next(node: Node, counts: bool = true) -> bool:
	if not on:
		return true
	if counts and overlay != null:
		overlay.advance()
	await node.get_tree().process_frame
	return node.is_inside_tree()
