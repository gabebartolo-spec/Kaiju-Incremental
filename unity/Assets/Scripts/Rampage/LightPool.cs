using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// scenes/light_pool.gd and pooled_light.gd: only the lights.pool_size lights nearest the camera are real; every other
// fire and police beacon is its glowing voxels alone. Re-picks on a timer or when the camera has moved
// lights.repick_distance, not every frame. The order is by distance, then by the order the lights joined, so a pick
// is the same every run. A light that drops out fades first; the one that replaces it starts only once a slot is
// free, so no more than pool_size lights are ever drawn. Each light fades in or out over lights.fade_seconds.
// Presentation only. No UnityEngine here: unity/SimTests compiles this file (LightPoolCheck).
public sealed class LightPool
{
    // pooled_light.gd: one light. Its owner sets where it is and the energy it wants, and shows energy * weight.
    public sealed class Slot
    {
        public float x, y, z, energy;
        // 0 (out) to 1 (fully lit); the pool moves `wanted`, this follows it.
        public float weight;
        public bool wanted;
        // Drawn at all (lit, or still fading out): what counts against the pool.
        public bool Live => wanted || weight > 0f;
    }

    // pooled_light.gd _process: the shortest fade.
    const float MIN_SECONDS = 0.001f;

    public readonly int size;
    readonly float every, moved, seconds;
    readonly List<Slot> all = new List<Slot>();
    readonly List<Slot> best = new List<Slot>();
    readonly List<float> dist = new List<float>();
    readonly HashSet<Slot> picked = new HashSet<Slot>();
    float clock, lastX, lastY, lastZ;
    bool placed;

    public int Count => all.Count;

    public LightPool()
    {
        S.GDict cfg = S.Content.Section("lights");
        size = (int)S.Num.F(cfg["pool_size"]);
        every = (float)S.Num.F(cfg["repick_seconds"]);
        moved = (float)S.Num.F(cfg["repick_distance"]);
        seconds = (float)S.Num.F(cfg["fade_seconds"]);
    }

    // A new light, out until the pool picks it (it joins after every light already there).
    public Slot Add()
    {
        var slot = new Slot();
        all.Add(slot);
        return slot;
    }

    public void Remove(Slot slot) => all.Remove(slot);

    public int Live()
    {
        int live = 0;
        foreach (Slot slot in all)
            if (slot.Live) live++;
        return live;
    }

    // Each frame, with the camera's place (light_pool.gd _process, then every light's own fade).
    public void Step(float dt, float cx, float cy, float cz)
    {
        clock += dt;
        if (!placed || clock >= every || Distance(lastX, lastY, lastZ, cx, cy, cz) >= moved)
        {
            clock = 0f;
            placed = true;
            lastX = cx;
            lastY = cy;
            lastZ = cz;
            Repick(cx, cy, cz);
        }
        float step = dt / Math.Max(seconds, MIN_SECONDS);
        foreach (Slot slot in all)
        {
            float to = slot.wanted ? 1f : 0f;
            slot.weight = slot.weight < to ? Math.Min(to, slot.weight + step) : Math.Max(to, slot.weight - step);
        }
    }

    static float Distance(float ax, float ay, float az, float bx, float by, float bz)
    {
        float x = ax - bx, y = ay - by, z = az - bz;
        return (float)Math.Sqrt(x * x + y * y + z * z);
    }

    // The lights nearest the camera, nearest first (energy-less lights never take a slot); ties go to the earlier.
    public List<Slot> Nearest(float cx, float cy, float cz)
    {
        best.Clear();
        dist.Clear();
        foreach (Slot slot in all)
        {
            if (slot.energy <= 0f) continue;
            float d = Distance(slot.x, slot.y, slot.z, cx, cy, cz);
            if (best.Count == size && d >= dist[size - 1]) continue;
            int at = dist.Count;
            while (at > 0 && dist[at - 1] > d) at--;  // after any equal distance: later lights sort after
            dist.Insert(at, d);
            best.Insert(at, slot);
            if (best.Count > size)
            {
                dist.RemoveAt(size);
                best.RemoveAt(size);
            }
        }
        return best;
    }

    public void Repick(float cx, float cy, float cz)
    {
        List<Slot> near = Nearest(cx, cy, cz);
        picked.Clear();
        foreach (Slot slot in near) picked.Add(slot);
        foreach (Slot slot in all)
            if (!picked.Contains(slot)) slot.wanted = false;
        int live = Live();
        foreach (Slot slot in near)
        {
            if (slot.wanted) continue;
            if (slot.Live) slot.wanted = true;  // still fading out: it holds its slot already
            else if (live < size)
            {
                slot.wanted = true;
                live++;
            }
        }
    }
}
