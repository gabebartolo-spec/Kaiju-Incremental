using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using N = System.Numerics;
using S = Kaiju.Sim;

// A building a red-barrel blast reaches blows apart (scenes/blast_break.gd, scenes/city_view.gd chunks_broken): a
// blast opens a short window (Blew, from EventFx); chunks the sim breaks within its reach in that window go top floor
// first, one step a rendered frame, each step throwing debris out from the blast and up and puffing dust, and biting
// the chunks beside them (GameLogic/BlastBreak.cs, checked against Godot by SimTests/BlastBreakCheck.cs). The voxels
// still go at once (Carved), as Godot's carve does; the carve's own debris toward the street is skipped then, since
// Godot throws none there. A chunk's debris samples are up to twelve of the voxels its carve cut (director,
// 2026-11-25: "Carve-job samples"); a bitten chunk's, of the voxels it still has. The site's skin flies first
// (SiteThrow: blast_fx.gd _throw). Steps count rendered frames, as Godot's _process: slow-mo does not stretch them.
public sealed unsafe partial class CityDraw
{
    // A building as the break sees it: the chunk states Godot's view would hold (standing, bitten, hidden), its
    // samples from the fine body, and the voxels the blast's carve cut.
    sealed class BlastSite : IBlastSite
    {
        public Site s;
        public long n;
        public CityDraw owner;
        public readonly Dictionary<S.Vector3i, float> states = new Dictionary<S.Vector3i, float>();
        public readonly HashSet<int> cut = new HashSet<int>();

        public bool Valid => true;
        public long W => s.b.w;
        public long D => s.b.d;
        public long Height => s.b.height;
        public bool Landmark => s.b.landmark != "";

        // A chunk the break has not touched is as the sim has it.
        public float State(S.Vector3i c) => states.TryGetValue(c, out float v) ? v : s.b.frame.Alive(c) ? 1f : 0f;
        public void SetState(S.Vector3i c, float v) => states[c] = v;

        public N.Vector3 ChunkWorld(S.Vector3i c)
        {
            S.Vector3 v = s.b.ChunkWorld(c);
            return new N.Vector3((float)v.x, (float)v.y, (float)v.z);
        }

        // The chunk's voxels (Carving.Grid cx, cz, fy: the column and floor owning each), in index order: the ones
        // its carve cut when the sim has broken it, else the ones it still has.
        public List<BurstPart> Parts(S.Vector3i c)
        {
            FineBody f = s.fine;
            if (f == null) return new List<BurstPart>();
            S.Carving.Grid g = owner.sim.carving.grids[n];
            bool broken = !s.b.frame.Alive(c);
            byte* cells = f.Cells;
            var index = new List<int>();
            for (int y = 0; y < f.h; y++)
            {
                if (g.fy[y] != c.y) continue;
                for (int z = 0; z < f.d; z++)
                {
                    if (g.cz[z] != c.z) continue;
                    for (int x = 0; x < f.w; x++)
                    {
                        if (g.cx[x] != c.x) continue;
                        int i = x + z * f.w + y * f.w * f.d;
                        if (broken ? cut.Contains(i) : cells[i] != 0) index.Add(i);
                    }
                }
            }
            Unity.Collections.NativeArray<byte> palette = s.palette, looks = f.looks;
            return BlastBreak.ChunkSamples(index, f.w, f.d, new N.Vector3(f.origin.x, f.origin.y, f.origin.z), VOXEL,
                i => PaletteColor(palette, looks[i]));
        }

    }

    BlastBreak blastBreak;
    BlastBreakTuning blastTuning;
    S.RandomNumberGenerator blastRng;
    readonly Dictionary<long, BlastSite> blastSites = new Dictionary<long, BlastSite>();
    readonly List<BlastBreakShot> blastShots = new List<BlastBreakShot>();
    int blastFrame = -1;

