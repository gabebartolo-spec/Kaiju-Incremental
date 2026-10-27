// Render plan item 14 (tuning render_opt.kaiju_three_faces): a kaiju cube drawn as three faces,
// not six. Its mesh holds only the +X, +Y and +Z faces (ThreeFaceCube); each pass mirrors them, per
// cube, onto the three sides that face that pass's camera (the player's, or a light's when it draws
// shadows). The other three are back faces there, which the GPU would throw away after working out
// their corners. Exact: every face the camera can see is drawn, where the box would draw it.

// +1 when the axis points to the eye's side of the cube, else -1.
float three_faces_side(vec3 axis, vec3 to_eye) {
	return dot(axis, to_eye) < 0.0 ? -1.0 : 1.0;
}

// Mirrors one vertex of a three-face cube (local, its position in the cube's own axes; n, its
// normal) onto the eye's sides. centre: the cube's centre in the instance's space (where VERTEX
// lives); turn: the cube's axes there; modelview, projection: the pass's MODELVIEW_MATRIX and
// PROJECTION_MATRIX (an orthographic pass, a sun's shadow, looks along -Z everywhere).
void three_faces_mirror(inout vec3 local, inout vec3 n, vec3 centre, mat3 turn, mat4 modelview, mat4 projection) {
	vec3 eye = (modelview * vec4(centre, 1.0)).xyz;
	vec3 to_eye = projection[3][3] > 0.5 ? vec3(0.0, 0.0, 1.0) : -eye;
	mat3 axes = mat3(modelview) * turn;
	vec3 s = vec3(
			three_faces_side(axes[0], to_eye),
			three_faces_side(axes[1], to_eye),
			three_faces_side(axes[2], to_eye));
	local *= s;
	n *= s;
	if (s.x * s.y * s.z < 0.0) {
		// An odd number of mirrors turns a face inside out: one more inside its own plane keeps the
		// square where it is and its front facing out.
		if (abs(n.x) > 0.5) {
			local.y = -local.y;
		} else if (abs(n.y) > 0.5) {
			local.z = -local.z;
		} else {
			local.x = -local.x;
		}
	}
}
