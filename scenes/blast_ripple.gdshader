shader_type canvas_item;
// The sonic boom you can see (BlastShock.ripple; director comments #20, "shockwaves and
// sonicboom"): when the boom reaches the camera, a thin ring of bent air runs out across the
// screen from where the blast is, pushing the city behind it outward, and is gone. `progress`
// 0..1 is driven from script; `width` is the ring's thickness and `strength` its push, both as
// shares of the screen height. No colour of its own: only the picture behind it moves.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float aspect = 1.7778;
uniform float progress = 0.0;
uniform float strength = 0.02;
uniform float width = 0.06;

void fragment() {
	vec2 d = (SCREEN_UV - centre) * vec2(aspect, 1.0);
	float r = length(d);
	float front = progress * 1.4;
	float x = (r - front) / width;
	float wave = exp(-x * x * 4.0) * x;  // a push then a pull across the ring
	float fade = (1.0 - progress) * (1.0 - progress);
	vec2 dir = r > 0.0001 ? d / r : vec2(0.0);
	vec2 push = dir * wave * strength * fade / vec2(aspect, 1.0);
	COLOR = vec4(textureLod(screen, SCREEN_UV - push, 0.0).rgb, 1.0);
}
