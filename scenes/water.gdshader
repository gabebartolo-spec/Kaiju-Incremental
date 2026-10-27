shader_type spatial;
// The city's water (D-244, D-245, D-325 step 1, the surface): the river channels and the bay in one
// look, built by WaterSurface. Presentation only: nothing reads it back. Per pixel:
//  - two scales of moving normal detail, both in world space and procedural, so nothing tiles:
//    wind waves (six directional waves on the deep-water dispersion w^2 = g k, each a sharp-crested
//    exp(sin) profile; Finch, GPU Gems 1 ch. 1; Acerola, "How Games Fake Water") and fine ripples
//    (two octaves of gradient noise drifting apart); on the river both ride its current;
//  - on the bay a long gentle swell (normals only);
//  - each wave fades out where a pixel is wider than a share of its wavelength (no shimmer at 4K),
//    the slope it loses going into the roughness, so far water keeps its sheen;
//  - depth from the depth texture (Godot docs, advanced post-processing): the view path through
//    the water to what lies under it (a quay wall, his legs) absorbs Beer-Lambert style, so the
//    water is clear for a hand's depth and murky below (`murk`), and a broken foam line marks
//    where anything meets the surface;
//  - Fresnel (Schlick, the engine's own F0 from `spec`): a steep view sees the water's body colour,
//    a grazing one the sky's reflection (the engine's specular; low roughness keeps it).
// Premultiplied blend, so the reflection stays whole where the water is clear. Depth is written,
// so the far blur and later effects see the surface, not the void under it.
render_mode blend_premul_alpha, depth_draw_always, cull_back, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec3 deep_color : source_color = vec3(0.16, 0.35, 0.42);
uniform vec3 shallow_color : source_color = vec3(0.3, 0.45, 0.4);
uniform vec3 foam_color : source_color = vec3(0.7, 0.74, 0.74);
uniform float absorb = 4.0;  // per metre of view path through the water
uniform float murk = 0.35;  // metres under the surface past which nothing shows through
uniform float foam_depth = 0.25;  // the foam line: how far under the surface a contact still foams
uniform float foam = 0.8;  // the foam line's strength (0 = none)
uniform float wave_length = 7.0;  // the longest wind wave (m); five shorter ones follow
uniform float wave_slope = 0.1;
uniform float ripple_length = 0.9;  // the fine ripples' cell (m); a second octave at 0.43x
uniform float ripple_slope = 0.12;
uniform float swell_length = 0.0;  // the bay's swell (m); 0 = none (the river)
uniform float swell_slope = 0.03;
uniform vec2 wind = vec2(0.6, -0.8);  // where the waves run (unit, x z)
uniform vec2 flow = vec2(0.0);  // the current (m/s, x z)
uniform float rough_near = 0.05;
uniform float rough_far = 0.25;
uniform float spec = 0.8;
uniform float crest_light = 0.25;  // how much lighter a crest's body colour is (light through its top)
uniform float seed = 0.0;

const float GRAVITY = 9.81;
const int WAVES = 6;
const int SWELLS = 3;
const float WAVE_STEP = 0.71;  // each wind wave this much shorter than the last (not a ratio of whole numbers)
const float SLOPE_STEP = 0.9;
const float SPREAD = 1.2;  // radians of spread round the wind
const float RIPPLE_STEP = 0.43;
const float WATER_F0 = 0.16;  // the engine's dielectric F0 is 0.16 * spec^2

float wh(float n) {
	return fract(sin(n * 91.3458 + seed * 1.37) * 47453.5453);
}

float h2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973) + seed * 0.013);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 grad2(vec2 i) {
	float a = TAU * h2(i);
	return vec2(cos(a), sin(a));
}

// Gradient noise and its slope: (n, dn/dx, dn/dy), quintic-smoothed.
vec3 gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	vec2 ga = grad2(i);
	vec2 gb = grad2(i + vec2(1.0, 0.0));
	vec2 gc = grad2(i + vec2(0.0, 1.0));
	vec2 gd = grad2(i + vec2(1.0, 1.0));
	float va = dot(ga, f);
	float vb = dot(gb, f - vec2(1.0, 0.0));
	float vc = dot(gc, f - vec2(0.0, 1.0));
	float vd = dot(gd, f - vec2(1.0, 1.0));
	float k = va - vb - vc + vd;
	float n = va + u.x * (vb - va) + u.y * (vc - va) + u.x * u.y * k;
	vec2 g = ga + u.x * (gb - ga) + u.y * (gc - ga) + u.x * u.y * (ga - gb - gc + gd)
		+ du * (u.yx * k + vec2(vb, vc) - va);
	return vec3(n, g);
}

