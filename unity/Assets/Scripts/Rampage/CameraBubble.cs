using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The camera bubble (D-283, D-326), scenes/camera_bubble.gd: a sphere round the camera cuts away the
// standing buildings it runs into, their shadows kept. Never cut, outside the core: a building in the
// kaiju's destruction field or a damaged one. Godot axes; the view's share is the clamped screen box of
// the building's corners, enough to order the few a sphere reaches.
public sealed class CameraBubble
{
    const float CELL = 32f;

    readonly S.RampageSim sim;
    readonly CityDraw city;
    readonly float size, core, seconds;
    readonly int most;
    readonly Dictionary<long, List<int>> grid = new Dictionary<long, List<int>>();
    readonly Dictionary<int, float> open = new Dictionary<int, float>();
    readonly List<int> near = new List<int>(), keys = new List<int>();
    readonly HashSet<int> seen = new HashSet<int>(), on = new HashSet<int>();
    readonly List<(float share, float gap, int n)> found = new List<(float, float, int)>();
    readonly Vector3[] corners = new Vector3[8];
    bool first = true;

    public int Open => open.Count;
    public IEnumerable<int> OpenNow => open.Keys;

    public CameraBubble(S.RampageSim simulation, CityDraw draw)
    {
        sim = simulation;
        city = draw;
        S.GDict c = S.Content.Section("camera");
        size = (float)S.Num.F(c["bubble_radius"]);
        core = (float)S.Num.F(c["bubble_core"]);
        seconds = (float)S.Num.F(c["bubble_seconds"]);
        most = (int)S.Num.I(c["bubble_max"]);
        Shader.SetGlobalFloat("_BubbleCore", core);
        for (int n = 0; n < sim.buildings.Size(); n++)
        {
            S.RampageSim.Building b = sim.buildings[n];
            float hw = (float)(double)b.w * 0.5f, hd = (float)(double)b.d * 0.5f, x = (float)(double)b.x, z = (float)(double)b.z;
            for (int cx = Mathf.FloorToInt((x - hw) / CELL); cx <= Mathf.FloorToInt((x + hw) / CELL); cx++)
                for (int cz = Mathf.FloorToInt((z - hd) / CELL); cz <= Mathf.FloorToInt((z + hd) / CELL); cz++)
                {
                    long key = Key(cx, cz);
                    if (!grid.TryGetValue(key, out List<int> list)) grid[key] = list = new List<int>();
                    list.Add(n);
                }
        }
    }

    static long Key(int x, int z) => ((long)x << 32) ^ (uint)z;

    float Field()
    {
        double bs = sim.BodyScale();
        double tail = (S.Num.F(sim.powersCfg["tail_reach"]) + sim.Stat("tail_reach")) * bs;
        return (float)System.Math.Max(System.Math.Max(sim.StompRadius(), sim.AbilityReach()), System.Math.Max(tail, sim.powers.sweep.Reach()));
    }

    static bool Damaged(S.RampageSim.Building b) => b.frame != null && b.frame.aliveCount < b.startChunks;

    static bool InField(S.RampageSim.Building b, Vector3 kaiju, float field)
    {
        float dx = (float)(double)b.x - kaiju.x, dz = (float)(double)b.z - kaiju.z;
        return Mathf.Sqrt(dx * dx + dz * dz) <= field + Mathf.Max((float)(double)b.w, (float)(double)b.d) * 0.5f;
    }

    static float Reach(Vector3 eye, S.RampageSim.Building b)
    {
        float hw = (float)(double)b.w * 0.5f, hd = (float)(double)b.d * 0.5f, x = (float)(double)b.x, z = (float)(double)b.z;
        var at = new Vector3(Mathf.Clamp(eye.x, x - hw, x + hw), Mathf.Clamp(eye.y, 0f, (float)(double)b.height), Mathf.Clamp(eye.z, z - hd, z + hd));
        return Vector3.Distance(eye, at);
    }

