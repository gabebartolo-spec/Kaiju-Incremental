// The body's bite (scenes/body_bite.gd, playtest note 2): the chunks the kaiju's body breaks are torn off as one piece
// that tumbles out away from the kaiju and bursts into debris where it lands, every sample of it, so a hole reads as
// torn open, never vanished; the walls round it are chipped as for any blow (BuildingView.chip, BlastBreak.Chip,
// director 2026-11-25: "Include it"). No dust cloud or fire. The chip and the spin draw on their own stream. Godot
// axes. Plain C# (System.Numerics) so SimTests/BodyBiteCheck.cs walks it against Godot's own output
// (golden/body_bite.txt). Presentation only: the sim's chunks are already gone.
using System;
using System.Collections.Generic;
using N = System.Numerics;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // One bite: where its piece starts and lands, how long it falls, how it turns, and the chipped edges' debris.
    public sealed class BodyBiteTear
    {
        public N.Vector3 mid, away, land, spin;
        public double seconds;
        public List<S.Vector3i> bitten;
        public readonly List<BurstFragment> chipped = new List<BurstFragment>();
    }

    public static class BodyBite
    {
        // body_bite.gd:11 THROW: how far out from the wall a torn piece lands (world units).
        public const float THROW = 1.2f;
        // body_bite.gd:13 MIN_DROP: the lowest a piece falls from, so a ground-floor bite still tumbles.
        public const float MIN_DROP = 0.4f;

        // body_bite.gd:16-37 tear, up to the tween: the piece's pivot is the cells' middle; the chip draws first, then
        // the spin; the piece lands THROW out from the wall away from the kaiju, at half MIN_DROP, after the time a
        // fall from its height (at least MIN_DROP) takes under the city's fall_gravity.
        public static BodyBiteTear Tear(IBlastSite site, IReadOnlyList<S.Vector3i> cells, N.Vector3 kaijuAt,
            double fallGravity, S.RandomNumberGenerator rng)
        {
            var tear = new BodyBiteTear();
            N.Vector3 mid = N.Vector3.Zero;
            foreach (S.Vector3i c in cells) mid += site.ChunkWorld(c);
            mid /= cells.Count;
            tear.mid = mid;
            var parts = new List<BurstPart>();
            tear.bitten = BlastBreak.Chip(site, cells, parts, rng);
            tear.away = Normalized(new N.Vector3(mid.X - kaijuAt.X, 0f, mid.Z - kaijuAt.Z));
            tear.land = new N.Vector3(mid.X, MIN_DROP * 0.5f, mid.Z) + tear.away * THROW;
            tear.seconds = Math.Sqrt(2.0 * Math.Max(MIN_DROP, (double)mid.Y) / fallGravity);
            tear.spin = new N.Vector3((float)rng.RandfRange(-1, 1), (float)rng.RandfRange(-1, 1),
                (float)rng.RandfRange(-1, 1));
            foreach (BurstPart p in parts)
                tear.chipped.Add(new BurstFragment { pos = p.pos, color = p.color, away = tear.away });
            return tear;
        }

        // body_bite.gd:38-40: the piece's position `t` seconds into its fall (TRANS_QUAD, EASE_IN from mid to land).
        public static N.Vector3 Position(BodyBiteTear tear, double t)
        {
            double k = Math.Min(1.0, t / tear.seconds);
            return tear.mid + (tear.land - tear.mid) * (float)(k * k);
        }

        // body_bite.gd:41: its rotation (Euler, radians), linear from none to the spin.
        public static N.Vector3 Rotation(BodyBiteTear tear, double t) =>
            tear.spin * (float)Math.Min(1.0, t / tear.seconds);

        // Whether the piece has landed `t` seconds in.
        public static bool Landed(BodyBiteTear tear, double t) => t >= tear.seconds;

        // body_bite.gd:42-50: where it lands, every sample of the piece (at rest, world) flies from its landed place.
        public static List<BurstFragment> Landing(BodyBiteTear tear, IReadOnlyList<BurstPart> piece)
        {
            var out_ = new List<BurstFragment>(piece.Count);
            N.Vector3 shift = tear.land - tear.mid;
            foreach (BurstPart p in piece)
                out_.Add(new BurstFragment { pos = p.pos + shift, color = p.color, away = tear.away });
            return out_;
        }

        // Vector3.normalized: zero stays zero (the kaiju right over the middle).
        static N.Vector3 Normalized(N.Vector3 v)
        {
            float len = v.Length();
            return len == 0f ? N.Vector3.Zero : v / len;
        }
    }
}
