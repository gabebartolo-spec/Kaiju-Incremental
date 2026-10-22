shader_type canvas_item;
render_mode unshaded;
// The colour fringe (D-142, PostFx): red and blue split apart along the line from the screen
// centre, by nothing at the centre and amount_px (at 1080 lines) at the screen edge, so the
// kaiju in the middle stays sharp while the city around it shudders. Drawn only during a burst.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount_px = 0.0;

void fragment() {
	vec2 centred = (SCREEN_UV - 0.5) * 2.0;
	float lines = 1.0 / (SCREEN_PIXEL_SIZE.y * 1080.0); // this screen's height over 1080
	vec2 shift = centred * amount_px * lines * SCREEN_PIXEL_SIZE;
	float r = texture(screen_tex, SCREEN_UV + shift).r;
	vec2 gb = texture(screen_tex, SCREEN_UV).ga;
	float b = texture(screen_tex, SCREEN_UV - shift).b;
	COLOR = vec4(r, gb.x, b, 1.0);
}
