extends RefCounted
## Particle size curves never use the engine's RGB-float CurveTexture (debt row 1): the GPU cannot
## sample that format, so the engine converted every one it made and warned, 117 times in a minute
## of play. FxCurve builds the same samples as an RGBA-float texture.

const SCENES := "res://scenes"
const FORBIDDEN: Array[String] = ["CurveTexture.new(", "CurveXYZTexture.new("]
## Samples compared against the curve itself (first, early, middle, last).
const PROBES: Array[int] = [0, 40, 128, 255]


static func check(check: Callable) -> void:
	_texture(check)
	_material(check)
	_source(check)


## The texture holds the curve's samples in every channel, in a format the GPU can sample.
static func _texture(check: Callable) -> void:
	var curve := Curve.new()
	curve.max_value = 4.0
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.4, 3.0))
	curve.add_point(Vector2(1.0, 0.25))
	var tex := FxCurve.texture(curve)
	check.call(
		tex.get_width() == FxCurve.WIDTH and tex.get_height() == 1,
		"the curve texture is %d x 1 (%d x %d)" % [FxCurve.WIDTH, tex.get_width(), tex.get_height()]
	)
	check.call(
		tex.get_format() == Image.FORMAT_RGBAF,
		"... in RGBA float, a format the GPU samples (format %d)" % tex.get_format()
	)
	var image := tex.get_image()
	for x: int in PROBES:
		var want := curve.sample_baked(float(x) / float(FxCurve.WIDTH))
		var got := image.get_pixel(x, 0) if image != null else Color(-1, -1, -1, -1)
		check.call(
			is_equal_approx(got.r, want) and got.g == got.r and got.b == got.r and got.a == 1.0,
			"... sample %d is the curve's %f in all three channels (%s)" % [x, want, str(got)]
		)


## set_scale puts it on the material as the size over life.
static func _material(check: Callable) -> void:
	var mat := ParticleProcessMaterial.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.1))
	FxCurve.set_scale(mat, curve)
	var tex := mat.get_param_texture(ParticleProcessMaterial.PARAM_SCALE)
	check.call(
		tex is ImageTexture and (tex as ImageTexture).get_format() == Image.FORMAT_RGBAF,
		"the particle material's scale curve is the RGBA float texture (%s)" % str(tex)
	)


## No scene builds a CurveTexture again.
static func _source(check: Callable) -> void:
	var offenders := PackedStringArray()
	var files := 0
	for file: String in DirAccess.get_files_at(SCENES):
		if not file.ends_with(".gd"):
			continue
		files += 1
		var text := FileAccess.get_file_as_string("%s/%s" % [SCENES, file])
		for word: String in FORBIDDEN:
			if text.contains(word):
				offenders.append("%s (%s)" % [file, word])
	check.call(files > 100, "the scan reads the scenes folder (%d scripts)" % files)
	check.call(
		offenders.is_empty(),
		"no scene builds an RGB-float curve texture (use FxCurve): %s" % ", ".join(offenders)
	)
