using System.Collections.Generic;
using Kaiju.Game;
using Unity.Collections;
using Unity.Collections.LowLevel.Unsafe;
using UnityEngine;
using N = System.Numerics;
using S = Kaiju.Sim;

// The body's bite (scenes/body_bite.gd, scenes/city_view.gd chunks_broken): chunks the kaiju's body breaks are torn
// off as one piece of the building's own voxels, the ones the blow carved (city_carve.gd bite), that tumbles out away
// from the kaiju and bursts into debris where it lands, every sample of it; the walls round the hole are chipped as
// for any blow (director, 2026-11-25: "Include it"). No collapse dust or fire. The maths is GameLogic/BodyBite.cs,
// checked against Godot by SimTests/BodyBiteCheck.cs; the chip and the spin draw on their own stream, as the blast
// break's do. The carve comes first in a frame's events (sim/carving.gd _finish: cells_carved, then the same
// building's chunks_broken), so Carved lifts the piece when the next event is that break under the body, and
// BiteTakes tears it off when the break arrives. The fall runs on the game's clock, as Godot's tween.
public sealed unsafe partial class CityDraw
{
    sealed class Bite
    {
        public FineBody body;
        public Transform hinge;
        // The piece's samples at rest (Godot axes), as Godot's carve job takes them.
        public List<BurstPart> parts;
        public BodyBiteTear tear;
        public double t;
    }

    // A piece lifted by its carve, waiting for its chunks_broken (the next event).
    readonly Dictionary<long, Bite> biteWaiting = new Dictionary<long, Bite>();
    readonly List<Bite> bites = new List<Bite>();
    S.RandomNumberGenerator biteRng;
    S.GArray<S.GDict> frameEvents;

    // RampageGame hands over each tick's events before fanning them out, so a carve can see the break after it.
    public void FrameEvents(S.GArray<S.GDict> events) => frameEvents = events;

    // The chunks_broken right after carve `e`, for its building (null: the carve broke no chunk).
    S.GDict BreakAfter(S.GDict e, long building)
    {
        if (frameEvents == null) return null;
        long n = frameEvents.Size();
        for (long k = 0; k + 1 < n; k++)
        {
            if (!ReferenceEquals(frameEvents[k], e)) continue;
            S.GDict next = frameEvents[k + 1];
            if (S.Gd.Str(next["type"]) == "chunks_broken" && S.Num.I(next["building"]) == building) return next;
            return null;
        }
        return null;
    }

    // city_carve.gd bite: the blow that breaks chunks under the body carves the piece itself. Its voxels leave the
    // fine body into a piece pivoting at the broken chunks' middle; they throw no carve debris (the landing does).
    bool BiteCarved(S.GDict e, long building, Site s, FineBody f, int[] raw, int n)
    {
        S.GDict broken = BreakAfter(e, building);
        if (broken == null || !sim.body.Over(building)) return false;
        var index = new List<int>(n);
        for (int k = 0; k < n; k++) index.Add(raw[k]);
        NativeArray<byte> palette = s.palette, looks = f.looks;
        List<BurstPart> parts = LandmarkBurst.Samples(index, f.w, f.d, new N.Vector3(f.origin.x, f.origin.y, f.origin.z), VOXEL,
            i => PaletteColor(palette, looks[i]));
        S.GArray<S.Vector3i> cells = broken["cells"];
        BlastSite site = BlastSiteOf(building);
        N.Vector3 mid = N.Vector3.Zero;
        for (int k = 0; k < cells.Size(); k++) mid += site.ChunkWorld(cells[k]);
        mid /= cells.Size();
        Bite bite = Lift(s, f, raw, n, new Vector3(mid.X, mid.Y, -mid.Z));
        bite.parts = parts;
        DropWaiting(building);
        biteWaiting[building] = bite;
        return true;
    }

