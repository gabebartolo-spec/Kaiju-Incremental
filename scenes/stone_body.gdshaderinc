// The kaiju's stone, ONE formula (Special K overload, DeathOverload; director 2026-10-27: "i dont like
// the pale blocks that come out of the explosion"). His hide turns to it as he dies
// (voxel_skin.gdshader and voxel_skin_fill.gdshader) and the pieces of him that fly off when he
// shatters are drawn with it (death_stone.gdshader), so a flying block is the same stone as the body it
// came from. Values come from data/tuning.json death.look (DeathStone.look sets them).

uniform vec3 stone_color : source_color = vec3(0.54, 0.53, 0.5);
uniform float stone_vary = 0.18;
uniform float stone_keep = 0.25;

// The stone for one cube: `tint` its own sRGB colour, `n` its 0..1 hash. The stone grey varied cube by
// cube, keeping stone_keep of his own shade. Linear albedo.
vec3 stone_rock(vec3 tint, float n) {
	float shade = dot(tint, vec3(0.299, 0.587, 0.114));
	vec3 rock = stone_color * (1.0 + (n - 0.5) * 2.0 * stone_vary);
	return mix(rock, rock * (0.6 + shade), stone_keep);
}
