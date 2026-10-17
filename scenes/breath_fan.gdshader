shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Atomic Breath sheath: a flat fan along the breath's cone (the sim's hit cone), hot along its
// centre line and soft to its edges. The game camera sits behind the kaiju, where the body hides
// a thin beam, so the cone's width is what reads: it spills out past both shoulders.
// The fan mesh is a unit sector in its local xy plane (apex at the origin, opening along +y);
// side and reach come from the local position, so the falloff follows the real angle.
// Additive and depth-tested, so it never hides the kaiju (D-025).

uniform float progress = 0.0;
uniform float power = 1.0;
uniform float strength = 0.55;
// Seconds-as-progress the fan takes to fade in (no first-frame pop).
uniform float fade_in = 0.11;
uniform float half_angle = 0.6;
uniform vec4 tint : source_color = vec4(1.0, 0.3, 0.08, 1.0);

varying vec2 local;

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

void vertex() {
	local = VERTEX.xy;
}

void fragment() {
	float side = clamp(abs(atan(local.x, local.y)) / half_angle, 0.0, 1.0);
	float out_ = length(local);
	float centre = pow(1.0 - side, 1.3);
	float stream = noise(vec2(local.x * 6.0, out_ * 5.0 - TIME * 14.0)) * 0.6
		+ noise(vec2(local.x * 15.0, out_ * 11.0 - TIME * 23.0)) * 0.4;
	float grow = smoothstep(0.0, fade_in, progress);
	float thin = 1.0 - smoothstep(0.45, 1.0, progress);
	// The front races out with the core, then the whole fan holds and thins.
	float front = 1.0 - smoothstep(progress * 10.0 - 0.15, progress * 10.0, out_);
	// Quiet under the kaiju's feet and at the far edge, strongest in between.
	float reach = smoothstep(0.15, 0.45, out_) * (1.0 - smoothstep(0.55, 1.0, out_));
	vec3 hot = mix(tint.rgb, vec3(1.0, 0.6, 0.3), centre * centre * 0.5);
	ALBEDO = hot * (1.6 + 0.9 * power) * (0.6 + 0.4 * stream);
	ALPHA = clamp(strength * centre * (0.5 + 0.5 * stream) * grow * thin * front * reach, 0.0, 1.0);
}
