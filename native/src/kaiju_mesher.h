#pragma once
// Native region mesher (WP4). Same algorithm, same bytes as scenes/cell_mesher.gd (the GDScript
// oracle tests/run_cell_mesh_tests.gd holds it to): one REGION^3 block of a building's fine grid
// to [vertices, normals, colours, indices], a face wherever a cell meets air (empty or off the
// grid; never the ground under local y = 0). Colour = palette[look] with Look.jitter's
// per-cell noise (Godot's hash of Vector4i(local cell, salt)). UV = (corner AO, finish class)
// as scenes/voxel_ao.gd (render plan item 12): the corner's level from the cells round the face's
// air cell (solid or ground shade it), the quad split along its brighter diagonal; the finish
// by look id from set_finish(). setup() and set_finish() once, then mesh_region() is
// read-only: safe to call from several WorkerThreadPool tasks at once.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
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
	PackedByteArray finish;
	Vector3 corners[6][4];
	// Per face direction, the 8 in-plane steps from its air cell (VoxelAO.ring_of's bit order).
	Vector3i ring[6][8];
	// Ring bits -> four 2-bit corner levels | 256 when the quad splits along corners 1-3.
	uint16_t ao_table[256];
	bool ready = false;

protected:
	static void _bind_methods();

public:
	// dims: grid size; offset: local cell of grid (0,0,0); origin: world centre of grid cell
	// (0,0,0); looks: per-cell palette index; palette: 256 sRGB colours.
	bool setup(const Vector3i &p_dims, const Vector3i &p_offset, const Vector3 &p_origin, float p_voxel,
			int64_t p_salt, double p_noise, const PackedByteArray &p_looks, const PackedColorArray &p_palette);
	// finish: look id (a cell's palette index) -> finish class, 256 entries.
	bool set_finish(const PackedByteArray &p_finish);
	Array mesh_region(const PackedByteArray &p_cells, const Vector3i &p_region) const;
	// Render plan item 9c (kaiju_surface.cpp): mesh_region's arrays packed as the surface
	// dictionary ArrayMesh._set_surfaces takes, the bytes RenderingServer packs for
	// CellMesher.to_mesh. Pure (no server call): safe on a worker. {} when it has no face.
	Dictionary pack_surface(const Array &p_arrays) const;
};

} // namespace godot