vec2 turn(vec2 d, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(d.x * c - d.y * s, d.x * s + d.y * c);
}

// A set of directional waves round the wind: (height, dh/dx, dh/dz). fp is the pixel's footprint
// (m); lost gathers the slope variance the faded waves give up.
vec3 wave_set(vec2 p, float t, float fp, float len0, float slope0, int count, float spread, float salt, inout float lost) {
	vec3 sum = vec3(0.0);
	float len = len0;
	float s = slope0;
	for (int i = 0; i < count; i++) {
		float fi = float(i) + salt;
		vec2 d = turn(wind, (wh(fi) - 0.5) * spread);
		float k = TAU / len;
		float ph = k * dot(d, p) - sqrt(GRAVITY * k) * t + TAU * wh(fi + 17.0);
		float e = exp(sin(ph) - 1.0);
		float keep = 1.0 - smoothstep(len * 0.12, len * 0.4, fp);
		sum += keep * vec3(s / k * e, s * e * cos(ph) * d);
		lost += (1.0 - keep) * s * s;
		len *= WAVE_STEP;
		s *= SLOPE_STEP;
	}
	return sum;
}

// The fine ripples: two octaves of noise slope drifting apart. (height, dh/dx, dh/dz).
vec3 ripples(vec2 p, float t, float fp, inout float lost) {
	vec3 sum = vec3(0.0);
	float len = ripple_length;
	float s = ripple_slope;
	for (int i = 0; i < 2; i++) {
		float a = 0.6 + float(i) * 1.9;
		vec2 drift = turn(wind, float(i) * 2.2 - 0.7) * (0.35 - 0.12 * float(i));
		vec2 q = turn(p - drift * t, a) / len;
		vec3 n = gnoise(q + vec2(seed * 0.37, float(i) * 31.7));
		float keep = 1.0 - smoothstep(len * 0.25, len * 0.9, fp);
		sum += keep * s * vec3(n.x * len, turn(n.yz, -a));
		lost += (1.0 - keep) * s * s;
		len *= RIPPLE_STEP;
		s *= 0.8;
	}
	return sum;
}

// What lies behind this pixel in view space (the depth texture, both renderers' NDC).
vec3 behind(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return v.xyz / v.w;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz;
	float t = TIME;
	float fp = max(length(dFdx(p)), length(dFdy(p)));
	vec2 carried = p - flow * t;  // the river carries its waves downstream
	float lost = 0.0;
	vec3 h = wave_set(carried, t, fp, wave_length, wave_slope, WAVES, SPREAD, 0.0, lost);
	h += ripples(carried, t, fp, lost);
	if (swell_length > 0.0) {
		h += wave_set(p, t, fp, swell_length, swell_slope, SWELLS, SPREAD * 0.4, 40.0, lost);
	}
	vec3 n_world = normalize(vec3(-h.y, 1.0, -h.z));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float alpha0 = rough_near * rough_near;
	ROUGHNESS = clamp(sqrt(sqrt(alpha0 * alpha0 + lost)), rough_near, rough_far);
	METALLIC = 0.0;

	// How much water lies in front of what is under it: the view path, and how deep it sits.
	vec3 under = behind(SCREEN_UV, INV_PROJECTION_MATRIX);
	float path = max(0.0, length(under) - length(VERTEX));
	float below = max(0.0, world.y - (INV_VIEW_MATRIX * vec4(under, 1.0)).y);
	float clear = exp(-absorb * path) * (1.0 - smoothstep(murk * 0.5, murk, below));

	// Fresnel with the engine's own F0, so the body colour and the reflection share it.
	float f0 = WATER_F0 * spec * spec;
	float fres = f0 + (1.0 - f0) * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);

	float crest = clamp(h.x / max(0.001, wave_slope * wave_length / TAU), -1.0, 1.0);
	vec3 body = mix(shallow_color, deep_color, smoothstep(0.0, murk, below));
	body *= 1.0 + crest_light * crest;

	// The foam line where anything meets the surface, broken into lace that drifts with the water.
	float band = 1.0 - smoothstep(0.0, foam_depth, below);
	float lace = gnoise(carried * 1.7 + vec2(t * 0.11, seed)).x + 0.5 * gnoise(carried * 4.3 - vec2(0.0, t * 0.17)).x;
	float froth = smoothstep(0.4, 0.75, band * (0.75 + lace)) * foam;

	float seen = clear * (1.0 - fres);  // the share of what is under the water that reaches the eye
	ALBEDO = mix(body * (1.0 - clear) * (1.0 - fres), foam_color, froth);
	ALPHA = mix(1.0 - seen, 1.0, froth);
	SPECULAR = spec * (1.0 - froth);
	ROUGHNESS = mix(ROUGHNESS, 0.7, froth);
}
