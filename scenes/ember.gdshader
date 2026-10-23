shader_type spatial;
render_mode unshaded;
// Glowing flame / ember voxel: the particle colour times `heat`, so the bloom catches it. 1 keeps a
// flame body saturated (a flame colour pushed to 1.4 blooms to cream); embers and sparks ask for more.

uniform float heat = 1.0;

void fragment() {
	ALBEDO = COLOR.rgb * heat;
	ALPHA = COLOR.a;
}
