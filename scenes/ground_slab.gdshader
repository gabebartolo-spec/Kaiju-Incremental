shader_type spatial;
// The street plan's slabs (CityGround): instance colour (sRGB) as albedo, matte, exactly the
// StandardMaterial3D it replaces while wet is 0. `wet` (0..1, set only by WeatherView, D-155) is
// the one weather switch: the road darkens and goes glossy, so lamps, fires and the sun lay soft
// sheen on it (no screen-space reflections; those are post-demo).
// WET_DARKEN and WET_ROUGHNESS are this material's identity; how wet each weather is, is data.

uniform float wet : hint_range(0.0, 1.0) = 0.0;
const float WET_DARKEN = 0.5;
const float WET_ROUGHNESS = 0.18;
const float WET_SPECULAR = 0.9;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb) * (1.0 - wet * WET_DARKEN);
	ROUGHNESS = mix(1.0, WET_ROUGHNESS, wet);
	SPECULAR = mix(0.5, WET_SPECULAR, wet);
}
