shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A glowing ribbon for the icon FX (icon_fx.gd): solid down its middle, soft to both edges, HDR
// so the glow pass blooms it. Alpha blended, not additive, so the icon's transparent background
// keeps the stroke. UV.x runs across the ribbon.

uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 2.0;
uniform float softness = 1.6;

void fragment() {
	float across = clamp(1.0 - abs(UV.x - 0.5) * 2.0, 0.0, 1.0);
	ALBEDO = tint.rgb * strength;
	ALPHA = pow(across, softness) * tint.a;
}
