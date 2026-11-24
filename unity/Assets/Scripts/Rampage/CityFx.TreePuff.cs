using UnityEngine;

// scenes/fx.gd tree_puff and fx_particle_mats.gd tree(): a few soft clouds of the street's dust over a felled tree's
// stump that come up to `peak` in PUFF_RISE, hold, grow a little and are gone in under a second. Godot's quad has its
// centre clearing off, so clear is 0. Bursts draws no particle spin, so the material's ±60° is left out.
public sealed partial class CityFx
{
    const int TREE_PUFFS = 3;
    const float TREE_PUFF_SCALE = 2.4f, PUFF_RISE = 0.1f, PUFF_HOLD = 0.07f, PUFF_FADE = 0.35f;
    // tree_puff: the burst rises this share of its size above the stump, from a box this share of it across.
    const float TREE_PUFF_LIFT = 0.35f, TREE_PUFF_BOX = 0.2f, TREE_PUFF_DEPTH = 0.1f, TREE_PUFF_SMALL = 0.8f;
    // FxParticleMats.tree(): straight up within 40°, slow, drifting up; scale 0.6 to 1.4 over its life. _tree_mesh
    // is _puff(1.0).
    const float TREE_SPREAD = 40f, TREE_LIFT = 0.2f, TREE_VMIN = 0.2f, TREE_VMAX = 0.6f, TREE_GROW_FROM = 0.6f, TREE_GROW_TO = 1.4f;

    BurstStyle treePuff;

    public void TreePuff(Vector3 at, float size, float peak)
    {
        treePuff ??= new BurstStyle
        {
            spread = TREE_SPREAD, gravity = new Vector3(0f, TREE_LIFT, 0f), vmin = TREE_VMIN, vmax = TREE_VMAX, unit = 1f, clear = 0f,
        }.Size(0f, TREE_GROW_FROM, 1f, TREE_GROW_TO);
        treePuff.smin = size * TREE_PUFF_SMALL * TREE_PUFF_SCALE;
        treePuff.smax = size * TREE_PUFF_SCALE;
        float total = PUFF_RISE + PUFF_HOLD + PUFF_FADE;
        Color soil = dustLight, clear = new Color(soil.r, soil.g, soil.b, 0f), full = new Color(soil.r, soil.g, soil.b, peak);
        treePuff.Colors(new[] { 0f, PUFF_RISE / total, (PUFF_RISE + PUFF_HOLD) / total, 1f }, clear, full, full, clear);
        bursts.Spawn(treePuff, at + Vector3.up * size * TREE_PUFF_LIFT, new Vector3(size * TREE_PUFF_BOX, TREE_PUFF_DEPTH, size * TREE_PUFF_BOX),
            TREE_PUFFS, total, (1f - EXPLOSIVENESS) * total, Now, Seed());
    }
}
