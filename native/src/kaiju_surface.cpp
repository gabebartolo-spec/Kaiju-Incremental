// Render plan item 9c: a region's mesh packed off the main thread. KaijuMesher.pack_surface turns
// mesh_region's arrays [vertices, normals, colours, indices, UVs] into the surface dictionary
// ArrayMesh._set_surfaces takes, so a worker can make the finished mesh (RenderingServer
// mesh_create_from_surfaces uploads it on the calling thread under a real renderer). The bytes
// mirror RenderingServer::mesh_create_surface_data_from_arrays (servers/rendering/
// rendering_server.cpp, Godot 4.7.2) for exactly CellMesher.to_mesh's arrays with no compression
// flag: the vertex stream is every position as float3, then per vertex the octahedral normal and
// the tangent Godot generates from it (2 x uint16 each); the attribute stream per vertex the colour
// as RGBA8 and the UV as float2; indices 16-bit up to 65536 vertices, else 32-bit; the AABB from the
// positions, each side at least CMP_EPSILON. tests/lib/remesh_worker.gd holds it to the engine's
// own packing byte for byte.
#include "kaiju_mesher.h"
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include <cstdint>
#include <cstring>

using namespace godot;

// Mesh array slots in mesh_region's order.
enum { IN_VERTEX, IN_NORMAL, IN_COLOR, IN_INDEX, IN_UV, IN_COUNT };
static const uint32_t POSITION_SIZE = 3 * sizeof(float);
// Octahedral normal then tangent, 2 x uint16 each.
static const uint32_t NORMAL_TANGENT_SIZE = 8;
// RGBA8 colour then float2 UV.
static const uint32_t ATTRIBUTE_SIZE = 4 + 2 * sizeof(float);
static const int64_t MAX_16BIT_VERTICES = 1 << 16;
static const float OCT_SCALE = 65535.0f;
static const double COLOR_SCALE = 255.0;

// (uint16_t)CLAMP(v * 65535, 0, 65535), as the engine writes an octahedral coordinate.
static inline uint16_t oct16(float p_v) {
	const float s = p_v * OCT_SCALE;
	return uint16_t(s < 0.0f ? 0.0f : (s > OCT_SCALE ? OCT_SCALE : s));
}

static inline uint8_t unorm8(float p_c) {
	const double s = p_c * COLOR_SCALE;
	return uint8_t(s < 0.0 ? 0.0 : (s > COLOR_SCALE ? COLOR_SCALE : s));
}

Dictionary KaijuMesher::pack_surface(const Array &p_arrays) const {
	Dictionary out;
	if (p_arrays.size() < IN_COUNT) {
		return out;
	}
	const PackedVector3Array verts = p_arrays[IN_VERTEX];
	const PackedVector3Array normals = p_arrays[IN_NORMAL];
	const PackedColorArray colors = p_arrays[IN_COLOR];
	const PackedInt32Array index = p_arrays[IN_INDEX];
	const PackedVector2Array uv = p_arrays[IN_UV];
	const int64_t n = verts.size();
	if (n == 0 || normals.size() != n || colors.size() != n || uv.size() != n || index.is_empty()) {
		return out;
	}
	const Vector3 *vp = verts.ptr();
	const Vector3 *np = normals.ptr();
	const Color *cp = colors.ptr();
	const Vector2 *up = uv.ptr();
	const int32_t *ip = index.ptr();

	PackedByteArray vertex_data;
	vertex_data.resize(n * (POSITION_SIZE + NORMAL_TANGENT_SIZE));
	uint8_t *vw = vertex_data.ptrw();
	uint8_t *nw = vw + n * POSITION_SIZE;
	Vector3 lo = vp[0];
	Vector3 hi = vp[0];
	for (int64_t i = 0; i < n; i++) {
		const float pos[3] = { float(vp[i].x), float(vp[i].y), float(vp[i].z) };
		memcpy(vw + i * POSITION_SIZE, pos, POSITION_SIZE);
		lo = lo.min(vp[i]);
		hi = hi.max(vp[i]);
		const Vector3 &nv = np[i];
		const Vector2 oct = nv.octahedron_encode();
		// The engine's tangent for a normal with no tangent array (sign +1), sanitised as it does.
		const Vector3 tan = Vector3(nv.z, -nv.x, nv.y).cross(nv.normalized()).normalized();
		const Vector2 toct = tan.octahedron_tangent_encode(1.0f);
		uint16_t nt[4] = { oct16(oct.x), oct16(oct.y), oct16(toct.x), oct16(toct.y) };
		if (nt[2] == 0 && nt[3] == 65535) {
			nt[2] = 65535;
		}
		memcpy(nw + i * NORMAL_TANGENT_SIZE, nt, NORMAL_TANGENT_SIZE);
	}

	PackedByteArray attribute_data;
	attribute_data.resize(n * ATTRIBUTE_SIZE);
	uint8_t *aw = attribute_data.ptrw();
	for (int64_t i = 0; i < n; i++) {
		const uint8_t c8[4] = { unorm8(cp[i].r), unorm8(cp[i].g), unorm8(cp[i].b), unorm8(cp[i].a) };
		const float t[2] = { float(up[i].x), float(up[i].y) };
		memcpy(aw + i * ATTRIBUTE_SIZE, c8, 4);
		memcpy(aw + i * ATTRIBUTE_SIZE + 4, t, 2 * sizeof(float));
	}

	const int64_t count = index.size();
	const bool wide = n > MAX_16BIT_VERTICES;
	PackedByteArray index_data;
	index_data.resize(count * (wide ? 4 : 2));
	uint8_t *iw = index_data.ptrw();
	for (int64_t i = 0; i < count; i++) {
		if (wide) {
			const uint32_t v = uint32_t(ip[i]);
			memcpy(iw + i * 4, &v, 4);
		} else {
			const uint16_t v = uint16_t(ip[i]);
			memcpy(iw + i * 2, &v, 2);
		}
	}

	const real_t eps = real_t(CMP_EPSILON);
	const AABB aabb(lo, (hi - lo).max(Vector3(eps, eps, eps)));
	const int64_t format = int64_t(Mesh::ARRAY_FORMAT_VERTEX | Mesh::ARRAY_FORMAT_NORMAL | Mesh::ARRAY_FORMAT_TANGENT |
									  Mesh::ARRAY_FORMAT_COLOR | Mesh::ARRAY_FORMAT_TEX_UV | Mesh::ARRAY_FORMAT_INDEX) |
			int64_t(RenderingServer::ARRAY_FLAG_FORMAT_CURRENT_VERSION);
	out["format"] = format;
	out["primitive"] = int64_t(Mesh::PRIMITIVE_TRIANGLES);
	out["vertex_data"] = vertex_data;
	out["vertex_count"] = n;
	out["attribute_data"] = attribute_data;
	out["index_data"] = index_data;
	out["index_count"] = count;
	out["aabb"] = aabb;
	out["uv_scale"] = Vector4();
	return out;
}
