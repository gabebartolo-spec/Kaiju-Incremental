shader_type canvas_item;
// The HUD's dark outline (UiKit.outline_color) round everything the icon render drew: the
// largest alpha in two rings of samples `radius_px` out, laid under the picture.

uniform vec4 outline_color : source_color = vec4(0.04, 0.04, 0.05, 0.9);
uniform float radius_px = 12.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float reach = 0.0;
	for (int ring = 1; ring <= 3; ring++) {
		float r = radius_px * float(ring) / 3.0;
		for (int i = 0; i < 24; i++) {
			float a = 6.2831853 * float(i) / 24.0;
			reach = max(reach, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * r * TEXTURE_PIXEL_SIZE).a);
		}
	}
	float edge = reach * outline_color.a;
	float alpha = c.a + edge * (1.0 - c.a);
	vec3 rgb = c.a > 0.0 ? (c.rgb * c.a + outline_color.rgb * edge * (1.0 - c.a)) / max(alpha, 0.0001) : outline_color.rgb;
	COLOR = vec4(rgb, alpha);
}
