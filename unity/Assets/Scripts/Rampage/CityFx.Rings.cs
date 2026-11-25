using UnityEngine;

// scenes/fx.gd ring_of: the shockwave's ring from `start` of its radius out, in `tint` (on the water: the intro's foam
// rings, RiverView). Godot axes.
public sealed partial class CityFx
{
    public void RingOf(Vector3 at, float radius, float start, Color tint) =>
        bursts.Ring(at + Vector3.up * RING_LIFT, radius * ringScale * RING_PLANE * 0.5f, start, ringSeconds, tint, ringAlpha, ringSoft, Now);
}
