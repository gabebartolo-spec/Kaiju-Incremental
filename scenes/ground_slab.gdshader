shader_type spatial;
render_mode diffuse_burley;  // StandardMaterial3D's default diffuse (the shader default is lambert)
// The street plan's slabs (CityGround): instance colour (sRGB) as albedo, matte, exactly the
// StandardMaterial3D it replaces while wet is 0. `wet` (0..1, set only by WeatherView, D-155) is
// the one weather switch: the road darkens and goes glossy, so lamps, fires and the sun lay soft
// sheen on it (no screen-space reflections; those are post-demo).
// WET_DARKEN and WET_ROUGHNESS are this material's identity; how wet each weather is, is data.

uniform float wet : hint_range(0.0, 1.0) = 0.0;
const float WET_DARKEN = 0.62;
const float WET_ROUGHNESS = 0.18;
const float WET_SPECULAR = 0.9;
const float WET_PUDDLE_SCALE = 0.16;  // puddle patches per metre
const float WET_PUDDLE_ROUGHNESS = 0.03;
const float WET_SHEEN = 0.55;  // how much of the sky colour the glancing road gives back
uniform vec3 sheen_color : source_color = vec3(0.0);  // the sky the wet road mirrors (set with `wet`)

float wet_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float wet_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(wet_hash(i), wet_hash(i + vec2(1.0, 0.0)), f.x),
		mix(wet_hash(i + vec2(0.0, 1.0)), wet_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb) * (1.0 - wet * WET_DARKEN);
	ROUGHNESS = mix(1.0, WET_ROUGHNESS, wet);
	SPECULAR = mix(0.5, WET_SPECULAR, wet);
	// Wet only, applied last: puddle patches are mirror-smooth and give the sky back at a glancing
	// angle (fresnel), the rest of the road a faint sheen. Both are 0 when dry.
	vec2 ground = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float puddle = smoothstep(0.45, 0.7, wet_noise(ground * WET_PUDDLE_SCALE) * 0.65 + wet_noise(ground * WET_PUDDLE_SCALE * 3.7) * 0.35);
	ROUGHNESS = mix(ROUGHNESS, WET_PUDDLE_ROUGHNESS, wet * puddle);
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = sheen_color * wet * WET_SHEEN * glance * (0.35 + 0.65 * puddle);
}
