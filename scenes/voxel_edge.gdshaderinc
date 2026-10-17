// Voxel edge shading (director, 2026-10-18): each cube face tilts its normal near its rim like a
// bevel, so the edges facing a light catch it and the ones facing away fall dark, and a thin seam
// darkens the very rim. A block then reads as a solid cube, not a flat patch of colour. The face
// coordinate runs -1..1 across a face along the axes the meshers use (BuildingMesher,
// VoxelBuilder._face): u = cross(a, n), v = cross(n, u), a = up unless the face is level.
// The strengths come from the look (data/looks.json, Look.edge_params); 0 width turns it off.

uniform float edge_width = 0.0;
uniform float edge_bevel = 0.0;
uniform float edge_dark = 0.0;

varying vec2 edge_face;
varying vec3 edge_u;
varying vec3 edge_v;

vec3 edge_axis_a(vec3 n) {
	return abs(n.y) < 0.5 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
}

// The face coordinate of a centred cube's corner (a BoxMesh without subdivisions): every corner
// sits at plus or minus half the size on each axis, so its signs are its place on the face.
vec2 edge_box_face(vec3 vertex, vec3 n) {
	vec3 u = normalize(cross(edge_axis_a(n), n));
	vec3 v = cross(n, u);
	vec3 s = sign(vertex);
	return vec2(dot(s, u), dot(s, v));
}

// n: the face normal in model space; face: its -1..1 coordinate; to_view: model to view rotation.
void edge_vertex(vec3 n, vec2 face, mat3 to_view) {
	vec3 u = normalize(cross(edge_axis_a(n), n));
	edge_face = face;
	edge_u = normalize(to_view * u);
	edge_v = normalize(to_view * cross(n, u));
}

// Bends the view-space normal and darkens the albedo near the rim. Where the rim band would be
// thinner than about a pixel (a far or small voxel) it fades out instead of shimmering.
void edge_fragment(inout vec3 albedo, inout vec3 normal) {
	if (edge_width <= 0.0) {
		return;
	}
	vec2 f = abs(edge_face);
	float px = max(max(fwidth(edge_face.x), fwidth(edge_face.y)), 1e-5);
	float fade = smoothstep(0.75, 1.5, edge_width / px);
	vec2 rim = smoothstep(vec2(1.0 - edge_width), vec2(1.0), f);
	vec2 tilt = sign(edge_face) * rim * edge_bevel * fade;
	normal = normalize(normal + edge_u * tilt.x + edge_v * tilt.y);
	float seam = smoothstep(1.0 - edge_width * 0.3, 1.0, max(f.x, f.y));
	albedo *= 1.0 - edge_dark * seam * fade;
}
