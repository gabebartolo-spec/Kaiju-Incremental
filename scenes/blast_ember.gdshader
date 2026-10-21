shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
// A blast's fireball voxel (BlastParts.fireball): the particle colour, pushed above white so the
// bloom catches it, never paled by the city's haze (a fireball is a light source, not a surface).

uniform float heat = 1.0;

void fragment() {
	ALBEDO = COLOR.rgb * heat;
	ALPHA = COLOR.a;
}
