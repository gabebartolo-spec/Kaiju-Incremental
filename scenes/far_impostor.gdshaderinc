// FarBeast's picture in the skyline: the little world's render of the far kaiju. Its body
// (alpha ~1) writes depth in an opaque pre-pass, so towers in front cut it off cleanly and the
// facades behind it (and their window glow) are hidden; only the soft fringe blends. Darkened to
// a silhouette (`shade`), edged with the burning towers' warm rim, and hazed by the far
// skyline's curve (far_haze.gdshaderinc: the same haze_color and haze inputs, and height fog).
// far_impostor.gdshader takes no engine fog; far_impostor_fogged.gdshader does (FarHaze).

uniform sampler2D view : source_color, filter_linear;
uniform float shade = 0.6;
uniform vec3 haze_color : source_color = vec3(0.30, 0.45, 0.50);
uniform float haze = 0.004;
uniform float haze_start = 120.0;
#include "res://scenes/far_haze.gdshaderinc"
uniform vec3 rim_color : source_color = vec3(1.0, 0.45, 0.15);
uniform float rim = 0.8;  // strength of the warm edge
uniform float rim_width = 3.0;  // in picture pixels
uniform float px = 512.0;  // picture size in pixels
uniform bool probe = false;  // measuring: the beast alone, flat magenta

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 seen = texture(view, UV);
	float f = far_haze(length(v_world - CAMERA_POSITION_WORLD), v_world.y);
	vec2 d = vec2(rim_width / px);
	float around = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		around += texture(view, UV + vec2(cos(a), sin(a)) * d).a;
	}
	float edge = seen.a * (1.0 - around / 8.0);
	vec3 lit = seen.rgb * shade + rim_color * edge * rim;
	ALBEDO = lit * (1.0 - f) + haze_color * f;
	ALPHA = seen.a;
	if (probe) {
		ALBEDO = vec3(1.0, 0.0, 1.0);
	}
}
