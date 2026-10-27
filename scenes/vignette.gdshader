shader_type canvas_item;
render_mode unshaded;
// The vignette (D-142, PostFx): the screen edges darken, the same at any health (low health is the
// HUD's heartbeat vignette alone, director 2026-10-27). Alpha only, so it reads no screen texture
// and costs next to nothing. The dark edge is 0 = the centre, 1 = a screen corner.
// Dithered by a third of a level so the soft edges never band on a 4K TV.

uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 0.0;
uniform float inner = 0.5;
uniform float outer = 1.0;

const float CORNER = 0.70710678; // 1 / sqrt(2): the corner of the -1..1 square
const float LEVEL = 1.0 / 255.0;

void fragment() {
	float d = length((UV - 0.5) * 2.0) * CORNER;
	float dark = smoothstep(inner, outer, d) * strength;
	float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
	COLOR = vec4(tint.rgb, dark > 0.0 ? clamp(dark + noise * LEVEL * 0.66, 0.0, 1.0) : 0.0);
}