    float Share(Camera cam, S.RampageSim.Building b)
    {
        float hw = (float)(double)b.w * 0.5f, hd = (float)(double)b.d * 0.5f, x = (float)(double)b.x, z = (float)(double)b.z, h = (float)(double)b.height;
        for (int i = 0; i < 8; i++)
            corners[i] = new Vector3(x + ((i & 1) != 0 ? hw : -hw), (i & 2) != 0 ? h : 0f, -(z + ((i & 4) != 0 ? hd : -hd)));
        Vector3 e = cam.transform.position;
        if (e.x > x - hw && e.x < x + hw && -e.z > z - hd && -e.z < z + hd && e.y > 0f && e.y < h) return 1f;
        float lox = 1f, loy = 1f, hix = -1f, hiy = -1f;
        for (int i = 0; i < 8; i++)
        {
            Vector3 p = cam.WorldToViewportPoint(corners[i]);
            float vx = p.x * 2f - 1f, vy = p.y * 2f - 1f;
            if (p.z <= 0f)
            {
                vx = vx < 0f ? 1f : -1f;
                vy = vy < 0f ? 1f : -1f;
            }
            lox = Mathf.Min(lox, Mathf.Clamp(vx, -1f, 1f));
            hix = Mathf.Max(hix, Mathf.Clamp(vx, -1f, 1f));
            loy = Mathf.Min(loy, Mathf.Clamp(vy, -1f, 1f));
            hiy = Mathf.Max(hiy, Mathf.Clamp(vy, -1f, 1f));
        }
        return Mathf.Max(0f, hix - lox) * Mathf.Max(0f, hiy - loy) / 4f;
    }

    public void Step(Camera cam, Vector3 kaiju, float dt)
    {
        Vector3 w = cam.transform.position;
        var eye = new Vector3(w.x, w.y, -w.z);
        float field = Field();
        float flat = Mathf.Sqrt((eye.x - kaiju.x) * (eye.x - kaiju.x) + (eye.z - kaiju.z) * (eye.z - kaiju.z));
        float radius = Mathf.Max(Mathf.Clamp(flat - field, 0f, size), core);
        Shader.SetGlobalFloat("_BubbleRadius", radius);

        near.Clear();
        seen.Clear();
        for (int cx = Mathf.FloorToInt((eye.x - radius) / CELL); cx <= Mathf.FloorToInt((eye.x + radius) / CELL); cx++)
            for (int cz = Mathf.FloorToInt((eye.z - radius) / CELL); cz <= Mathf.FloorToInt((eye.z + radius) / CELL); cz++)
                if (grid.TryGetValue(Key(cx, cz), out List<int> list))
                    foreach (int n in list)
                        if (seen.Add(n)) near.Add(n);

        found.Clear();
        foreach (int n in near)
        {
            S.RampageSim.Building b = sim.buildings[n];
            float gap = Reach(eye, b);
            if (gap < core && b.frame != null && b.frame.aliveCount > 0) found.Add((float.NegativeInfinity, gap, n));
            else if (gap < radius && !Damaged(b) && !InField(b, kaiju, field)) found.Add((-Share(cam, b), gap, n));
        }
        found.Sort();
        on.Clear();
        for (int i = 0; i < found.Count && i < most; i++)
        {
            int n = found[i].n;
            on.Add(n);
            if (!open.ContainsKey(n)) open[n] = first ? 1f : 0f;
        }
        first = false;

        keys.Clear();
        keys.AddRange(open.Keys);
        foreach (int n in keys)
        {
            S.RampageSim.Building b = sim.buildings[n];
            float next = Mathf.MoveTowards(open[n], on.Contains(n) ? 1f : 0f, dt / seconds);
            if (Reach(eye, b) < core) next = 1f;
            else if (Damaged(b) || InField(b, kaiju, field)) next = 0f;
            city.SetCut(n, next);
            if (next <= 0f) open.Remove(n);
            else open[n] = next;
        }
    }
}
