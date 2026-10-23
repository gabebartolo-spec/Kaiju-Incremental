shader_type spatial;
// A window of a burning floor on the title's far shore (D-151: the burning floors' windows turn
// fire-orange): a pane that glows the fire's colour and flickers, brighter at its middle. Unlit.
// One MultiMesh draws every burning window (scenes/title_burning_windows.gd); each has its own
// flicker from where it stands.
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.36, 0.08);
uniform float glow = 1.6;
uniform float flicker_hz = 7.0;

varying float phase;

void vertex() {
	phase = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 6.2831;
}

void fragment() {
	float beat = sin(TIME * flicker_hz + phase) * sin(TIME * 2.3 + phase * 3.0);
	float middle = 1.0 - 0.45 * length((UV - 0.5) * 2.0);
	ALBEDO = colour * glow * (0.75 + 0.25 * beat) * clamp(middle, 0.4, 1.0) * COLOR.rgb;
}
