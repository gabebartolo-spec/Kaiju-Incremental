shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Atomic Breath blast curtain: a wall of heat and flame standing up along the far arc of the
// breath's cone, where it strikes the street. From the game camera behind the kaiju its height
// rises above the head, so the breath reads even though the body hides the core.
// UV.x runs -1..1 along the arc, UV.y 0 at the street to 1 at the top. Additive (D-025).

uniform float progress = 0.0;
uniform float power = 1.0;
uniform float strength = 0.6;
uniform vec4 tint : source_color = vec4(1.0, 0.3, 0.08, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float side = abs(UV.x);
	float up = UV.y;
	// Flames licking upward: noise streams up and breaks the top edge into tongues.
	float lick = noise(vec2(UV.x * 9.0, up * 3.0 - TIME * 6.0)) * 0.6
		+ noise(vec2(UV.x * 21.0, up * 7.0 - TIME * 11.0)) * 0.4;
	// Flame tongues all the way up, and no base line: the lower half fades in from the street, so
	// seen from behind the curtain never reads as a sheet with an edge.
	float tongue = (1.0 - smoothstep(0.35 + 0.5 * lick, 0.75 + 0.5 * lick, up))
		* smoothstep(0.0, 0.5, up) * smoothstep(0.25, 0.65, lick + 0.2 * up);
	float centre = pow(1.0 - side, 1.2);
	// It stands up as the beam's front reaches the arc (a tenth of the life), then thins out.
	float arrive = smoothstep(0.04, 0.14, progress);
	float thin = 1.0 - smoothstep(0.5, 1.0, progress);
	vec3 hot = mix(tint.rgb, vec3(1.0, 0.7, 0.4), lick * centre);
	ALBEDO = hot * (1.6 + 0.9 * power);
	ALPHA = clamp(strength * centre * tongue * (0.45 + 0.55 * lick) * arrive * thin, 0.0, 1.0);
}
