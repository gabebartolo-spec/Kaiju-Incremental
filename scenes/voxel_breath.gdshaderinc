// The breath (D-165, ClipIdle): the skin shaders push the back, shoulders and flanks out from the
// spine and up as he breathes in, and let them fall back, seen from behind where the camera sits.
// The cubes and the filler under them take the same push at the same place, so no gap opens and
// every cube keeps its size and square axes. `breath` is rig units (signed); breath_k holds each
// bone's share (the main bones weigh in by their skin weights); the underside barely moves.
uniform float breath = 0.0;
uniform float breath_lift = 0.5;
uniform float breath_belly = 0.2;
// The spine's axis, pelvis to the neck's base, in skin space (this frame's pose).
uniform vec3 breath_a = vec3(0.0);
uniform vec3 breath_b = vec3(0.0, 1.0, 0.0);
uniform float breath_k[128];

vec3 breath_push(vec3 p, float share) {
	vec3 ab = breath_b - breath_a;
	float t = clamp(dot(p - breath_a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	vec3 radial = p - (breath_a + ab * t);
	float r = length(radial);
	vec3 dir = r > 0.0001 ? radial / r : vec3(0.0, 1.0, 0.0);
	float belly = mix(breath_belly, 1.0, smoothstep(-0.4, 0.2, dir.y));
	return (dir + vec3(0.0, breath_lift, 0.0)) * belly * (breath * share);
}
