shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
// The far city's window light on the bay (FarWaterGlow, tuning city far_reflect): a pass drawn over
// the bay's own water material (its next_pass), so the water and its colour are unchanged
// elsewhere. Within `reach` metres of the far shore it lays a faint share (`strength`) of the
// window palette's light over the water, fading to none further out, so nothing near the camera
// changes. The engine's fog lands on it as on the water (director comment #37; lead 2026-10-27:
// real night bays show the city's lit windows reflected on the water near the far shore).

uniform vec3 glow_color : source_color = vec3(0.91, 0.85, 0.69);
uniform float energy = 0.0;
uniform float strength = 0.0;
uniform float shore_z = 0.0;
uniform float reach = 1.0;

varying float v_from_shore;

void vertex() {
	v_from_shore = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z - shore_z;
}

void fragment() {
	ALBEDO = glow_color * energy;
	ALPHA = strength * (1.0 - smoothstep(0.0, reach, max(v_from_shore, 0.0)));
}
