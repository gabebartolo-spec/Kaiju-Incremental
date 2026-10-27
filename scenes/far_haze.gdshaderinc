// The far skyline's own haze, one curve for every far shader (facade_far, concrete_stand_far,
// far_impostor and their _fogged twins; FarHaze sets it): `haze` per metre from `haze_start`
// metres on (at most 0.94), and height fog, `haze_base` more at the foot of the far city fading
// out over `haze_base_height` metres up, so it sinks into the air with no hard base line
// (director comment #37: "something funky going on with the distant city", it floated crisp above
// the haze). The includer declares `haze` and `haze_start` first. FarHaze.share_at is the same
// curve in GDScript.

uniform float haze_base = 0.0;
uniform float haze_base_height = 30.0;

float far_haze(float dist, float height) {
	float f = clamp(1.0 - exp(-max(dist - haze_start, 0.0) * haze), 0.0, 0.94);
	float foot = haze_base * exp(-max(height, 0.0) / haze_base_height);
	return clamp(f + (1.0 - f) * foot * smoothstep(haze_start * 0.5, haze_start, dist), 0.0, 0.97);
}
