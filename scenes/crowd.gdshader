shader_type spatial;
// The stadium crowd (StadiumCrowd), all of it on the GPU: seated fans bob on their own beat;
// once the match panics (flee_t >= 0, seconds since) every fan is up (the standing mesh) and,
// after its own delay, runs straight out from the middle and up the stands, facing out, to the
// back of the stands (normalised radius exit_r), where it steps down out of sight through the
// exit and is gone (collapsed) once `sink` below it: no fan pops out in view (director
// playtest, 2026-10-19). Each fan's beat and delay come from its instance id with the same
// hash StadiumCrowd places and counts them with (StadiumCrowd.running_at).

uniform float bob = 0.05;
uniform vec2 bob_hz = vec2(1.2, 2.4);
uniform float roughness_value = 0.9;
uniform float flee_t = -1.0;
uniform vec2 centre = vec2(0.0);
uniform vec2 half_size = vec2(1.0);
uniform float exit_r = 0.86;
uniform float speed = 3.0;
uniform float slope = 0.8;
uniform float delay = 0.5;
uniform float sink = 2.0;

// How far a fan at `rel` (from the middle) runs straight out to normalised radius exit_r.
float run_out(vec2 rel) {
	vec2 q = rel / half_size;
	vec2 d = normalize(rel) / half_size;
	float a = dot(d, d);
	float b = dot(q, d);
	float c = dot(q, q) - exit_r * exit_r;
	return max(0.0, (-b + sqrt(max(0.0, b * b - a * c))) / a);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	float h = fract(float(INSTANCE_ID) * 0.6180339887);
	if (flee_t < 0.0) {
		float hz = mix(bob_hz.x, bob_hz.y, h);
		VERTEX.y += bob * max(0.0, sin((TIME * hz + h) * 6.2831853));
	} else {
		float t = max(0.0, flee_t - h * delay);
		vec3 origin = MODEL_MATRIX[3].xyz;
		vec2 rel = origin.xz - centre;
		vec2 dir = normalize(rel);
		float moved = speed * t;
		float run = run_out(rel);
		float along = min(moved, run);
		float down = max(0.0, moved - run);
		if (down > sink) {
			VERTEX = vec3(0.0);
		} else {
			if (t > 0.0) {
				VERTEX.xz = -VERTEX.xz;  // turned to face out, the way they run
			}
			VERTEX.y += 0.06 * abs(sin((flee_t * 9.0 + h) * 3.14159));  // a panicked hop
			mat3 to_local = transpose(mat3(MODEL_MATRIX));
			VERTEX += to_local * vec3(dir.x * along, along * slope - down, dir.y * along);
		}
	}
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
}
