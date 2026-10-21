shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
// A blast's shell of bent air (BlastParts.haze; director comments #20, "shockwaves and
// sonicboom"): the city seen through the sphere's rim is pushed outward, strongest at the
// silhouette where the shell is seen edge-on, with a faint pale front, fading as `progress` runs
// from 0 to 1 while script swells the sphere. Reads the screen behind it (works in
// gl_compatibility too).

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float progress = 0.0;
uniform float strength = 0.035;
uniform float front = 0.12;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 3.0) * smoothstep(0.0, 0.2, facing);
	float fade = (1.0 - progress) * (1.0 - progress);
	vec2 push = NORMAL.xy * vec2(1.0, -1.0) * strength * rim * fade;
	vec3 behind = textureLod(screen, SCREEN_UV - push, 0.0).rgb;
	ALBEDO = behind + vec3(front * rim * fade);
	ALPHA = clamp(rim * fade * 2.5, 0.0, 1.0);
}
