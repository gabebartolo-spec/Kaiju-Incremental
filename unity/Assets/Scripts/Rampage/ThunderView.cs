using System;
using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The Thunder Beam on screen (scenes/thunder_beam.gd): the breath's bolt held for the beam's seconds, from the
// throat into the first standing facade on its line, re-struck on the stroke schedule while the head steers;
// its branches crawl up the wall from the impact. Reads the sim's events and state; decides nothing.
public sealed class ThunderView : IDisposable
{
    public int Beams { get; private set; }

    readonly S.RampageSim sim;
    readonly Croc croc;
    readonly int seed;
    readonly S.GDict row;
    readonly BoltRig rig;
    readonly float scale, along, up, jawSeconds;
    Vector3 end;
    S.Vector2 latched;
    bool hasLatch;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    static float At(S.GArray<S.Variant> a, int i) => (float)(double)S.Num.F(a[i]);

    public ThunderView(S.RampageSim sim, CityFx fx, Croc croc, int seed, float exposureUnit, float lightMatch, Action<Vector3> stroked)
    {
        this.sim = sim;
        this.croc = croc;
        this.seed = seed;
        S.GDict bolt = S.Content.Section("fx")["bolt"];
        row = bolt["thunder"];
        S.GArray<S.Variant> throat = bolt["throat"];
        along = At(throat, 0);
        up = At(throat, 1);
        S.GDict charge = bolt["charge"];
        jawSeconds = F(charge, "jaw_before");
        scale = (float)sim.BodyScale();
        rig = new BoltRig("thunder", Resources.Load<Shader>("Shaders/Bolt"), Resources.Load<Shader>("Shaders/Flare"), fx, scale, exposureUnit, lightMatch, bolt)
        {
            ends = LashTargets,
            stroked = stroked,
        };
    }

    public void OnEvent(S.GDict e, Vector3 kaijuAt)
    {
        string type = S.Gd.Str(e["type"]);
        if (type == "beam_start")
        {
            croc.JawOpen(true, jawSeconds);
            Beams++;
            hasLatch = false;
            Aim(kaijuAt);
            rig.Play(F(e, "seconds"), S.Seeds.Make("thunder_bolt", seed * BoltRig.SEEDS_PER_RUN + Beams));
            Debug.Log($"beam {Beams} at frame {Time.frameCount}: mouth {croc.ThroatAt(along, up)} hit {end}");
        }
        else if (type == "beam_end")
        {
            croc.JawOpen(false, jawSeconds);
            rig.Release();
        }
    }

    // After the pose for this frame: the bolt follows the jaw and the facing the sim steers.
    public void Step(Vector3 kaijuAt, float dt)
    {
        if (rig.Live) Aim(kaijuAt);
        rig.Step(dt);
        rig.Draw();
    }

    void Aim(Vector3 kaijuAt)
    {
        if (!hasLatch || sim.facing.AngleTo(latched) > F(row, "turn_hold"))
        {
            hasLatch = true;
            latched = sim.facing;  // the beam stays on one point of the facade until the player turns
            end = FacadeEnd(kaijuAt);
        }
        rig.Aim(croc.ThroatAt(along, up), end);
    }

    // Into the first standing facade on its line (end_height up it), else the sim's full range.
    Vector3 FacadeEnd(Vector3 kaijuAt)
    {
        float reach = (float)(double)S.Num.F(sim.powersCfg["beam_range"]) * scale;
        float best = reach;
        long top = -1;
        for (int i = 0; i < sim.buildings.Size(); i++)
        {
            S.RampageSim.Building b = sim.buildings[i];
            float t = Enter(b);
            if (t >= best) continue;
            long standing = Standing(b);
            if (standing <= 0) continue;
            best = t;
            top = standing;
        }
        if (top <= 0) return NearestFacade(kaijuAt, reach);
        float into = best + F(row, "into_wall") * scale;
        float fx = (float)(double)sim.facing.x, fz = (float)(double)sim.facing.y;
        return new Vector3(kaijuAt.x + fx * into, Mathf.Min(F(row, "end_height"), top), kaijuAt.z + fz * into);
    }

