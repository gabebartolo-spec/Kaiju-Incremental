shader_type spatial;
// The beach along the bottom of the title picture (scenes/title_shore.gd): the game's own sand
// (sand.gdshader: grains a voxel each, wet and darker along the waterline) at night, the broken
// foam line where the lapping water meets it (as water.gdshader draws it where anything meets the
// surface), and the orange of the fires on the far shore washing the sand nearest the water,
// brightest by the water and under the burning district, dark like the sand where it is wet.
// Unlit like the quay it replaced, so the light is exactly what is painted here; presentation only.
render_mode unshaded, blend_mix, cull_back, fog_disabled;

uniform sampler2D grains : source_color, filter_nearest_mipmap;
uniform float wet_width = 4.0;  // metres of wet sand up from the waterline
uniform float wet_dark = 0.5;  // the wettest sand's lightness (share of the dry sand's)
uniform float night = 0.4;  // the dry sand's lightness at night (share of its day colour)
uniform float grade = 0.035;  // the slope's rise per metre (m)
uniform float tide_y = -0.77;  // the water's surface this frame (world y, set each frame)
uniform vec3 foam_color : source_color = vec3(0.54, 0.58, 0.6);  // already at night
uniform float foam_width = 1.5;  // metres of sand above the water the foam line covers
uniform float foam = 0.8;  // the foam line's strength (0 = none)
uniform vec3 fire_colour : source_color = vec3(1.0, 0.42, 0.1);
uniform float fire_x = 60.0;  // the burning district's middle (world x)
uniform float fire_width = 260.0;  // how far along the shore its light reaches (m)
uniform float fire_reach = 10.0;  // how far up the sand from the waterline (m)
uniform float fire_strength = 0.5;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise, -0.5 .. 0.5, smooth.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) - 0.5;
}

void fragment() {
	float up = max(world.y - tide_y, 0.0) / grade;  // metres up the sand from the water's edge
	float wet = 1.0 - smoothstep(0.0, wet_width, up);
	wet *= wet;
	vec3 col = texture(grains, UV).rgb * night * mix(1.0, wet_dark, wet);
	float along = exp(-pow((world.x - fire_x) / fire_width, 2.0));
	float wash = exp(-up / fire_reach) * (0.35 + 0.65 * along) * mix(1.0, wet_dark, wet);
	col += fire_colour * wash * fire_strength;
	float band = 1.0 - smoothstep(0.0, foam_width, up);
	float lace = vnoise(world.xz * 0.6) + 0.5 * vnoise(world.xz * 1.7);
	float froth = smoothstep(0.4, 0.75, band * (0.75 + lace)) * foam;
	col = mix(col, foam_color, froth);
	ALBEDO = col;
}
