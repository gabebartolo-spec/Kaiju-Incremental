// A building a red-barrel blast reaches blows apart rather than blinking out (scenes/blast_break.gd; motion critic
// 2026-10-21: "debris thrown outward and upward before the walls drop, walls breaking into voxels over 3-4 frames").
// A blast opens a short window (Blew); chunks the sim breaks within its reach in that window are this class's: they
// go top floor first in break.slices steps, one a frame, each step throwing debris out from the blast and up and
// puffing dust, and biting ragged edges into the chunks beside them (BuildingView.chip). The site's own skin flies
// first (scenes/blast_fx.gd _throw: Throw). A chunk's debris samples are taken from its voxels as Godot's carve job
// takes them, up to BuildingMesher's twelve a chunk (director, 2026-11-25: "Carve-job samples"); the scatter draws
// on its own stream ("Own stream is fine"). Godot axes. Plain C# (System.Numerics) so SimTests/BlastBreakCheck.cs
// walks it against Godot's own output (golden/blast_break.txt). Presentation only: the sim's chunks are already gone.
using System;
using System.Collections.Generic;
using N = System.Numerics;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // data/tuning.json "blast_fx": its "break" section, and the site throw's "debris" count.
    public struct BlastBreakTuning
    {
        public int slices, windowFrames, perChunk, debris;
        public float push, up;

        public static BlastBreakTuning From(S.GDict blastFx)
        {
            S.GDict cfg = blastFx["break"];
            return new BlastBreakTuning
            {
                slices = (int)S.Num.I(cfg["slices"]),
                windowFrames = (int)S.Num.I(cfg["window_frames"]),
                perChunk = (int)S.Num.I(cfg["per_chunk"]),
                push = (float)S.Num.F(cfg["push"]),
                up = (float)S.Num.F(cfg["up"]),
                debris = (int)S.Num.I(blastFx["debris"]),
            };
        }
    }

    // One building as the break sees it: its view's chunk states (BuildingView _get_state / _put_state: 1 standing,
    // BITTEN bitten, 0 hidden) and debris samples (_parts), and the sim building's box (RampageSim.Building).
    public interface IBlastSite
    {
        // is_instance_valid(view): false once the building's view is gone.
        bool Valid { get; }
        long W { get; }
        long D { get; }
        long Height { get; }
        bool Landmark { get; }
        float State(S.Vector3i chunk);
        void SetState(S.Vector3i chunk, float state);
        List<BurstPart> Parts(S.Vector3i chunk);
        N.Vector3 ChunkWorld(S.Vector3i chunk);
    }

    // One step of a break (blast_break.gd _break): the chunks it hid, the ones it bit, its debris for the city's
    // DebrisField (pos, color, away) and its dust puff (none when the step had no samples).
    public sealed class BlastBreakShot
    {
        public IBlastSite site;
        public List<S.Vector3i> cells, bitten;
        public readonly List<BurstFragment> debris = new List<BurstFragment>();
        public bool dust;
        public N.Vector3 dustAt;
        public float dustSize;
    }

    public sealed class BlastBreak
    {
        // building_view.gd:12-13 BITTEN, BITE_CHANCE: a chunk next to a hole keeps this share of its voxels, and this
        // share of the chunks next to a hole are bitten; :341 a chunk is bitten only while its state is above
        // BITTEN + BITE_MARGIN; :346 a third of the bitten chunks' samples fly.
        public const float BITTEN = 0.7f;
        const float BITE_CHANCE = 0.5f;
        const float BITE_MARGIN = 0.01f;
        const float BITE_SHARE = 3f;
        // building_mesher.gd:16-18 NEIGHBOURS (Vector3i LEFT, RIGHT, UP, DOWN, FORWARD, BACK).
        static readonly S.Vector3i[] NEIGHBOURS =
        {
            new S.Vector3i(-1, 0, 0), new S.Vector3i(1, 0, 0), new S.Vector3i(0, 1, 0),
            new S.Vector3i(0, -1, 0), new S.Vector3i(0, 0, -1), new S.Vector3i(0, 0, 1),
        };
        // building_mesher.gd:19 SAMPLES_PER_CHUNK: the most debris samples a chunk has.
        public const int SAMPLES = 12;
        // blast_break.gd:98: a piece flies out at push times PUSH_MIN..PUSH_MAX and up at up times UP_MIN..UP_MAX.
        const float PUSH_MIN = 0.6f;
        const float PUSH_MAX = 1.2f;
        const float UP_MIN = 0.5f;
        const float UP_MAX = 1.2f;
        // blast_break.gd:102: a step's dust puff is DUST_BASE plus DUST_PER_CHUNK a chunk.
        const double DUST_BASE = 0.5;
        const double DUST_PER_CHUNK = 0.05;
        // blast_fx.gd:231-234 _throw: a skin piece starts in the site's box (x, z in -1..1, y in 0..1 of its half
        // size from the centre) and rises at up times THROW_UP_MIN..THROW_UP_MAX.
        const float THROW_UP_MIN = 0.8f;
        const float THROW_UP_MAX = 1.4f;

        // A fresh blast (blast_break.gd _blasts): its origin on the ground, its reach, frames left.
        sealed class Fresh
        {
            public N.Vector3 origin;
            public double reach;
            public int left;
        }

        // A break still running (_queue): its site, the slices left, the blast's origin.
        sealed class Running
        {
            public IBlastSite site;
            public List<List<S.Vector3i>> slices;
            public N.Vector3 origin;
        }

        readonly BlastBreakTuning tuning;
        readonly S.RandomNumberGenerator rng;
        readonly List<Fresh> blasts = new List<Fresh>();
        readonly List<Running> queue = new List<Running>();

        public BlastBreak(BlastBreakTuning tuning, S.RandomNumberGenerator rng)
        {
            this.tuning = tuning;
            this.rng = rng;
        }

        // Fresh blasts and breaks still running (nothing to step when false).
        public bool Busy => blasts.Count > 0 || queue.Count > 0;

        // blew: a blast went off at `origin`; chunks broken within `reach` for the next few frames blow apart.
        public void Blew(N.Vector3 origin, double reach)
        {
            blasts.Add(new Fresh { origin = origin, reach = reach, left = tuning.windowFrames });
        }

        // takes' reach test: the first fresh blast whose reach holds the building's middle (x, z).
        public bool Covers(double x, double z, out N.Vector3 origin)
        {
            foreach (Fresh blast in blasts)
            {
                var flat = new N.Vector2((float)(x - blast.origin.X), (float)(z - blast.origin.Z));
                if (flat.Length() > blast.reach) continue;
                origin = blast.origin;
                return true;
            }
            origin = default;
            return false;
        }

        // takes: true when these broken chunks belong to a fresh blast; their first slice breaks now (into `shots`),
        // the rest one a frame (Process).
        public bool Takes(double x, double z, IReadOnlyList<S.Vector3i> cells, IBlastSite site, List<BlastBreakShot> shots)
        {
            if (!Covers(x, z, out N.Vector3 origin)) return false;
            List<List<S.Vector3i>> slices = Slices(cells, tuning.slices);
            List<S.Vector3i> first = slices[0];
            slices.RemoveAt(0);
            Shoot(site, first, origin, shots);
            if (slices.Count > 0) queue.Add(new Running { site = site, slices = slices, origin = origin });
            return true;
        }

        // _process: each fresh blast loses a frame (gone at none); each running break takes its next slice.
        public void Process(List<BlastBreakShot> shots)
        {
            foreach (Fresh blast in blasts) blast.left--;
            blasts.RemoveAll(blast => blast.left <= 0);
            foreach (Running item in queue)
            {
                List<S.Vector3i> next = item.slices[0];
                item.slices.RemoveAt(0);
                Shoot(item.site, next, item.origin, shots);
            }
            queue.RemoveAll(item => item.slices.Count == 0);
        }

        // _slices: the chunks top floor first (Godot's sort_custom), in `count` groups split at floor(n k / count)
        // (fewer when there are fewer chunks; an empty group is dropped).
        public static List<List<S.Vector3i>> Slices(IReadOnlyList<S.Vector3i> cells, int count)
        {
            int size = cells.Count;
            var sorted = new S.Vector3i[size];
            for (int i = 0; i < size; i++) sorted[i] = cells[i];
            S.GodotSort.Sort(sorted, size, (a, c) => a.y > c.y);
            int n = Math.Clamp(count, 1, Math.Max(1, size));
            var slices = new List<List<S.Vector3i>>();
            for (int k = 0; k < n; k++)
            {
                int lo = (int)Math.Floor(size * ((double)k / n));
                int hi = (int)Math.Floor(size * ((double)(k + 1) / n));
                var part = new List<S.Vector3i>();
                for (int i = lo; i < hi; i++) part.Add(sorted[i]);
                if (part.Count > 0) slices.Add(part);
            }
            return slices;
        }

        void Shoot(IBlastSite site, List<S.Vector3i> cells, N.Vector3 origin, List<BlastBreakShot> shots)
        {
            BlastBreakShot shot = Break(site, cells, origin);
            if (shot != null) shots.Add(shot);
        }

        // _break: these chunks go (hide_chunks, then chip), their samples thrown out from the blast and up; null when
        // the site's view is gone.
        BlastBreakShot Break(IBlastSite site, List<S.Vector3i> cells, N.Vector3 origin)
        {
            if (!site.Valid) return null;
            var parts = new List<BurstPart>();
            foreach (S.Vector3i c in cells) parts.AddRange(site.Parts(c));
            foreach (S.Vector3i c in cells) site.SetState(c, 0f);
            var shot = new BlastBreakShot { site = site, cells = cells, bitten = Chip(site, cells, parts, rng) };
            if (parts.Count == 0) return shot;
            int budget = Math.Min(parts.Count, cells.Count * tuning.perChunk);
            for (int n = 0; n < budget; n++)
            {
                BurstPart part = parts[(int)rng.RandiRange(0, parts.Count - 1)];
                N.Vector3 flat = Normalized(new N.Vector3(part.pos.X - origin.X, 0f, part.pos.Z - origin.Z));
                N.Vector3 push = flat * tuning.push * (float)rng.RandfRange(PUSH_MIN, PUSH_MAX);
                N.Vector3 away = push + N.Vector3.UnitY * tuning.up * (float)rng.RandfRange(UP_MIN, UP_MAX);
                shot.debris.Add(new BurstFragment { pos = part.pos, color = part.color, away = away });
            }
            shot.dust = true;
            shot.dustAt = site.ChunkWorld(cells[0]);
            shot.dustSize = (float)(DUST_BASE + cells.Count * DUST_PER_CHUNK);
            return shot;
        }

        // BuildingView.chip: some standing neighbours of the broken chunks are bitten (their state drops to BITTEN)
        // and a third of their samples join `parts`. Not for a landmark (no draws). The body's bite chips too (BodyBite).
        public static List<S.Vector3i> Chip(IBlastSite site, IReadOnlyList<S.Vector3i> broken, List<BurstPart> parts,
            S.RandomNumberGenerator rng)
        {
            var bitten = new List<S.Vector3i>();
            if (site.Landmark) return bitten;
            foreach (S.Vector3i c in broken)
            {
                foreach (S.Vector3i d in NEIGHBOURS)
                {
                    var n = new S.Vector3i(c.x + d.x, c.y + d.y, c.z + d.z);
                    if (Inside(site, n) && site.State(n) > BITTEN + BITE_MARGIN && rng.Randf() < BITE_CHANCE)
                    {
                        site.SetState(n, BITTEN);
                        bitten.Add(n);
                    }
                }
            }
            var chips = new List<BurstPart>();
            foreach (S.Vector3i c in bitten) chips.AddRange(site.Parts(c));
            int keep = (int)Math.Floor(chips.Count / BITE_SHARE);
            for (int k = 0; k < keep; k++) parts.Add(chips[k]);
            return bitten;
        }

        // building_view.gd:339: a chunk inside the building's box.
        static bool Inside(IBlastSite site, S.Vector3i n) =>
            n.x >= 0 && n.z >= 0 && n.y >= 0 && n.x < site.W && n.z < site.D && n.y < site.Height;

        // blast_fx.gd _throw: the site's skin thrown out of its whole box (centre, half size), outward and up, in its
        // kind's colours by turn: the first pieces off, before its broken floors follow.
        public static List<BurstFragment> Throw(N.Vector3 centre, N.Vector3 half, IReadOnlyList<N.Vector4> colours,
            BlastBreakTuning tuning, S.RandomNumberGenerator rng)
        {
            var pieces = new List<BurstFragment>();
            for (int n = 0; n < tuning.debris; n++)
            {
                float sx = (float)rng.RandfRange(-1, 1);
                float sy = (float)rng.Randf();
                float sz = (float)rng.RandfRange(-1, 1);
                var spot = new N.Vector3(sx, sy, sz);
                N.Vector3 flat = Normalized(new N.Vector3(spot.X, 0f, spot.Z));
                N.Vector3 rise = N.Vector3.UnitY * tuning.up * (float)rng.RandfRange(THROW_UP_MIN, THROW_UP_MAX);
                N.Vector3 away = flat * tuning.push + rise;
                pieces.Add(new BurstFragment { pos = centre + half * spot, color = colours[n % colours.Count], away = away });
            }
            return pieces;
        }

        // A chunk's debris samples (director, 2026-11-25: "Carve-job samples"): up to SAMPLES of its voxels, spread
        // evenly along `index` (cell i of a w x d plan grid is (i % w, i / (w d), (i / w) % d)), each at its cell's
        // corner in its look's colour (carve_job.gd samples).
        public static List<BurstPart> ChunkSamples(IReadOnlyList<int> index, int w, int d, N.Vector3 origin, float voxel,
            Func<int, N.Vector4> look)
        {
            var parts = new List<BurstPart>();
            int n = index.Count;
            if (n == 0) return parts;
            int plan = w * d;
            int count = Math.Min(SAMPLES, n);
            for (int j = 0; j < count; j++)
            {
                int i = index[(int)((long)j * n / count)];
                var c = new N.Vector3(i % w, i / plan, i / w % d);
                parts.Add(new BurstPart { pos = origin + c * voxel, color = look(i) });
            }
            return parts;
        }

        // Vector3.normalized: zero stays zero.
        static N.Vector3 Normalized(N.Vector3 v) => v.LengthSquared() > 0f ? N.Vector3.Normalize(v) : N.Vector3.Zero;
    }
}
