using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The rubble the city leaves: a low heap where a building is gone (scenes/ruin_yard.gd, Ruin.heap) and a pile
// along the street where a tower toppled (scenes/city_falls.gd land: Ruin.strip_plan, LandmarkRubble.pile).
// Godot builds voxel meshes; here the shapes are laid as grains on the debris heightfield (D-474), so they
// pile, slide and flatten under a foot with the rest of the debris. Reads sim events; decides nothing.
public sealed class RubbleView
{
    // scenes/ruin.gd heap and strip_plan: the materials a heap's and a strip's blocks take their colours from.
    static readonly string[] HeapKeys = { "wall", "wall", "wall", "wall", "pillar", "trim", "slab", "window" };
    static readonly string[] StripKeys = { "wall", "wall", "wall", "pillar", "trim", "slab", "window", "char" };
    // scenes/ruin.gd rubble_palette: the charred blocks' colour (2a2624).
    static readonly Color32 Char = new Color32(0x2a, 0x26, 0x24, 255);
    // A laid grain starts on the ground just short of still, so the debris step lands it on its column's top.
    const float SETTLE = -0.01f;
    const int HEAP_SALT = 0, STRIP_SALT = 101, PILE_SALT = 211;

    sealed class Job
    {
        public List<RubbleColumn> columns;
        public Color32[] colors;
        public double blockY;
        public int layer, top, at, salt;
    }

    readonly S.RampageSim sim;
    readonly Tuning tuning;
    readonly CityDraw city;
    readonly Debris debris;
    readonly RubbleCfg cfg;
    readonly Color32 grey;
    readonly HashSet<long> ruined = new HashSet<long>();
    readonly List<long> due = new List<long>();
    readonly List<Job> jobs = new List<Job>();
    long heaps, strips, grains;

    public long Heaps => heaps;
    public long Strips => strips;
    public long Grains => grains;

    public RubbleView(S.RampageSim sim, Tuning tuning, CityDraw city, Debris debris)
    {
        this.sim = sim;
        this.tuning = tuning;
        this.city = city;
        this.debris = debris;
        S.GDict topple = S.Content.Section("topple_fx");
        S.GArray<S.Variant> block = topple["rubble_block"];
        cfg = new RubbleCfg
        {
            cell = debris.GridCell,
            grain = Mathf.Max(0.001f, debris.GrainHeight),
            share = tuning.ruin_share,
            res = S.Num.F(S.Content.Section("destruction")["res"]),
            peakBase = tuning.ruin_peak_base,
            peakPerTier = tuning.ruin_peak_per_tier,
            spillCells = tuning.ruin_spill_cells,
            wobble = tuning.ruin_wobble,
            wobbleSwing = tuning.ruin_wobble_swing,
            wobbleJitter = tuning.ruin_wobble_jitter,
            fallPower = tuning.ruin_fall_power,
            heightJitter = tuning.ruin_height_jitter,
            stripHeight = tuning.ruin_strip_height,
            lump = S.Num.F(topple["rubble_lump"]),
            blockX = S.Num.F(block[0]),
            blockY = S.Num.F(block[1]),
            blockZ = S.Num.F(block[2]),
            pileBack = tuning.landmark_rubble_back,
            pileReach = tuning.landmark_rubble_reach,
            pileReachMax = tuning.landmark_rubble_reach_max,
            pilePeak = tuning.landmark_rubble_peak,
        };
        ColorUtility.TryParseHtmlString("#" + tuning.ruin_grey, out Color g);
        grey = g;
    }

    public void OnEvent(S.GDict e)
    {
        switch (S.Gd.Str(e["type"]))
        {
            case "chunks_broken":
            case "fall_start":
                Mark(S.Num.I(e["building"]));
                break;
            case "fall_land":
                Mark(S.Num.I(e["building"]));
                Landed(e);
                break;
            case "building_regrown":
                long index = S.Num.I(e["building"]);
                ruined.Remove(index);
                due.Remove(index);
                break;
        }
    }

    // scenes/ruin_yard.gd mark: a building with nothing left standing is due its heap, once.
    void Mark(long index)
    {
        if (index < 0 || index >= sim.buildings.Size() || ruined.Contains(index)) return;
        S.RampageSim.Building b = sim.buildings[index];
        if (b.frame == null || b.frame.aliveCount != 0) return;
        ruined.Add(index);
        due.Add(index);
    }

