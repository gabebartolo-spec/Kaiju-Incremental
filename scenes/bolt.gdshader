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
// A ribbon seen end-on (the game camera sits behind the kaiju, looking down the bolt) collapses to
// a line, so BoltView also puts a camera-facing round blob (COLOR.b = 1, UV = the corner) on the
// line's points: end-on the blobs overlap into a thick column. `min_px` keeps both from ever being
// thinner than that many pixels (at 1080p) whatever the distance.

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
// The least width on screen, in pixels at 1080p.
uniform float min_px = 0.0;

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float per_px = max(-vp.z, 0.1) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	// The least width is only eased by the taper (a stroke's thin end keeps most of it).
	float least = min_px * VIEWPORT_SIZE.y / 1080.0 * per_px * (0.4 + 0.6 * COLOR.r);
	float w = max(width * COLOR.r, least) * 0.5;
	if (COLOR.b > 0.5) {
		vp.xy += UV * w;
	} else {
		vec3 t = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 s = cross(t, normalize(vp.xyz));
		float len = length(s);
		s = len > 0.001 ? s / len : vec3(1.0, 0.0, 0.0);
		vp.xyz += s * UV.x * w;
	}
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float u = COLOR.b > 0.5 ? length(UV) : abs(UV.x);
	float shape = pow(clamp(1.0 - u, 0.0, 1.0), falloff);
	vec3 col = mix(tint.rgb, fringe.rgb, smoothstep(0.1, 1.0, u));
	float flick = 1.0 - wobble * 0.5 * (1.0 + sin(TIME * wobble_hz * 6.2832 + UV.y * 37.0));
	ALBEDO = col * boost * shape * level * flick * COLOR.g;
	ALPHA = 1.0;
}
