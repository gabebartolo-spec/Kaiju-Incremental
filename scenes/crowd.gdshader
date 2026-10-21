shader_type spatial;
// The stadium crowd (StadiumCrowd), all of it on the GPU: seated fans bob on their own beat;
// once the match panics (flee_t >= 0, seconds since) every fan is up (the standing mesh) and,
// after its own delay, runs straight out from the middle and up the stands, facing out, to the
// back of the stands (normalised radius exit_r), where it steps down out of sight through the
// exit and is gone (collapsed) once `sink` below it: no fan pops out in view (director
// playtest, 2026-10-19). Each fan's beat and delay come from its instance id with the same
// hash StadiumCrowd places and counts them with (StadiumCrowd.running_at). A fan that dies (its
// stand went, or a blow) falls from where it is to the height StadiumCrowd gives it, goes over,
// lies there a while and shrinks away under the dust (custom data, set once when it dies).

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
uniform float clock = 0.0;
uniform float fall_g = 30.0;
uniform float shrink = 0.5;
uniform float topple = 0.25;

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
	// A fan whose stand has gone (or a blow has killed) carries its fall in its custom data:
	// x the crowd time it began (+1; 0 for none), y the flee time then (-1 before the panic),
	// z the height it lands at, w how long it lies there. It keeps the place it fell from.
	bool dying = INSTANCE_CUSTOM.x > 0.5;
	float ft = dying ? INSTANCE_CUSTOM.y : flee_t;
	vec3 local = VERTEX;
	vec3 off = vec3(0.0);  // in world axes: the model matrix only turns
	bool out_of_sight = false;
	if (ft < 0.0) {
		if (!dying) {
			float hz = mix(bob_hz.x, bob_hz.y, h);
			off.y = bob * max(0.0, sin((TIME * hz + h) * 6.2831853));
		}
	} else {
		float t = max(0.0, ft - h * delay);
		vec3 origin = MODEL_MATRIX[3].xyz;
		vec2 rel = origin.xz - centre;
		vec2 dir = normalize(rel);
		float moved = speed * t;
		float run = run_out(rel);
		float along = min(moved, run);
		float down = max(0.0, moved - run);
		if (down > sink) {
			out_of_sight = true;
		} else {
			if (t > 0.0) {
				local.xz = -local.xz;  // turned to face out, the way they run
			}
			off.y = 0.06 * abs(sin((ft * 9.0 + h) * 3.14159));  // a panicked hop
			off += vec3(dir.x * along, along * slope - down, dir.y * along);
		}
	}
	if (dying && !out_of_sight) {
		float dt = max(0.0, clock - (INSTANCE_CUSTOM.x - 1.0));
		float air = max(0.0, MODEL_MATRIX[3].y + off.y - INSTANCE_CUSTOM.z);
		float lie = sqrt(2.0 * air / fall_g) + topple;
		float a = clamp(dt / lie, 0.0, 1.0) * 1.5707963;  // goes over as it falls, flat on landing
		float side = h < 0.5 ? 1.0 : -1.0;  // on its back or on its face
		float c = cos(a);
		float s = sin(a) * side;
		local.yz = vec2(c * local.y - s * local.z, s * local.y + c * local.z);
		local.y += 0.15 * sin(a);
		local *= 1.0 - clamp((dt - lie - INSTANCE_CUSTOM.w) / shrink, 0.0, 1.0);  // gone under the dust
		off.y -= min(0.5 * fall_g * dt * dt, air);
	}
	VERTEX = out_of_sight ? vec3(0.0) : local + transpose(mat3(MODEL_MATRIX)) * off;
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
}
