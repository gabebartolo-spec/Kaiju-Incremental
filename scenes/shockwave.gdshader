shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// A ground pressure ripple: a ring of street dust that runs out from the impact with a bright
// soil rim at its leading edge, an inner fill that fades behind it and a small mound of dust
// at the impact point (docs/VFX_STYLE.md families 3 and 7: the same dust as a footfall's
// puffs). It is unshaded in the street dust's own tone (Fx._dust_tone), so it is the same warm
// colour at night and at noon, and it is blended in by alpha only: never darkened, multiplied or
// black. `peak` caps its opacity, `soft` is the inner fill's width as a share of the radius
// (data/tuning.json fx.shockwave). `progress` 0..1 is driven from script; the quad is scaled to
// the full radius.

uniform float progress = 0.0;
uniform vec4 tint : source_color = vec4(0.541, 0.435, 0.306, 1.0);
uniform float peak = 0.55;
uniform float soft = 0.4;
// The rim's width as a share of the full radius (about 35 px for a 320 px stomp ring), and the
// impact mound's radius (about 45 px).
uniform float rim_width = 0.11;
uniform float mound_radius = 0.14;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 dir = p / max(r, 0.001);
	float lump = noise(dir * 2.2 + 7.0);  // a smooth ragged front, no spokes
	float grain = noise(p * 6.0 + progress * 2.0);
	float front = progress + (lump - 0.5) * 0.08;
	// The rim: brightest just inside the leading edge, soft on both sides.
	float rim = smoothstep(front - rim_width, front - rim_width * 0.4, r)
		* (1.0 - smoothstep(front - 0.01, front + 0.03, r));
	// The fill behind it, fading toward the centre.
	float fill = smoothstep(front - soft, front - rim_width, r)
		* (1.0 - smoothstep(front - rim_width, front, r)) * 0.3;
	// The mound at the impact: dust thrown up and out, gone by the ring's middle.
	float mound = (1.0 - smoothstep(0.0, mound_radius * (1.0 + progress), r))
		* (1.0 - smoothstep(0.0, 0.6, progress));
	float rim_edge = 1.0 - smoothstep(0.85, 1.0, r);  // never a cut at the quad's edge
	float body = max(max(rim, fill), mound * 0.7) * rim_edge;
	float fade = 1.0 - progress * progress;
	vec3 dust = mix(vec3(dot(tint.rgb, vec3(0.333))), tint.rgb, 0.6);  // as muted as the puffs
	ALBEDO = dust * mix(0.8, 1.25, rim) * (0.88 + 0.24 * grain);
	ALPHA = body * fade * peak * (0.85 + 0.3 * grain) * tint.a;
}
