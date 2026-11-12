// The light pool (Rampage/LightPool.cs, after scenes/light_pool.gd and pooled_light.gd; tests/lib/city_light_pool.gd)
// and the per-cell colour shade (Rampage/VoxelJitter.cs, after scenes/look.gd jitter_by) are plain maths, so they
// are held here: with more lights than the pool only the nearest pool_size are lit and the rest stay out (on), with
// fewer every light is lit (off); a light with no energy never takes a slot; a new light waits for the next pick;
// when the camera moves the dropped lights fade out before their replacements start, so never more than pool_size
// are drawn; the same lights give the same pick. The shade matches Godot's hash() for cells pinned from Godot
// 4.7.2, and is nothing at amount 0.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

static class LightPoolCheck
{
    const float Dt = 1f / 60f;
    const int Extra = 16, Row = 8;
    const float Spacing = 3f, FarAway = 500f;
    const double Noise = 0.08;
    const int Grey = 0xc8c8c8;

    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        GDict cfg = Content.Section("lights");
        float fade = (float)Num.F(cfg["fade_seconds"]), every = (float)Num.F(cfg["repick_seconds"]);
        int size = (int)Num.F(cfg["pool_size"]);

        // On: more lights than the pool, in a grid; the camera at the first corner.
        var pool = new LightPool();
        List<LightPool.Slot> lights = Grid(pool, size + Extra);
        Check(pool.size == size, $"the pool's size is the data's: {pool.size}");
        pool.Step(Dt, 0f, 0f, 0f);
        Check(Wanted(lights) == size, $"only pool_size lights are picked: {Wanted(lights)} of {lights.Count}");
        Check(lights[0].weight > 0f && lights[0].weight < 1f, $"a picked light fades in, not pops: {lights[0].weight}");
        Run(pool, fade + Dt, 0f);
        int lit = 0, dark = 0;
        float farthestLit = 0f, nearestDark = float.MaxValue;
        foreach (LightPool.Slot s in lights)
        {
            float d = (float)Math.Sqrt(s.x * s.x + s.z * s.z);
            if (s.weight >= 1f) { lit++; farthestLit = Math.Max(farthestLit, d); }
            else if (s.weight <= 0f) { dark++; nearestDark = Math.Min(nearestDark, d); }
        }
        Check(lit == size && dark == Extra, $"after the fade pool_size are fully lit and the rest out: {lit} lit, {dark} out");
        Check(farthestLit <= nearestDark, $"the lit ones are the nearest: farthest lit {farthestLit}, nearest out {nearestDark}");

        // The camera jumps to the far corner: the dropped lights fade first, never more than pool_size drawn.
        LightPool.Slot last = lights[lights.Count - 1];
        int most = 0;
        bool waited = true;
        for (float t = 0f; t < fade * 3f + every; t += Dt)
        {
            pool.Step(Dt, last.x, 0f, last.z);
            most = Math.Max(most, pool.Live());
            if (t < fade - Dt * 2f && last.wanted) waited = false;
        }
        Check(most <= size, $"never more than pool_size lights are drawn through a hand-over: {most}");
        Check(waited, "a replacement starts only once a dropped light has faded out");
        Check(last.weight >= 1f && lights[0].weight <= 0f, $"the far corner is lit and the first is out: {last.weight}, {lights[0].weight}");

        // No energy: never picked. A new light: out until the next pick.
        var few = new LightPool();
        LightPool.Slot off = few.Add();
        LightPool.Slot on = few.Add();
        on.energy = 1f;
        Run(few, fade + Dt, 0f);
        Check(!off.wanted && off.weight <= 0f, "a light with no energy never takes a slot");
        Check(on.weight >= 1f, "off: with fewer lights than the pool, every light with energy is lit");
        LightPool.Slot late = few.Add();
        late.energy = 1f;
        few.Step(Dt, 0f, 0f, 0f);
        Check(!late.wanted, "a new light is out until the next pick");
        Run(few, every + fade + Dt, 0f);
        Check(late.weight >= 1f, "and lit after it");
        few.Remove(late);
        Check(few.Count == 2, "a removed light leaves the pool");

        // Same lights, same pick.
        var again = new LightPool();
        List<LightPool.Slot> twins = Grid(again, size + Extra);
        Run(again, fade + Dt, 0f);
        var first = new LightPool();
        List<LightPool.Slot> firsts = Grid(first, size + Extra);
        Run(first, fade + Dt, 0f);
        bool same = true;
        for (int i = 0; i < twins.Count; i++) same &= twins[i].wanted == firsts[i].wanted && twins[i].weight == firsts[i].weight;
        Check(same, "the same lights give the same pick");

        // The shade, against Godot 4.7.2: hash(Vector4i(0, 10, -2, 34)) = 1813889686, (-3, 8, -1, 30) = 1537210239.
        Check(GodotHash.Vector4i(0, 10, -2, 34) == 1813889686U, "Godot's hash of a cell and salt");
        Check(VoxelJitter.Shade(Grey, 0, 10, -2, 34, Noise) == 0xcecece, $"a cell shaded lighter: {VoxelJitter.Shade(Grey, 0, 10, -2, 34, Noise):x}");
        Check(VoxelJitter.Shade(Grey, -3, 8, -1, 30, Noise) == 0xc0c0c0, $"a cell shaded darker: {VoxelJitter.Shade(Grey, -3, 8, -1, 30, Noise):x}");
        Check(VoxelJitter.Shade(Grey, 0, 10, -2, 34, 0.0) == Grey, "off: no noise, the paint as it is");
        Check(VoxelJitter.Shade(0xffffff, 0, 10, -2, 34, Noise) == 0xffffff, "white stays in range");

        Console.WriteLine(failed == 0
            ? $"light pool: {checks} checks, 0 failed (on: {lit} of {lights.Count} lit; off: all lit)"
            : $"light pool: {failed} failed");
        return failed;
    }

    static List<LightPool.Slot> Grid(LightPool pool, int count)
    {
        var lights = new List<LightPool.Slot>();
        for (int i = 0; i < count; i++)
        {
            LightPool.Slot s = pool.Add();
            s.x = i % Row * Spacing;
            s.z = i / Row * Spacing;
            s.energy = 1f;
            lights.Add(s);
        }
        return lights;
    }

    static void Run(LightPool pool, float seconds, float at)
    {
        for (float t = 0f; t < seconds; t += Dt) pool.Step(Dt, at, 0f, at);
    }

    static int Wanted(List<LightPool.Slot> lights)
    {
        int n = 0;
        foreach (LightPool.Slot s in lights)
            if (s.wanted) n++;
        return n;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL light pool: " + what);
    }
}