    // The carved voxels move out of the fine body into a piece hinged at `at` (Unity axes), as FallStart's.
    Bite Lift(Site s, FineBody f, int[] raw, int n, Vector3 at)
    {
        int* lo = stackalloc int[3];
        int* hi = stackalloc int[3];
        fixed (int* ip = raw)
        {
            Native.kc_cells_bounds(ip, n, f.w, f.d, lo, hi);
            int nw = hi[0] - lo[0], nh = hi[1] - lo[1], nd = hi[2] - lo[2], size = nw * nh * nd;
            var pc = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.ClearMemory);
            var pd = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.ClearMemory);
            var pl = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.ClearMemory);
            Native.kc_cells_move(f.Cells, f.Drawn, f.Looks, ip, n, f.w, f.d, lo, nw, nd,
                (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(pc),
                (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(pd),
                (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(pl));
            for (int k = 0; k < n; k++) f.MarkCell(ip[k]);
            Transform hinge = Hinge("bite", at, out Transform holder);
            Vector3 origin = f.origin + new Vector3(lo[0], lo[1], lo[2]) * VOXEL;
            FineBody piece = Body("piece", nw, nh, nd, origin, f.mat, pc, pd, pl, s.palette, s.finish, 0, ABOVE_GROUND, 0, holder);
            piece.shown = true;
            piece.MarkAll();
            return new Bite { body = piece, hinge = hinge };
        }
    }

    // city_view.gd chunks_broken: chunks broken under the body are its bite's (EventFx then raises no collapse dust
    // and tries no blast break). body_bite.gd tear: the chip and the spin; the chipped edges fly at once.
    public bool BiteTakes(long index, S.GArray<S.Vector3i> cells)
    {
        if (!sim.body.Over(index))
        {
            DropWaiting(index);
            return false;
        }
        if (biteRng == null)
        {
            if (burstMaterial == null) BurstSetup();
            biteRng = S.Seeds.Make("body_bite");
        }
        BlastSite site = BlastSiteOf(index);
        var list = new List<S.Vector3i>((int)cells.Size());
        for (int k = 0; k < cells.Size(); k++)
        {
            list.Add(cells[k]);
            site.SetState(cells[k], 1f);  // Godot's view still shows them while it chips round them
        }
        var kaijuAt = new N.Vector3((float)(double)sim.kaijuPos.x, 0f, (float)(double)sim.kaijuPos.y);
        BodyBiteTear tear = BodyBite.Tear(site, list, kaijuAt, S.Num.F(sim.city["fall_gravity"]), biteRng);
        foreach (S.Vector3i c in list) site.SetState(c, 0f);  // then lifts them out
        foreach (BurstFragment f in tear.chipped)
            cityDebris.Spawn(V(f.pos), new Color(f.color.X, f.color.Y, f.color.Z, f.color.W), V(f.away));
        if (biteWaiting.TryGetValue(index, out Bite bite))
        {
            biteWaiting.Remove(index);
            bite.tear = tear;
            bites.Add(bite);
        }
        return true;
    }

    // A lifted piece whose break never came (none should): its voxels go, as the carve's would have.
    void DropWaiting(long building)
    {
        if (!biteWaiting.TryGetValue(building, out Bite bite)) return;
        biteWaiting.Remove(building);
        Free(bite.body);
        Object.Destroy(bite.hinge.gameObject);
    }

    // body_bite.gd's tween: the piece falls (quad ease-in) out to its landing spot, turning, then bursts into debris
    // there, every sample of it, and goes.
    void StepBites(float dt)
    {
        if (biteWaiting.Count > 0)
        {
            foreach (long n in new List<long>(biteWaiting.Keys))
            {
                Debug.LogWarning($"body bite: building {n} lifted a piece with no break after it");
                DropWaiting(n);
            }
        }
        for (int k = bites.Count - 1; k >= 0; k--)
        {
            Bite b = bites[k];
            b.t += dt;
            if (BodyBite.Landed(b.tear, b.t))
            {
                foreach (BurstFragment f in BodyBite.Landing(b.tear, b.parts))
                    cityDebris.Spawn(V(f.pos), new Color(f.color.X, f.color.Y, f.color.Z, f.color.W), V(f.away));
                Free(b.body);
                Object.Destroy(b.hinge.gameObject);
                bites.RemoveAt(k);
                continue;
            }
            N.Vector3 p = BodyBite.Position(b.tear, b.t);
            b.hinge.position = new Vector3(p.X, p.Y, -p.Z);
            b.hinge.rotation = MirroredEuler(BodyBite.Rotation(b.tear, b.t));
        }
    }

    // A Godot rotation (Euler radians, YXZ: Basis.from_euler) seen through the z mirror: the quaternion's x and y flip.
    static Quaternion MirroredEuler(N.Vector3 e)
    {
        N.Quaternion q = N.Quaternion.CreateFromAxisAngle(N.Vector3.UnitY, e.Y)
            * N.Quaternion.CreateFromAxisAngle(N.Vector3.UnitX, e.X)
            * N.Quaternion.CreateFromAxisAngle(N.Vector3.UnitZ, e.Z);
        return new Quaternion(-q.X, -q.Y, q.Z, q.W);
    }
}
