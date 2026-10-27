// Shared by the building shaders (render plan item 12, looks R2 + R5): baked voxel AO and the
// material finish. The meshers (BuildingMesher, CellMesher, KaijuMesher) store per vertex
// UV = (ao, finish): ao is the corner's occlusion by the cells round it (VoxelAO: 0 a closed
// inside corner .. 1 open), finish its material's class (data/materials.json "finish": 0 rough,
// 1 glass, 2 metal). BuildingView sets the uniforms from the look (VoxelAO.apply); their defaults
// leave a surface exactly as it was (AO 1, no light affect, roughness_value, the engine's specular).

uniform float ao_strength = 0.0;
uniform float ao_light_affect = 0.0;
uniform bool finish_on = false;
uniform float finish_roughness[3];
uniform float finish_specular[3];

// The baked AO of this fragment, eased toward none by ao_strength.
float voxel_ao(vec2 uv) {
	return mix(1.0, uv.x, ao_strength);
}

// The finish class of this fragment's cell (constant over a face).
int voxel_finish(vec2 uv) {
	return clamp(int(uv.y + 0.5), 0, 2);
}
