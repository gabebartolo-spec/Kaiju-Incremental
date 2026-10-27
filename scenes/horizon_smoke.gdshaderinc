// SkylineRampage's smoke columns and collapse dust across the bay: camera-facing puffs placed
// by this shader from the elapsed time (`now`, set by script), so a column costs no CPU.
// Instance transform: the column's base and the puff's base size. INSTANCE_CUSTOM: x = the
// puff's place in its column (0..1), y = when the column starts (s), z = kind (0 smoke column,
// 1 collapse dust), w = seed. Hazes like the far skyline (facade.gdshaderinc FAR_HAZE).
// horizon_smoke.gdshader takes no engine fog; horizon_smoke_fogged.gdshader does (FarHaze).

#include "res://scenes/surface_detail.gdshaderinc"

uniform float now = 0.0;
uniform float rise_s = 14.0;  // a smoke puff's trip up the column
uniform float height = 140.0;
uniform float drift = 0.35;  // sideways lean of a column per unit of height (the wind)
uniform float dust_s = 7.0;  // a collapse cloud's life
uniform vec3 smoke_color : source_color = vec3(0.18, 0.16, 0.15);
uniform vec3 dust_color : source_color = vec3(0.42, 0.38, 0.33);
uniform vec3 ember_color : source_color = vec3(1.0, 0.45, 0.15);
uniform float ember = 1.2;
uniform vec3 haze_color : source_color = vec3(0.30, 0.45, 0.50);
uniform float haze = 0.004;
uniform float haze_start = 120.0;

varying float v_alpha;
varying float v_age;
varying float v_haze;
varying float v_kind;
varying float v_seed;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	float since = now - INSTANCE_CUSTOM.y;
	float slot = INSTANCE_CUSTOM.x;
	float puff = INSTANCE_CUSTOM.w;
	v_kind = INSTANCE_CUSTOM.z;
	v_seed = puff;
	vec3 centre;
	if (v_kind < 0.5) {
		// A puff rises the column and comes round again; the column grows from its base.
		float trip = since / rise_s;
		v_age = fract(trip + slot);
		float grown = step(v_age, trip);
		centre = base + vec3(drift * height * v_age * v_age + sin(puff * 40.0 + v_age * 6.0) * size * 0.3,
			height * v_age, 0.0);
		size *= 1.0 + 3.0 * v_age;
		v_alpha = grown * sin(3.14159 * sqrt(v_age)) * smoothstep(0.0, 2.0, since);
	} else {
		// Dust rolls out from a falling tower's foot and settles.
		v_age = clamp(since / dust_s, 0.0, 1.0);
		float a = puff * 6.2832;
		float spread = size * (0.6 + 2.2 * sqrt(v_age)) * (0.5 + slot);
		centre = base + vec3(cos(a) * spread, size * (0.3 + 1.2 * v_age) * (0.4 + slot), sin(a) * spread * 0.4);
		size *= 1.0 + 1.5 * v_age;
		v_alpha = step(0.0, since) * (1.0 - v_age) * smoothstep(0.0, 0.08, v_age + 0.01);
	}
	float dist = length(centre - INV_VIEW_MATRIX[3].xyz);
	v_haze = clamp(1.0 - exp(-max(dist - haze_start, 0.0) * haze), 0.0, 0.94);
	vec4 view = VIEW_MATRIX * vec4(centre, 1.0);
	VERTEX = view.xyz + vec3(VERTEX.xy * size, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float n = sd_fbm(UV * 4.0 + v_seed * 17.0, 1.0);
	float mask = 1.0 - smoothstep(0.25, 1.0, length(p) + (n - 0.5) * 0.6);
	vec3 col = v_kind < 0.5 ? smoke_color : dust_color;
	col *= 0.8 + 0.35 * n;
	vec3 emit = v_kind < 0.5 ? ember_color * ember * pow(1.0 - v_age, 6.0) : vec3(0.0);
	ALBEDO = col * (1.0 - v_haze);
	EMISSION = emit * (1.0 - v_haze * 0.6) + haze_color * v_haze;
	ROUGHNESS = 1.0;
	ALPHA = clamp(mask * v_alpha * (1.0 - v_haze * 0.5), 0.0, 1.0);
}
