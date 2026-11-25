// A landmark section bursting where it stands on its break frame (scenes/landmark_burst.gd, D-078 rounds 4-5): its
// piece is gone at once and, on that frame, a cloud of dust covers the opening while a few hundred chunks of its own
// voxels, in its colours and two or three voxels across, fly outward from the landmark's middle and fall for a third
// of a second before they shrink away; a few real fragments go to the street's debris and one dust puff marks it.
// The section's samples are taken from its cells at the break as Godot's carve job takes them (scenes/carve_job.gd
// samples; director, 2026-11-25: "Carve-job rule", "Fix both"). Godot axes. Plain C# (System.Numerics) so
// SimTests/LandmarkBurstCheck.cs walks it against Godot's own output (golden/landmark_burst.txt). Presentation only:
// the sim never knows a burst happened.
using System;
using System.Collections.Generic;
using N = System.Numerics;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // One debris sample of a section: a cell's corner and its look's colour (carve_job.gd samples' {"pos", "color"}).
    public struct BurstPart
    {
        public N.Vector3 pos;
        public N.Vector4 color;
    }

    // One thrown chunk (landmark_burst.gd _throw: _from, _vel, its instance colour, _size).
    public struct BurstChunk
    {
        public N.Vector3 from, vel;
        public N.Vector4 color;
        public float size;
    }

    // One real fragment for the street's debris (CityView.debris's pos, color, away).
    public struct BurstFragment
    {
        public N.Vector3 pos, away;
        public N.Vector4 color;
    }

    // data/tuning.json "landmark_burst".
    public struct LandmarkBurstTuning
    {
        public int chunks, fragments, clouds;
        public float voxelsMin, voxelsMax, speedMin, speedMax, shade, dark, darkShare, cloudAlpha, cloudMax;
        // GDScript floats: a life ends on the frame Godot's summed clock reaches it, to the bit.
        public double chunkLife, cloudLife;

        public static LandmarkBurstTuning From(S.GDict cfg)
        {
            S.GArray<S.Variant> voxels = cfg["chunk_voxels"], speed = cfg["chunk_speed"];
            return new LandmarkBurstTuning
            {
                chunks = (int)S.Num.I(cfg["chunks"]),
                voxelsMin = (float)S.Num.F(voxels[0]),
                voxelsMax = (float)S.Num.F(voxels[1]),
                speedMin = (float)S.Num.F(speed[0]),
                speedMax = (float)S.Num.F(speed[1]),
                chunkLife = S.Num.F(cfg["chunk_life"]),
                shade = (float)S.Num.F(cfg["chunk_shade"]),
                dark = (float)S.Num.F(cfg["chunk_dark"]),
                darkShare = (float)S.Num.F(cfg["chunk_dark_share"]),
                fragments = (int)S.Num.I(cfg["fragments"]),
                clouds = (int)S.Num.I(cfg["clouds"]),
                cloudAlpha = (float)S.Num.F(cfg["cloud_alpha"]),
                cloudLife = S.Num.F(cfg["cloud_life"]),
                cloudMax = (float)S.Num.F(cfg["cloud_max"]),
            };
        }
    }

    // Everything one burst throws on its break frame, in Godot's order.
    public sealed class LandmarkBurstPlan
    {
        public readonly List<BurstChunk> chunks = new List<BurstChunk>();
        public readonly List<N.Vector3> clouds = new List<N.Vector3>();
        public float cloudSize;
        public readonly List<BurstFragment> fragments = new List<BurstFragment>();
        public N.Vector3 dustAt;
        public float dustSize;
    }

    public static class LandmarkBurst
    {
        // carve_job.gd SAMPLES (BuildingMesher.SAMPLES_PER_CHUNK) per CHUNK_CELLS (a structural chunk, 8 cells a side).
        public const int SAMPLES = 12;
        public const int CHUNK_CELLS = 512;
        // landmark_burst.gd SECONDS: a landed landmark section's shrink (retire), and the scale it shrinks to.
        public const float RETIRE_SECONDS = 0.15f;
        public const float RETIRE_SCALE = 0.01f;
        // GRAVITY: the chunks' fall.
        public const float GRAVITY = 20f;
        // DUST: the cloud's colour.
        public static readonly N.Vector3 DUST = new N.Vector3(0.62f, 0.61f, 0.58f);
        // BuildingVoxels.VOXEL: a chunk's cube before its size.
        public const float VOXEL = 0.125f;
        // _throw: a chunk's heading turns up to TURN either way off straight out, and it rises at RISE_MIN..RISE_MAX.
        const float TURN = 0.6f;
        const float RISE_MIN = 2f;
        const float RISE_MAX = 6f;
        // _draw_spray: a chunk tumbles about (1, 1, 0) at SPIN radians a second, offset by its number; it never goes
        // below FLOOR; it shrinks over the last SHRINK_SHARE of its life.
        static readonly N.Vector3 SPIN_AXIS = N.Vector3.Normalize(new N.Vector3(1f, 1f, 0f));
        const float SPIN = 8f;
        const float FLOOR = 0.1f;
        const float SHRINK_SHARE = 0.4f;
        // _cover: the cloud is CLOUD_SPAN of the section's wider side, at least CLOUD_MIN, times CLOUD_GROW.
        const float CLOUD_SPAN = 0.3f;
        const float CLOUD_MIN = 0.6f;
        const float CLOUD_GROW = 2.4f;
        // _draw_clouds: a puff swells from CLOUD_START to CLOUD_START + CLOUD_SWELL of its size.
        const float CLOUD_START = 0.8f;
        const float CLOUD_SWELL = 0.7f;
        // _init: a fragment leaves outward and FRAGMENT_RISE up; the dust is half the section's diagonal, DUST_MIN..
        // DUST_MAX.
        const float FRAGMENT_RISE = 0.5f;
        const float DUST_MIN = 1f;
        const float DUST_MAX = 4f;

        // carve_job.gd samples: SAMPLES per structural chunk's worth of the section's cells, spread evenly along
        // `index` (at least one), each at its cell's corner in its look's colour. Cell i of a w x d plan grid is
        // (i % w, i / (w d), (i / w) % d).
        public static List<BurstPart> Samples(IReadOnlyList<int> index, int w, int d, N.Vector3 origin, float voxel,
            Func<int, N.Vector4> look)
        {
            var parts = new List<BurstPart>();
            int n = index.Count;
            if (n == 0) return parts;
            int plan = w * d;
            int count = Math.Clamp((int)Math.Ceiling((float)n * SAMPLES / CHUNK_CELLS), 1, n);
            for (int j = 0; j < count; j++)
            {
                int i = index[(int)((long)j * n / count)];
                N.Vector3 c = new N.Vector3(i % w, i / plan, i / w % d);
                parts.Add(new BurstPart { pos = origin + c * voxel, color = look(i) });
            }
            return parts;
        }

        // _init, _throw and _cover: what a section's samples burst into. `middle` is the landmark's middle (x, z) and
        // `id` the fall event's, the seed of its draws.
        public static LandmarkBurstPlan Plan(IReadOnlyList<BurstPart> parts, N.Vector2 middle, long id,
            LandmarkBurstTuning tuning)
        {
            var plan = new LandmarkBurstPlan();
            if (parts.Count == 0) return plan;
            N.Vector3 lo = new N.Vector3(float.PositiveInfinity), hi = new N.Vector3(float.NegativeInfinity);
            foreach (BurstPart part in parts)
            {
                lo = N.Vector3.Min(lo, part.pos);
                hi = N.Vector3.Max(hi, part.pos);
            }
            var rng = new S.RandomNumberGenerator();
            rng.seed = id;
            Throw(parts, middle, rng, tuning, plan);
            Cover(lo, hi, rng, tuning, plan);
            int every = Math.Max(1, parts.Count / tuning.fragments);
            for (int n = 0; n < parts.Count; n += every)
            {
                BurstPart part = parts[n];
                N.Vector3 away = Normalized(Outward(part.pos, middle) + N.Vector3.UnitY * FRAGMENT_RISE);
                plan.fragments.Add(new BurstFragment { pos = part.pos, color = part.color, away = away });
            }
            plan.dustAt = (lo + hi) * 0.5f;
            plan.dustSize = Math.Clamp((hi - lo).Length() * 0.5f, DUST_MIN, DUST_MAX);
            return plan;
        }

        static void Throw(IReadOnlyList<BurstPart> parts, N.Vector2 middle, S.RandomNumberGenerator rng,
            LandmarkBurstTuning tuning, LandmarkBurstPlan plan)
        {
            int every = Math.Max(1, parts.Count / tuning.chunks);
            for (int n = 0; n < parts.Count; n += every)
            {
                BurstPart part = parts[n];
                N.Vector3 dir = Rotate(Outward(part.pos, middle), N.Vector3.UnitY, (float)rng.RandfRange(-TURN, TURN));
                N.Vector3 fling = dir * (float)rng.RandfRange(tuning.speedMin, tuning.speedMax);
                N.Vector3 vel = fling + N.Vector3.UnitY * (float)rng.RandfRange(RISE_MIN, RISE_MAX);
                bool dark = rng.Randf() < tuning.darkShare;
                float shade = dark ? tuning.dark : tuning.shade;
                N.Vector4 color = part.color * shade;
                color.W = 1f;
                float size = (float)rng.RandfRange(tuning.voxelsMin, tuning.voxelsMax);
                plan.chunks.Add(new BurstChunk { from = part.pos, vel = vel, color = color, size = size });
            }
        }

        static void Cover(N.Vector3 lo, N.Vector3 hi, S.RandomNumberGenerator rng, LandmarkBurstTuning tuning,
            LandmarkBurstPlan plan)
        {
            N.Vector3 span = hi - lo;
            plan.cloudSize = Math.Clamp(Math.Max(span.X, span.Z) * CLOUD_SPAN, CLOUD_MIN, tuning.cloudMax) * CLOUD_GROW;
            for (int n = 0; n < tuning.clouds; n++)
            {
                float x = (float)rng.RandfRange(lo.X, hi.X);
                float y = (float)rng.RandfRange(lo.Y, hi.Y);
                float z = (float)rng.RandfRange(lo.Z, hi.Z);
                plan.clouds.Add(new N.Vector3(x, y, z));
            }
        }

        // _process: the spray is gone once t reaches the chunks' life; before that it shrinks over the last part.
        public static bool SprayAlive(double t, LandmarkBurstTuning tuning) => t < tuning.chunkLife;

        public static float Shrink(double t, LandmarkBurstTuning tuning)
        {
            double life = tuning.chunkLife;
            double fade = (t - life * (1 - SHRINK_SHARE)) / (life * SHRINK_SHARE);
            return (float)(1.0 - Math.Clamp(fade, 0.0, 1.0));
        }

        // _draw_spray: chunk i's pose at t, as a Godot basis (columns x, y, z, already scaled) and origin.
        public static void SprayPose(BurstChunk chunk, int i, double t, float shrink, out N.Vector3 bx, out N.Vector3 by,
            out N.Vector3 bz, out N.Vector3 at)
        {
            float ft = (float)t;
            at = chunk.from + chunk.vel * ft + -N.Vector3.UnitY * (0.5f * GRAVITY * ft * ft);
            at.Y = Math.Max(at.Y, FLOOR);
            float s = chunk.size * shrink;
            AxisAngle(SPIN_AXIS, (float)(t * SPIN + i), out bx, out by, out bz);
            bx *= s;
            by *= s;
            bz *= s;
        }

        // _process: k is t over the cloud's life; the cloud is gone at k = 1.
        public static double CloudK(double t, LandmarkBurstTuning tuning) => t / tuning.cloudLife;

        // _draw_clouds: a puff's size and alpha at k.
        public static float CloudScale(float cloudSize, double k) => (float)(cloudSize * (CLOUD_START + CLOUD_SWELL * k));

        public static float CloudAlpha(LandmarkBurstTuning tuning, double k) => (float)(tuning.cloudAlpha * (1.0 - k * k));

        // _outward: flat, away from the landmark's middle; zero stays zero.
        static N.Vector3 Outward(N.Vector3 pos, N.Vector2 middle) => Normalized(new N.Vector3(pos.X - middle.X, 0f, pos.Z - middle.Y));

        static N.Vector3 Normalized(N.Vector3 v) => v.LengthSquared() > 0f ? N.Vector3.Normalize(v) : N.Vector3.Zero;

        // Vector3.rotated(axis, angle): Basis(axis, angle) times v.
        static N.Vector3 Rotate(N.Vector3 v, N.Vector3 axis, float angle)
        {
            AxisAngle(axis, angle, out N.Vector3 x, out N.Vector3 y, out N.Vector3 z);
            return x * v.X + y * v.Y + z * v.Z;
        }

        // Basis(axis, angle) (Godot's set_axis_angle), as its columns.
        static void AxisAngle(N.Vector3 a, float angle, out N.Vector3 x, out N.Vector3 y, out N.Vector3 z)
        {
            float cos = MathF.Cos(angle), sin = MathF.Sin(angle), t = 1f - cos;
            N.Vector3 sq = a * a;
            float r00 = sq.X + cos * (1f - sq.X), r11 = sq.Y + cos * (1f - sq.Y), r22 = sq.Z + cos * (1f - sq.Z);
            float xy = a.X * a.Y * t, xz = a.X * a.Z * t, yz = a.Y * a.Z * t;
            float r01 = xy - a.Z * sin, r10 = xy + a.Z * sin;
            float r02 = xz + a.Y * sin, r20 = xz - a.Y * sin;
            float r12 = yz - a.X * sin, r21 = yz + a.X * sin;
            x = new N.Vector3(r00, r10, r20);
            y = new N.Vector3(r01, r11, r21);
            z = new N.Vector3(r02, r12, r22);
        }
    }
}
