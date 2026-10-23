shader_type canvas_item;
// PROTOTYPE for the plates board (#97): the faint inner highlight on text. A glyph's top rim
// (a pixel with ink whose neighbour just above has none) is lightened, so the letters look
// stamped. Only light fills are lit, so the dark outline pass is left alone. Untextured
// draws (the plate) have a white texture, so they never count as a rim.
uniform float rim_px = 2.0;
uniform float strength : hint_range(0.0, 1.0) = 0.45;
uniform float min_luma = 0.4;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float up = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * rim_px)).a;
	float rim = base.a * (1.0 - up);
	float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec4 c = base * COLOR;
	c.rgb = mix(c.rgb, vec3(1.0), rim * strength * step(min_luma, luma));
	COLOR = c;
}