    void BlastSetup()
    {
        if (burstMaterial == null) BurstSetup();
        blastTuning = BlastBreakTuning.From(S.Content.Section("blast_fx"));
        // Its own stream (director, 2026-11-25: "Own stream is fine"): Godot's draws on the city's.
        blastRng = S.Seeds.Make("blast_break");
        blastBreak = new BlastBreak(blastTuning, blastRng);
    }

    // blast_fx.gd _explode / _bomb: a blast went off at `at` (ground); what breaks within `reach` soon blows apart.
    public void Blew(Vector3 at, float reach)
    {
        if (blastBreak == null) BlastSetup();
        blastBreak.Blew(new N.Vector3(at.x, at.y, at.z), reach);
    }

    // city_view.gd chunks_broken: true when a fresh blast takes these chunks (EventFx then raises no collapse dust
    // and puts out no chunk fires, as Godot's return).
    public bool BlastTakes(long index, S.GArray<S.Vector3i> cells)
    {
        if (blastBreak == null) return false;
        Site s = sites[index];
        if (!blastBreak.Covers(s.b.x, s.b.z, out N.Vector3 _)) return false;
        BlastSite site = BlastSiteOf(index);
        var list = new List<S.Vector3i>((int)cells.Size());
        for (int k = 0; k < cells.Size(); k++)
        {
            list.Add(cells[k]);
            site.SetState(cells[k], 1f);  // Godot's view still shows them until their step
        }
        blastShots.Clear();
        blastBreak.Takes(s.b.x, s.b.z, list, site, blastShots);
        Shoot();
        return true;
    }

    // blast_fx.gd _throw: the site's skin out of its box (centre, half size: Godot axes) in its kind's colours.
    public void SiteThrow(string kind, Vector3 centre, Vector3 half)
    {
        if (blastBreak == null) BlastSetup();
        S.GDict colourOf = S.Content.Section("blast_fx")["debris_colors"];
        S.GArray<S.Variant> hexes = colourOf[kind];
        var colours = new List<N.Vector4>();
        for (int k = 0; k < hexes.Size(); k++)
        {
            ColorUtility.TryParseHtmlString("#" + S.Gd.Str(hexes[k]), out Color c);
            colours.Add(new N.Vector4(c.r, c.g, c.b, c.a));
        }
        foreach (BurstFragment f in BlastBreak.Throw(new N.Vector3(centre.x, centre.y, centre.z),
            new N.Vector3(half.x, half.y, half.z), colours, blastTuning, blastRng))
            cityDebris.Spawn(V(f.pos), new Color(f.color.X, f.color.Y, f.color.Z, f.color.W), V(f.away));
    }

    // Carved under a fresh blast: the cut voxels are the broken chunks' samples, and the carve throws no debris.
    bool BlastCarved(long building, int[] index, int n)
    {
        Site s = sites[building];
        if (blastBreak == null || !blastBreak.Covers(s.b.x, s.b.z, out N.Vector3 _)) return false;
        BlastSite site = BlastSiteOf(building);
        for (int k = 0; k < n; k++) site.cut.Add(index[k]);
        return true;
    }

    // blast_break.gd _process, once a rendered frame.
    void StepBlast()
    {
        if (blastBreak == null || Time.frameCount == blastFrame) return;
        blastFrame = Time.frameCount;
        if (!blastBreak.Busy)
        {
            foreach (BlastSite site in blastSites.Values) site.cut.Clear();
            return;
        }
        blastShots.Clear();
        blastBreak.Process(blastShots);
        Shoot();
    }

    void Shoot()
    {
        foreach (BlastBreakShot shot in blastShots)
        {
            foreach (BurstFragment f in shot.debris)
                cityDebris.Spawn(V(f.pos), new Color(f.color.X, f.color.Y, f.color.Z, f.color.W), V(f.away));
            if (shot.dust && crumbleFx != null) crumbleFx.Dust(V(shot.dustAt), shot.dustSize);
        }
    }

    BlastSite BlastSiteOf(long n)
    {
        if (!blastSites.TryGetValue(n, out BlastSite site))
            blastSites[n] = site = new BlastSite { s = sites[n], n = n, owner = this };
        return site;
    }
}
