shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
// A lamp's reflection on a wet street (WeatherView, no screen-space reflections: director 2026-10-23
// "a wet sheen"): a soft glowing smear on the ground under the lamp, drawn long toward the camera
// the way a light's reflection stretches on wet asphalt, brightest at its head and breaking up with
// ripples. One quad per lamp or lit building in a MultiMesh; the instance colour is the light and how
// much of it is on, the instance custom data (x, y) its width and length in metres. Added light, kept under the bloom threshold by the caller.

uniform vec2 toward_camera = vec2(0.0, 1.0);  // world, flat, unit
uniform float alpha = 0.55;

varying vec4 v_color;
varying vec2 v_uv;

void vertex() {
	vec2 along = toward_camera;
	vec2 across = vec2(-along.y, along.x);
	// The quad (1 x 1, in x and z) runs from the lamp's foot (z = -0.5) out toward the camera.
	vec2 off = across * VERTEX.x * INSTANCE_CUSTOM.x + along * (VERTEX.z + 0.5) * INSTANCE_CUSTOM.y;
	VERTEX = vec3(off.x, 0.0, off.y);
	v_color = COLOR;
	v_uv = UV;
}

void fragment() {
	// v runs 0 at the lamp's foot to 1 at the tip: bright and narrow at the foot, widening and fading
	// toward the camera, with ripples that break it up.
	float t = clamp(v_uv.y, 0.0, 1.0);
	float across = abs(v_uv.x * 2.0 - 1.0);
	float body = smoothstep(1.0, 0.0, across / (0.35 + 0.65 * t));
	float tail = pow(1.0 - t, 1.5);
	float ripple = 0.7 + 0.3 * sin(t * 30.0 + v_uv.x * 4.0);
	// Added light: the glow goes in ALBEDO (ALPHA stays 1) so a lamp can never add more than its own colour.
	ALBEDO = v_color.rgb * v_color.a * alpha * body * tail * ripple;
	ALPHA = 1.0;
}
