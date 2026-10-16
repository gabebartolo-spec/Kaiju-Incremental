shader_type spatial;
render_mode unshaded;
// Glowing flame / ember voxel: the particle colour, pushed above white so the bloom catches it.

uniform float heat = 3.6;

void fragment() {
	ALBEDO = COLOR.rgb * heat;
	ALPHA = COLOR.a;
}
