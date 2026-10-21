shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Atomic Breath core: a tapered cylinder (CylinderMesh, mouth at the bottom) of hot plasma.
// A white-hot spine fades to the species colour at the edges; turbulence streams away from
// the mouth. `progress` 0..1 from script: a hard flare, a short hold, then the beam thins out.
// Additive, narrow and depth-tested, so it never hides the kaiju (D-025). The game camera sits
// behind the kaiju and looks almost down the beam, so the glow cannot rely on edge-on views.

uniform float progress = 0.0;
uniform float power = 1.0;
// Progress the beam takes to fade in (set from fx.breath_fade_in): no first-frame pop.
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
	// UV.y runs 0 at the far end to 1 at the mouth on Godot's CylinderMesh.
	float along = 1.0 - UV.y;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 2.5);
	float stream = noise(vec2(UV.x * 10.0, along * 7.0 - TIME * 18.0)) * 0.65
		+ noise(vec2(UV.x * 23.0, along * 15.0 - TIME * 31.0)) * 0.35;
	float flare = smoothstep(0.0, fade_in, progress);
	float thin = 1.0 - smoothstep(0.45, 1.0, progress);
	// The front races out over the first tenth of the life, then the whole beam holds.
	float front = 1.0 - smoothstep(progress * 10.0 - 0.15, progress * 10.0, along);
	float tip = 1.0 - smoothstep(0.75, 1.0, along);
	vec3 hot = mix(tint.rgb, vec3(1.0, 0.97, 0.85), core * core);
	ALBEDO = hot * (1.6 + 1.4 * power) * (0.55 + 0.45 * stream);
	float body = 0.3 + 0.7 * core;
	ALPHA = clamp(body * (0.35 + 0.65 * stream) * flare * thin * front * tip, 0.0, 1.0);
}
