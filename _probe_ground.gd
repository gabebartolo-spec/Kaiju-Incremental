extends SceneTree

const SimRubbleSlabs := preload("res://tests/lib/sim_rubble_slabs.gd")


func _initialize() -> void:
	var fails := [0]
	var check := func(ok: bool, what: String) -> void:
		print(("PASS " if ok else "FAIL ") + what)
		if not ok:
			fails[0] += 1
	var h := SimRubbleSlabs.new(check)
	h._on_the_ground()
	print("fails ", fails[0])
	quit()
