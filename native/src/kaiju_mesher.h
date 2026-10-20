#pragma once
// Native region mesher (WP4). Same algorithm, same bytes as scenes/cell_mesher.gd (the GDScript
// oracle tests/run_cell_mesh_tests.gd holds it to): one REGION^3 block of a building's fine grid
// to [vertices, normals, colours, indices], a face wherever a cell meets air (empty or off the
// grid; never the ground under local y = 0). Colour = palette[look] with Look.jitter's
// per-cell noise (Godot's hash of Vector4i(local cell, salt)). setup() once, then mesh_region()
// is read-only: safe to call from several WorkerThreadPool tasks at once.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector3i.hpp>

namespace godot {

class KaijuMesher : public RefCounted {
	GDCLASS(KaijuMesher, RefCounted)

	Vector3i dims;
	Vector3i offset;
	Vector3 origin;
	float voxel = 0.125f;
	int64_t salt = 0;
	double noise = 0.0;
	PackedByteArray looks;
	PackedColorArray palette;
	Vector3 corners[6][4];
	bool ready = false;

protected:
	static void _bind_methods();

public:
	// dims: grid size; offset: local cell of grid (0,0,0); origin: world centre of grid cell
	// (0,0,0); looks: per-cell palette index; palette: 256 sRGB colours.
	bool setup(const Vector3i &p_dims, const Vector3i &p_offset, const Vector3 &p_origin, float p_voxel,
			int64_t p_salt, double p_noise, const PackedByteArray &p_looks, const PackedColorArray &p_palette);
	Array mesh_region(const PackedByteArray &p_cells, const Vector3i &p_region) const;
};

} // namespace godot
