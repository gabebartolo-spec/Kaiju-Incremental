// The camera rule shared by the smoke shader and the rain (director 2026-10-16, playtest
// 2026-10-19; D-018): what hangs between the camera and the kaiju thins out, so the kaiju reads.
// One function for every translucent weather and smoke family; each shader keeps its own
// uniforms and passes them in.

global uniform float smoke_focus;

// Opacity factor 0..1 for something `depth` metres in front of the camera at screen_uv.
// - Fully clear nearer than near_clear, full from near_full on.
// - Over the screen centre (radius in screen heights) only `keep` of it stays.
// - In front of the kaiju (view depth under focus_clear of the camera-to-kaiju depth) it is
//   cleared too; back at full strength from focus_full.
float view_clear(float depth, vec2 screen_uv, vec2 viewport, float near_clear, float near_full,
		float keep, float radius, float focus_clear, float focus_full) {
	float near = smoothstep(near_clear, near_full, depth);
	vec2 off = (screen_uv - 0.5) * vec2(viewport.x / viewport.y, 1.0);
	float centre = mix(keep, 1.0, smoothstep(radius * 0.4, radius, length(off)));
	float front = smoke_focus > 0.0
		? smoothstep(smoke_focus * focus_clear, smoke_focus * focus_full, depth) : 1.0;
	return near * centre * front;
}
