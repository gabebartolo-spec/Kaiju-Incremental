class_name FxCurve
extends RefCounted
## A Curve as the texture a particle material samples for its size over life (scale_curve). The
## engine's CurveTexture is RGB float, which the GPU cannot sample, so the engine converted every
## one it made and warned ("Image format RGBFloat not supported by hardware"; 117 times in a minute
## of play, debt row 1). The same samples as RGBA float say the same thing with no conversion.

## Samples across the curve (CurveTexture's own width).
const WIDTH := 256


## The curve as a one-row RGBA float texture: every channel is the curve, as CurveTexture's are
## (the particle shader reads scale_curve as a 3-vector).
static func texture(curve: Curve) -> ImageTexture:
	var image := Image.create_empty(WIDTH, 1, false, Image.FORMAT_RGBAF)
	for x: int in WIDTH:
		var v := curve.sample_baked(float(x) / float(WIDTH))  # as CurveTexture samples it
		image.set_pixel(x, 0, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(image)


## The particles' size over their life follows `curve` (ParticleProcessMaterial.scale_curve).
static func set_scale(mat: ParticleProcessMaterial, curve: Curve) -> void:
	mat.set_param_texture(ParticleProcessMaterial.PARAM_SCALE, texture(curve))
