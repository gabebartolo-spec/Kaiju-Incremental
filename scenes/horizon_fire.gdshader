shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;
// SkylineRampage's lights across the bay: flickering fires, the warm wash a burning district
// throws on the haze. Camera-facing quads; the instance transform
// holds the centre and the size (x wide, y tall). Instance colour = tint. INSTANCE_CUSTOM:
// x = flicker seed, y = when it lights (s), z = kind (0 flame, 1 wash), w = strength.
// Lights burn through the haze more than walls do, as the far facades' windows.

uniform float now = 0.0;
uniform float haze = 0.004;
uniform float haze_start = 120.0;

varying float v_kind;
varying float v_power;
varying float v_seed;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	v_kind = INSTANCE_CUSTOM.z;
	v_seed = INSTANCE_CUSTOM.x;
	float since = now - INSTANCE_CUSTOM.y;
	float lit = smoothstep(0.0, 1.5, since);
	float flicker = 0.75 + 0.15 * sin(now * 11.0 + v_seed * 31.0) + 0.1 * sin(now * 23.0 + v_seed * 7.0);
	if (v_kind > 0.5) {
		flicker = 0.9 + 0.1 * sin(now * 1.7 + v_seed * 13.0);
	}
	float dist = length(centre - INV_VIEW_MATRIX[3].xyz);
	float f = clamp(1.0 - exp(-max(dist - haze_start, 0.0) * haze), 0.0, 0.94);
	v_power = INSTANCE_CUSTOM.w * lit * flicker * (1.0 - f * 0.6);
	if (v_kind < 0.5) {
		size *= 0.9 + 0.2 * flicker;
		centre.y += size.y * 0.4;  // flames stand on their fire, not round it
	}
	vec4 view = VIEW_MATRIX * vec4(centre, 1.0);
	VERTEX = view.xyz + vec3(VERTEX.xy * size, 0.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float shape;
	if (v_kind > 0.5) {
		shape = exp(-r * r * 3.0) * 0.5;  // the wash: broad and soft
	} else {
		// A flame: a soft tongue of light, widest low down, wavering.
		float up = clamp(1.0 - UV.y, 0.0, 1.0);
		float sway = 0.12 * sin(up * 7.0 + now * 8.0 + v_seed * 11.0) * up;
		shape = exp(-pow((p.x - sway) / mix(0.55, 0.2, up), 2.0) - pow((up - 0.3) / 0.35, 2.0));
	}
	vec3 hot = mix(COLOR.rgb, vec3(1.0, 0.92, 0.7), exp(-r * r * 8.0) * 0.3);
	ALBEDO = hot * shape * v_power;
}