    // How tall (cells) a real building stands (not a kiosk, lamp or fence); else -1.
    long Standing(S.RampageSim.Building b)
    {
        S.GArray<S.Variant> least = row["facade_min"];
        double w = (double)b.w, d = (double)b.d;
        if (w < S.Num.I(least[0]) || d < S.Num.I(least[0])) return -1;
        long standing = b.frame.TopBelow((long)Math.Floor(w * 0.5), (long)Math.Floor(d * 0.5), (long)b.height);
        return standing >= S.Num.I(least[1]) ? standing : -1;
    }

    // With none on its line, the standing building the beam passes closest, at its near face.
    Vector3 NearestFacade(Vector3 kaijuAt, float reach)
    {
        float ax = (float)(double)sim.facing.x, az = (float)(double)sim.facing.y;
        float px = (float)(double)sim.kaijuPos.x, pz = (float)(double)sim.kaijuPos.y;
        float closest = float.PositiveInfinity;
        var o = new Vector3(kaijuAt.x + ax * reach, F(row, "street_height"), kaijuAt.z + az * reach);
        for (int i = 0; i < sim.buildings.Size(); i++)
        {
            S.RampageSim.Building b = sim.buildings[i];
            float bx = (float)(double)b.x, bz = (float)(double)b.z;
            float rx = bx - px, rz = bz - pz;
            float ahead = rx * ax + rz * az;
            long standing = Standing(b);
            if (standing <= 0 || ahead <= 0f || ahead > reach) continue;
            float off = Mathf.Abs(rx * az - rz * ax);
            if (off >= closest) continue;
            closest = off;
            float len = Mathf.Sqrt(rx * rx + rz * rz), half = Mathf.Max((float)(double)b.w, (float)(double)b.d) * 0.5f;
            o = new Vector3(bx - rx / len * half, Mathf.Min(F(row, "end_height"), standing), bz - rz / len * half);
        }
        return o;
    }

    // How far along the beam's line (from the kaiju) it meets the footprint; infinity if it does not.
    float Enter(S.RampageSim.Building b)
    {
        float dx = (float)(double)sim.facing.x, dz = (float)(double)sim.facing.y;
        float w = (float)(double)b.w, d = (float)(double)b.d;
        float loX = (float)(double)b.x - w * 0.5f - (float)(double)sim.kaijuPos.x;
        float loZ = (float)(double)b.z - d * 0.5f - (float)(double)sim.kaijuPos.y;
        float t0 = float.NegativeInfinity, t1 = float.PositiveInfinity;
        if (!Slab(dx, loX, loX + w, ref t0, ref t1) || !Slab(dz, loZ, loZ + d, ref t0, ref t1)) return float.PositiveInfinity;
        return t1 >= t0 && t0 > 0f ? t0 : float.PositiveInfinity;
    }

    static bool Slab(float dir, float lo, float hi, ref float t0, ref float t1)
    {
        if (Mathf.Abs(dir) < 0.000001f) return lo <= 0f && hi >= 0f;
        float a = lo / dir, b = hi / dir;
        t0 = Mathf.Max(t0, Mathf.Min(a, b));
        t1 = Mathf.Min(t1, Mathf.Max(a, b));
        return true;
    }

    // Points up the wall from where the beam lands, each a way to one side: the lashes on the facade.
    List<Vector3> LashTargets(S.RandomNumberGenerator rng, int count)
    {
        var side = new Vector3(-(float)(double)sim.facing.y, 0f, (float)(double)sim.facing.x);
        S.GArray<S.Variant> climb = row["lash_climb"];
        float lashSide = F(row, "lash_side");
        var o = new List<Vector3>(count);
        for (int i = 0; i < count; i++)
        {
            float rise = (float)rng.RandfRange(At(climb, 0), At(climb, 1)) * scale;
            float across = (float)rng.RandfRange(-1.0, 1.0) * lashSide * scale;
            o.Add(end + side * across + Vector3.up * rise);
        }
        return o;
    }

    public void Dispose() => rig.Dispose();
}
