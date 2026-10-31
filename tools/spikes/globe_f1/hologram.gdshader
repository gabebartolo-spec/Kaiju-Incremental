// Overworld F1 spike (throwaway): the hologram globe's look. Additive and unshaded, so it adds light over
// the near-black background: a fresnel rim from NORMAL and VIEW, scanlines scrolling up the sphere in model
// space, and a faint lat/long grid so the spin reads. Colours come from the script (UiKit, D-061).
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float rim_power = 2.6;
uniform float rim_strength = 1.4;
uniform float base_glow = 0.06;
uniform float scan_count = 90.0;  // lines over the sphere's height
uniform float scan_speed = 0.12;  // sphere heights per second
uniform float scan_strength = 0.35;
uniform float grid_lines = 12.0;  // meridians per half turn, parallels per pole-to-pole
uniform float grid_width = 0.035;
uniform float grid_strength = 0.18;

varying vec3 model_pos;

void vertex() {
	model_pos = VERTEX;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power) * rim_strength;
	float h = model_pos.y * 0.5 + 0.5;
	float scan = smoothstep(0.35, 0.5, fract(h * scan_count - TIME * scan_speed * scan_count)) * scan_strength;
	vec3 p = normalize(model_pos);
	float lon = atan(p.z, p.x) / 3.14159265 * grid_lines;
	float lat = acos(clamp(p.y, -1.0, 1.0)) / 3.14159265 * grid_lines;
	// distance to the nearest grid line, in grid cells
	float d = min(abs(fract(lon + 0.5) - 0.5), abs(fract(lat + 0.5) - 0.5));
	float grid = (1.0 - smoothstep(0.0, grid_width, d)) * grid_strength * facing;
	ALBEDO = tint.rgb * (base_glow + rim + scan * (0.3 + rim) + grid);
}
