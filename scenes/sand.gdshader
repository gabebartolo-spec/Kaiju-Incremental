shader_type spatial;
render_mode diffuse_lambert;
// The beach's sand (HarbourView.beach): grains a voxel each (nearest filtered), wet along the
// waterline (director 2026-10-31: "a thinnish strip of wet sand that gradually gets drier"). The
// vertex red is the metres up the sand from the waterline, over wet_width: the sand is darkest and
// glossiest at the water and dries across the strip. The lapping itself is the sim's water running
// up the sand (WaterView), not painted here (director 2026-10-31: the painted swash removed).

uniform sampler2D grains : source_color, filter_nearest_mipmap;
uniform float wet_width = 4.0;  // metres of wet sand up from the waterline
uniform float wet_dark = 0.5;  // the wettest sand's lightness (share of the dry sand's)
uniform float wet_rough = 0.3;  // the wettest sand's roughness (dry sand: 1)

varying float up;  // metres up the sand from the waterline

void vertex() {
	up = COLOR.r * wet_width;
}

void fragment() {
	// Wet sand: 1 at the waterline, drying to 0 at wet_width (eased, most of it near the water).
	float wet = 1.0 - smoothstep(0.0, wet_width, up);
	wet *= wet;
	ALBEDO = texture(grains, UV).rgb * mix(1.0, wet_dark, wet);
	ROUGHNESS = mix(1.0, wet_rough, wet);
}
