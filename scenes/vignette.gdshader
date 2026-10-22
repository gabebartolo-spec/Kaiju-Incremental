shader_type canvas_item;
render_mode unshaded;
// The vignette (D-142, PostFx): the screen edges darken, and below the low-health line a red band
// hugs the very edge and beats. Alpha only, so it reads no screen texture and costs next to
// nothing. The dark edge is 0 = the centre, 1 = a screen corner; the red band is measured in
// pixels (at 1080 lines) from the nearest screen edge: red_alpha at the edge, nothing at red_depth.
// Dithered by a third of a level so the soft edges never band on a 4K TV.

uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 0.0;
uniform float inner = 0.5;
uniform float outer = 1.0;
uniform vec4 red_tint : source_color = vec4(0.75, 0.06, 0.05, 1.0);
uniform float red_alpha = 0.0;
uniform float red_depth = 110.0;

const float CORNER = 0.70710678; // 1 / sqrt(2): the corner of the -1..1 square
const float LEVEL = 1.0 / 255.0;

void fragment() {
	float d = length((UV - 0.5) * 2.0) * CORNER;
	float dark = smoothstep(inner, outer, d) * strength;
	float lines = 1.0 / (SCREEN_PIXEL_SIZE.y * 1080.0); // this screen's height over 1080
	vec2 to_edge = min(UV, 1.0 - UV) / SCREEN_PIXEL_SIZE / lines;
	float edge = min(to_edge.x, to_edge.y);
	float red = (1.0 - smoothstep(0.0, red_depth, edge)) * red_alpha;
	float total = 1.0 - (1.0 - dark) * (1.0 - red);
	vec3 colour = total > 0.0 ? (tint.rgb * dark * (1.0 - red) + red_tint.rgb * red) / total : tint.rgb;
	float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
	COLOR = vec4(colour, total > 0.0 ? clamp(total + noise * LEVEL * 0.66, 0.0, 1.0) : 0.0);
}
