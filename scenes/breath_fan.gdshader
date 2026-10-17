shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Atomic Breath sheath: a flat fan along the breath's cone (the sim's hit cone), hot along its
// centre line and soft to its edges. The game camera sits behind the kaiju, where the body hides
// a thin beam, so the cone's width is what reads: it spills out past both shoulders.
// UV.x is the side (-1..1 across the cone), UV.y how far out (0 at the mouth, 1 at full reach).
// Additive and depth-tested, so it never hides the kaiju (D-025).

uniform float progress = 0.0;
uniform float power = 1.0;
uniform float strength = 0.55;
// Seconds-as-progress the fan takes to fade in (no first-frame pop).
uniform float fade_in = 0.11;
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
	float out_ = UV.y;
	float centre = pow(1.0 - side, 2.0);
	float stream = noise(vec2(UV.x * 6.0, out_ * 5.0 - TIME * 14.0)) * 0.6
		+ noise(vec2(UV.x * 15.0, out_ * 11.0 - TIME * 23.0)) * 0.4;
	float grow = smoothstep(0.0, fade_in, progress);
	float thin = 1.0 - smoothstep(0.45, 1.0, progress);
	// The front races out with the core, then the whole fan holds and thins.
	float front = 1.0 - smoothstep(progress * 5.0 - 0.15, progress * 5.0, out_);
	// Quiet near the mouth (over the head) and at the far edge, strongest in between.
	float reach = smoothstep(0.08, 0.3, out_) * (1.0 - smoothstep(0.8, 1.0, out_));
	vec3 hot = mix(tint.rgb, vec3(1.0, 0.95, 0.8), centre * centre);
	ALBEDO = hot * (1.2 + 0.8 * power) * (0.6 + 0.4 * stream);
	ALPHA = clamp(strength * centre * (0.5 + 0.5 * stream) * grow * thin * front * reach, 0.0, 1.0);
}
