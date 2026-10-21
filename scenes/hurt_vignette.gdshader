shader_type canvas_item;
// The hurt vignette (R 15.3): red creeping in from the screen's edges. `width` is how far in
// (0 none, 1 to the centre), `alpha` its strength at the edge. Square-ish, like the broadcast
// frame, softened at the corners.

uniform vec4 tint : source_color = vec4(0.75, 0.08, 0.05, 1.0);
uniform float width = 0.0;
uniform float alpha = 0.0;

void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = mix(max(d.x, d.y), length(d) * 0.7071, 0.5);
	float t = smoothstep(1.0 - width, 1.0, edge);
	COLOR = vec4(tint.rgb, tint.a * alpha * t);
}
