shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// The game's one beam shader (VFX_STYLE family 6): a camera-facing ribbon for a bolt drawn from an
// ImmediateMesh (BoltView). Per vertex the mesh gives NORMAL = the line's tangent there, UV.x = the
// side (-1 / +1), UV.y = how far along the line, COLOR.r = width share, COLOR.g = brightness
// share. The vertex stage turns the ribbon to face the camera, so a rebuild is needed only when
// the shape changes, never for the view. Two materials draw one bolt: a narrow white-hot core and
// a wide halo (tint at the middle, fringe at the edges); only width and colour differ by owner
// (the breath, the Thunder Beam, later the Taskforce's lasers). Additive and unlit, so it lights
// nothing itself (the rig's two lights do) and never hides the kaiju (D-025). Gl_compatibility
// has no HDR, so `boost` simply clips there and the wide halo carries the glow.

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform vec4 fringe : source_color = vec4(1.0, 0.5, 0.12, 1.0);
// Full ribbon width in world units where COLOR.r is 1.
uniform float width = 1.0;
// 0..1 from script: the stroke's current brightness.
uniform float level = 1.0;
// Colour multiplier above 1 so the bloom catches it (Forward+).
uniform float boost = 1.0;
// How fast the brightness falls from the ribbon's middle to its edge.
uniform float falloff = 2.0;
// The shallow brightness wobble between strokes (never a blackout): share of brightness lost, Hz.
uniform float wobble = 0.15;
uniform float wobble_hz = 22.0;

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 t = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 s = cross(t, normalize(vp.xyz));
	float len = length(s);
	s = len > 0.001 ? s / len : vec3(1.0, 0.0, 0.0);
	vp.xyz += s * UV.x * width * COLOR.r * 0.5;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float u = abs(UV.x);
	float shape = pow(clamp(1.0 - u, 0.0, 1.0), falloff);
	vec3 col = mix(tint.rgb, fringe.rgb, smoothstep(0.1, 1.0, u));
	float flick = 1.0 - wobble * 0.5 * (1.0 + sin(TIME * wobble_hz * 6.2832 + UV.y * 37.0));
	ALBEDO = col * boost * shape * level * flick * COLOR.g;
	ALPHA = 1.0;
}
