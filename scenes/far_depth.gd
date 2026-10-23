class_name FarDepth
extends RefCounted
## Far blur (director D-163: "Far blur only", locked on the kaiju): a depth-of-field on the game
## camera that blurs only what is beyond the kaiju, its focus distance following him every frame, so
## he is never blurred and there is never a near band (no tilt-shift). The haze (CityHaze)
## carries the rest of the depth. The look's numbers: far_blur_amount (0 = off), far_blur_start
## (blur begins at this many times the camera-to-kaiju distance), far_blur_ramp (and is full this
## many times that distance later). A preset may turn it off ("far_blur"); never the grade.

var _camera: Camera3D
var _attrs: CameraAttributesPractical


## Puts the far blur on `camera` unless the look or the preset says off.
func _init(camera: Camera3D) -> void:
	var quality := GraphicsPresets.far_blur(PlayerSettings.graphics_row())
	if quality < 0 or Look.value("far_blur_amount") <= 0.0:
		return
	_camera = camera
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = true
	_attrs.dof_blur_amount = Look.value("far_blur_amount")
	camera.attributes = _attrs
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_BOX)
	RenderingServer.camera_attributes_set_dof_blur_quality(
		quality as RenderingServer.DOFBlurQuality, false
	)


## Every frame: the focus follows the kaiju's feet (world position) along the view.
func follow(kaiju_feet: Vector3) -> void:
	if _attrs == null:
		return
	var depth := (kaiju_feet - _camera.global_position).dot(-_camera.global_transform.basis.z)
	if depth > 1.0:
		_attrs.dof_blur_far_distance = depth * Look.value("far_blur_start")
		_attrs.dof_blur_far_transition = depth * Look.value("far_blur_ramp")