    // scenes/city_falls.gd land: a tower that toppled into the street leaves its length there as rubble. One
    // that came down on the kaiju or on a building leaves none, and neither does a landmark.
    void Landed(S.GDict e)
    {
        if (S.Gd.Str(e["kind"]) != "topple" || !e.Has("from") || e.Has("contact")) return;
        long index = S.Num.I(e["building"]);
        S.RampageSim.Building b = sim.buildings[index];
        if (b.landmark != "") return;
        S.Vector2 from = e["from"], to = e["to"];
        double width = S.Num.F(e["width"]);
        var columns = new List<RubbleColumn>();
        if (b.model != "")
        {
            RubbleShape.Pile(cfg, from.x, from.y, to.x, to.y, width, columns);
            Lay(columns, Colors(index, b, StripKeys, false), RubbleShape.HEAP_BLOCK_Y, PILE_SALT);
        }
        else
        {
            RubbleShape.Strip(cfg, from.x, from.y, to.x, to.y, width, columns);
            Lay(columns, Colors(index, b, StripKeys, true), cfg.blockY, STRIP_SALT);
        }
        strips++;
    }

    // Once a frame, before the debris steps: the heaps the kaiju has stepped off (scenes/ruin_yard.gd
    // _process), then one more layer of every shape being laid.
    public void Tick()
    {
        for (int k = due.Count - 1; k >= 0; k--)
        {
            long index = due[k];
            if (sim.body.Over(index)) continue;
            due.RemoveAt(k);
            S.RampageSim.Building b = sim.buildings[index];
            var columns = new List<RubbleColumn>();
            RubbleShape.Heap(cfg, b.x, b.z, b.w, b.d, b.tier, S.Seeds.Make("ruin", index), columns);
            int laid = Lay(columns, Colors(index, b, HeapKeys, true), RubbleShape.HEAP_BLOCK_Y, HEAP_SALT);
            heaps++;
            Debug.Log($"ruin {index} at {b.x:0.0},{b.z:0.0} columns {columns.Count} grains {laid}");
        }
        for (int k = jobs.Count - 1; k >= 0; k--)
            if (Layer(jobs[k])) jobs.RemoveAt(k);
    }

    int Lay(List<RubbleColumn> columns, Color32[] colors, double blockY, int salt)
    {
        int top = 0, total = 0;
        foreach (RubbleColumn c in columns)
        {
            top = Mathf.Max(top, c.grains);
            total += c.grains;
        }
        if (top > 0 && colors.Length > 0) jobs.Add(new Job { columns = columns, colors = colors, blockY = blockY, top = top, salt = salt });
        return total;
    }

    // One layer a frame: every grain lands on its column's top as the debris step finds it, so a shape
    // stacks true on whatever already lies there. A full batch stops the layer; it picks up next frame.
    // True when the shape is all laid.
    bool Layer(Job j)
    {
        for (; j.at < j.columns.Count; j.at++)
        {
            RubbleColumn c = j.columns[j.at];
            if (c.grains <= j.layer) continue;
            Color32 colour = j.colors[RubbleShape.Key(cfg, c, j.layer, j.blockY, j.salt, j.colors.Length)];
            var grain = new KcParticle
            {
                px = (float)c.x,
                py = 0f,
                pz = -(float)c.z,
                color = colour.r | ((uint)colour.g << 8) | ((uint)colour.b << 16) | 0xFF000000u,
                vx = 0f,
                vy = SETTLE,
                vz = 0f,
                seed = RubbleShape.Hash(j.at, j.layer, j.salt),
            };
            if (!debris.Add(grain)) return false;
            grains++;
        }
        j.at = 0;
        j.layer++;
        return j.layer >= j.top;
    }

    // The colours a shape's blocks take: a plain building's own materials by name, a model building's own
    // baked colours; greyed as scenes/ruin.gd rubble_palette does. The debris step dusts them as they land.
    Color32[] Colors(long index, S.RampageSim.Building b, string[] keys, bool greyed)
    {
        var list = new List<Color32>();
        if (b.model != "" || b.landmark != "") city.ModelColorsOf((int)index, tuning.landmark_rubble_colors, list);
        if (list.Count == 0)
        {
            foreach (string key in keys)
            {
                if (key == "char") list.Add(Char);
                else if (city.MaterialColor((int)index, key, out Color32 c)) list.Add(c);
                else list.Add(grey);
            }
        }
        var colors = list.ToArray();
        if (!greyed) return colors;
        for (int k = 0; k < colors.Length; k++)
            if (!colors[k].Equals(Char)) colors[k] = Color32.Lerp(colors[k], grey, tuning.ruin_grey_mix);
        return colors;
    }
}
