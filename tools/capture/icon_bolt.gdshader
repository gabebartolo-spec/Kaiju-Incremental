shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A lightning ribbon (icon_fx.gd): brightest down its middle, soft to both edges, HDR so the
// glow pass blooms it. UV.x runs across the ribbon.

uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 2.0;

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	ALBEDO = tint.rgb * strength * pow(clamp(across, 0.0, 1.0), 1.6);
}
