shader_type spatial;
// The stadium crowd (StadiumCrowd), all of it on the GPU: seated fans bob on their own beat;
// once the match panics (flee_t >= 0, seconds since) every fan is up (the standing mesh) and,
// after its own short delay, runs straight out from the middle and up the stands, facing out,
// and is gone (collapsed) past the rim's exits at normalised radius exit_r. Each fan's beat
// and delay come from its instance id with the same hash StadiumCrowd counts escapes with.

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
		vec2 dir = normalize(origin.xz - centre);
		float moved = speed * t;
		if (length((origin.xz + dir * moved - centre) / half_size) > exit_r) {
			VERTEX = vec3(0.0);
		} else {
			if (t > 0.0) {
				VERTEX.xz = -VERTEX.xz;  // turned to face out, the way they run
			}
			VERTEX.y += 0.06 * abs(sin((flee_t * 9.0 + h) * 3.14159));  // a panicked hop
			mat3 to_local = transpose(mat3(MODEL_MATRIX));
			VERTEX += to_local * vec3(dir.x * moved, moved * slope, dir.y * moved);
		}
	}
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
}
