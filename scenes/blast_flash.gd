class_name BlastFlash
extends RefCounted
## The white flash of a red-barrel blast over the whole screen (clip critic round 6: "no visible
## white flash"): a white sheet under the HUD at `alpha` (a blast of full_radius or more at full
## strength, smaller ones down to small_share of it) that is gone in `seconds`, about three
## frames. Presentation only; data/tuning.json "blast_fx" screen_flash.


static func screen(host: Node, radius: float, cfg: Dictionary) -> void:
	var share := clampf(radius / Num.f(cfg["full_radius"]), Num.f(cfg["small_share"]), 1.0)
	var layer := CanvasLayer.new()
	layer.layer = Num.i(cfg["layer"])  # under the HUD: only the city whitens
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1.0, 1.0, 1.0, Num.f(cfg["alpha"]) * share)
	layer.add_child(rect)
	host.add_child(layer)
	var tween := layer.create_tween()
	tween.tween_property(rect, "color:a", 0.0, Num.f(cfg["seconds"]))
	tween.tween_callback(layer.queue_free)
