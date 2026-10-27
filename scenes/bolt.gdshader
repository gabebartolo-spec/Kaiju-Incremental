shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// The game's one beam shader (VFX_STYLE family 6): a bolt drawn as CAPSULES. BoltView gives every
// segment of every polyline its own camera-facing quad, four vertices a segment: VERTEX = this end of
// the segment, CUSTOM0.xyz = its other end, UV.x = 0 / 1 (the start / the far end), UV.y = the side
// (-1 / +1), CUSTOM1 = (width share, brightness share here, how far along the bolt here). The vertex
// stage stretches the quad half a width past both ends and the fragment stage measures the pixel's
// distance to the segment's axis (a capsule SDF), so joints and caps are round and no ribbon ever
// folds into a wedge when the camera looks down the bolt. Glow is NOT geometry: the colour is
// white-hot at the axis, a thin tinted fringe at the edge, HDR above the engine's glow threshold
// (data/looks.json), so the engine's own bloom is the halo. Blended by alpha (blend_mix), so
// capsules that overlap at a joint never add up into a bead. Gl_compatibility has no HDR, so `boost`
// simply clips there. `min_px` keeps the bolt from ever being thinner than that many pixels (at
// 1080p) whatever the distance.

uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.35, 1.0);
uniform vec4 fringe : source_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform vec4 core_colour : source_color = vec4(1.0, 0.97, 0.92, 1.0);
// Full width in world units where the width share is 1.
uniform float width = 1.0;
// 0..1 from script: the stroke's current brightness (a dim leader is orange, a stroke white-hot).
uniform float level = 1.0;
// HDR multiplier of the white-hot axis, and of the tint and fringe (the bloom catches both).
uniform float boost = 3.0;
uniform float fringe_boost = 1.6;
// Where across the capsule (0 axis, 1 edge) the white ends and the fringe begins.
uniform float white_to = 0.45;
uniform float tint_to = 0.7;
// The shallow brightness wobble between strokes (never a blackout): share of brightness lost, Hz.
uniform float wobble = 0.15;
uniform float wobble_hz = 22.0;
// The least width on screen, in pixels at 1080p.
uniform float min_px = 4.0;
// Share of the coverage kept (thin charge arcs are see-through so they never smear over the head).
uniform float alpha_scale = 1.0;
// Metres over which a bolt fades out against geometry in front of it (0: no fade).
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float soft = 0.0;

varying vec2 q;
varying float lw;
varying float wpx;
varying vec2 shade;

void vertex() {
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 o = (MODELVIEW_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
	p.z = min(p.z, -0.05);
	o.z = min(o.z, -0.05);
	float far_end = UV.x;
	float side = UV.y;
	float depth = max(-(p.z + o.z) * 0.5, 0.1);  // one radius for both ends
	float per_px = depth * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float share = CUSTOM1.x;
	float least = min_px * VIEWPORT_SIZE.y / 1080.0 * per_px * (0.7 + 0.3 * min(share, 1.0));
	float w = max(width * share, least) * 0.5;
	vec2 d = p.xy - o.xy;
	float len = length(d);
	vec2 out_dir = len > 0.0001 ? d / len : vec2(far_end > 0.5 ? 1.0 : -1.0, 0.0);
	vec2 perp = vec2(-out_dir.y, out_dir.x);
	vec3 vp = p;
	vp.xy += out_dir * w + perp * side * w;
	q = vec2(far_end > 0.5 ? len / w + 1.0 : -1.0, side);
	lw = len / w;
	wpx = w / per_px;
	shade = CUSTOM1.yz;
	POSITION = PROJECTION_MATRIX * vec4(vp, 1.0);
}

void fragment() {
	float x = clamp(q.x, 0.0, lw);
	float d = length(vec2(q.x - x, q.y));
	float cover = clamp((1.0 - d) / (1.5 / max(wpx, 1.0)), 0.0, 1.0);
	float hot = clamp((level - 0.25) / 0.5, 0.0, 1.0);
	float white = (1.0 - smoothstep(white_to * 0.6, white_to, d)) * hot;
	vec3 edge = mix(tint.rgb, fringe.rgb, smoothstep(tint_to, 1.0, d)) * fringe_boost;
	vec3 col = mix(edge, core_colour.rgb * boost, white);
	float flick = 1.0 - wobble * 0.5 * (1.0 + sin(TIME * wobble_hz * 6.2832 + shade.y * 37.0));
	float k = 1.0;
	if (soft > 0.0) {
		float depth = texture(depth_tex, SCREEN_UV).x;
		vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		k = clamp((-v.z / v.w + VERTEX.z) / soft, 0.0, 1.0);
	}
	ALBEDO = col * shade.x * flick * mix(0.6, 1.0, clamp(level, 0.0, 1.0));
	ALPHA = cover * smoothstep(0.0, 0.12, level) * alpha_scale * k;
}
