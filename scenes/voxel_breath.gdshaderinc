// The breath (D-165, ClipIdle): the skin shaders push the back, shoulders and flanks out from the
// spine and up as he breathes in, and let them fall back, seen from behind where the camera sits.
// The cubes and the filler under them take the same push at the same place, so no gap opens and
// every cube keeps its size and square axes. `breath` is rig units (signed); breath_k holds each
// bone's share (the main bones weigh in by their skin weights); the underside barely moves.
// `breath` is the biggest push now (rig units, depth and weight in); breath_phase where the breath is in
// its cycle (0..1) and breath_shape its (inhale, rest) shares; breath_lag the share of a breath it
// reaches the hips after the neck, so the plates ripple down the back.
uniform float breath = 0.0;
uniform float breath_phase = 0.0;
uniform float breath_lag = 0.0;
uniform vec2 breath_shape = vec2(0.4, 0.1);
uniform float breath_lift = 0.5;
uniform float breath_belly = 0.2;
// The spine's axis, pelvis to the neck's base, in skin space (this frame's pose).
uniform vec3 breath_a = vec3(0.0);
uniform vec3 breath_b = vec3(0.0, 1.0, 0.0);
uniform float breath_k[128];

float breath_curve(float p) {
	p = fract(p);
	float out_end = 1.0 - breath_shape.y;
	if (p < breath_shape.x) {
		return 0.5 - 0.5 * cos(PI * p / breath_shape.x);
	}
	if (p < out_end) {
		return 0.5 + 0.5 * cos(PI * (p - breath_shape.x) / (out_end - breath_shape.x));
	}
	return 0.0;
}

// Options for the director's trade (all 0 = off, the default): breath_swell widens the body
// sideways by that share of a point's distance from the spine, breath_plate raises the dorsal plate
// rows' crests (x rig units; y, z the first crest's rest z and the rows' spacing), both scaled by
// breath_depth, the breath's depth and weight.
uniform float breath_depth = 0.0;
uniform float breath_swell = 0.0;
uniform vec3 breath_plate = vec3(0.0, 0.0, 1.0);

vec3 breath_push(vec3 rest, vec3 p, float share) {
	vec3 ab = breath_b - breath_a;
	float t = clamp(dot(p - breath_a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	vec3 radial = p - (breath_a + ab * t);
	float r = length(radial);
	vec3 dir = r > 0.0001 ? radial / r : vec3(0.0, 1.0, 0.0);
	float belly = mix(breath_belly, 1.0, smoothstep(-0.4, 0.2, dir.y));
	float c = breath_curve(breath_phase - breath_lag * (1.0 - t));
	vec3 push = (dir + vec3(0.0, breath_lift, 0.0)) * (belly * breath * c * share / (1.0 + breath_lift));
	push.x += radial.x * breath_swell * breath_depth * c * share * belly;
	float crest = 0.5 + 0.5 * cos(TAU * (rest.z - breath_plate.y) / breath_plate.z);
	push.y += breath_plate.x * breath_depth * c * share * crest * smoothstep(0.3, 0.7, dir.y);
	return push;
}
