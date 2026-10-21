shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// FarBeast's picture in the skyline: the little world's render of the far kaiju, cut out by its
// alpha (an opaque cut-out, so it sorts with the towers), darkened to a silhouette (`shade`)
// and hazed by the far skyline's curve (facade.gdshaderinc FAR_HAZE).

uniform sampler2D view : source_color, filter_linear;
uniform float shade = 0.6;
uniform vec3 haze_color : source_color = vec3(0.30, 0.45, 0.50);
uniform float haze = 0.004;
uniform float haze_start = 120.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 seen = texture(view, UV);
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	float f = clamp(1.0 - exp(-max(dist - haze_start, 0.0) * haze), 0.0, 0.94);
	ALBEDO = seen.rgb * shade * (1.0 - f) + haze_color * f;
	ALPHA = seen.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
