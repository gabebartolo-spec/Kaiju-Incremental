// Interleaved gradient noise: a cheap screen-space dither in [0, 1). The stream swap (StreamDissolve)
// crosses a stand-in box and a meshed building with it: the building is drawn where the dither is
// below its share, the box where it is at or below the rest, so the two fill the screen together.
float dither(vec2 at) {
	return fract(52.9829189 * fract(dot(at, vec2(0.06711056, 0.00583715))));
}
