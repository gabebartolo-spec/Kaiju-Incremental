// The kaiju's iron hide (scenes/kaiju_hide.gd, director 2026-11-03): one rigid capsule round him (FallContact.Hide,
// tuning fall_contact) that follows him every physics step, so debris fragments and broken building parts hit him,
// shatter and slide off, never pass through; no fragment is ever thrown from inside it (DebrisField keep_out). And
// what a falling part does when it reaches him or a standing neighbour on the way down (scenes/city_falls.gd
// _shatter): it breaks up where it is, its fragments thrown off what it hit, from outside his hide. Godot axes.
// Plain C# (System.Numerics) so SimTests/KaijuHideCheck.cs walks it against Godot's own output
// (golden/kaiju_hide.txt). Presentation only: the sim's own contact (FallContact) uses the same capsule.
using System;
using System.Collections.Generic;
using N = System.Numerics;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // The hide now: its foot and head centres and its radius (FallContact.Hide's [foot, head, radius]).
    public struct HideCapsule
    {
        public N.Vector3 foot, head;
        public float radius;
    }

    // A falling part's place (Godot's node.global_transform): world = origin + x*v.x + y*v.y + z*v.z.
    public struct PieceXf
    {
        public N.Vector3 x, y, z, origin;

        public N.Vector3 Apply(N.Vector3 v) => origin + x * v.X + y * v.Y + z * v.Z;
    }

    // What a part's break-up threw: the fragments in Godot's order and where the dust goes (the first one).
    public sealed class HideShatter
    {
        public readonly List<BurstFragment> fragments = new List<BurstFragment>();
        public N.Vector3 dust;
        public bool hasDust;
    }

    public static class KaijuHide
    {
        // kaiju_hide.gd:41 and fall_contact.gd:62: the floor under the axis' squared length.
        const float AXIS_FLOOR = 1e-6f;
        // kaiju_hide.gd:44: a point closer than this (squared) to the axis has no way out of its own.
        const float AWAY_FLOOR = 1e-6f;
        // city_falls.gd:9 DEBRIS_PER_LANDING: the most fragments one break-up throws.
        public const int DEBRIS_PER_LANDING = 160;
        // city_falls.gd:120: every fragment's lift.
        const float LIFT = 0.3f;
        // city_falls.gd:123: a fragment closer than this (squared) to his axis has no way off him of its own.
        const float OFF_FLOOR = 1e-6f;
        // city_falls.gd:134: the dust where the first fragment flies.
        public const float DUST = 1.5f;

        // FallContact.Hide's array as a capsule.
        public static HideCapsule Of(S.GArray<S.Variant> cap)
        {
            S.Vector3 a = cap[0], b = cap[1];
            return new HideCapsule { foot = V(a), head = V(b), radius = (float)S.Num.F(cap[2]) };
        }

        // kaiju_hide.gd:53-55 _follow: the collision capsule's height, end caps included, and where its middle sits.
        public static float Height(HideCapsule cap) => N.Vector3.Distance(cap.foot, cap.head) + 2f * cap.radius;

        public static N.Vector3 Centre(HideCapsule cap) => (cap.foot + cap.head) * 0.5f;

        // fall_contact.gd:59-63 hide_depth: how deep `p` is inside the capsule; <= 0 outside.
        public static float Depth(N.Vector3 p, HideCapsule cap) =>
            cap.radius - N.Vector3.Distance(p, OnAxis(p, cap));

        // kaiju_hide.gd:34-46 outside: `pos` moved clear of the hide (margin past its skin) when it lies inside or on
        // it; a point on the axis itself goes out along +x.
        public static N.Vector3 Outside(N.Vector3 pos, HideCapsule cap, float margin)
        {
            if (Depth(pos, cap) <= -margin) return pos;
            N.Vector3 on = OnAxis(pos, cap);
            N.Vector3 away = pos - on;
            if (away.LengthSquared() < AWAY_FLOOR) away = N.Vector3.UnitX;
            return on + N.Vector3.Normalize(away) * (cap.radius + margin);
        }

        // city_falls.gd:111-134 _shatter, up to the crush: up to DEBRIS_PER_LANDING samples of the part, picked at
        // random (repeats allowed), placed where the part is now (xf, about its pivot) and thrown up LIFT, and off his
        // axis when it was him it hit; each from outside his hide (`hide` null: there is none). The dust goes where
        // the first one flies.
        public static HideShatter Shatter(IReadOnlyList<BurstPart> parts, PieceXf xf, N.Vector3 pivot, bool onKaiju,
            N.Vector2 kaijuAt, HideCapsule? hide, float margin, S.RandomNumberGenerator rng)
        {
            var out_ = new HideShatter();
            var axis = new N.Vector3(kaijuAt.X, 0f, kaijuAt.Y);
            int n = Math.Min(parts.Count, DEBRIS_PER_LANDING);
            for (int k = 0; k < n; k++)
            {
                BurstPart part = parts[(int)rng.RandiRange(0, parts.Count - 1)];
                N.Vector3 at = xf.Apply(part.pos - pivot);
                N.Vector3 away = N.Vector3.UnitY * LIFT;
                if (onKaiju)
                {
                    N.Vector3 off = new N.Vector3(at.X, 0f, at.Z) - axis;
                    away += off.LengthSquared() > OFF_FLOOR ? N.Vector3.Normalize(off) : N.Vector3.UnitX;
                }
                if (hide.HasValue) at = Outside(at, hide.Value, margin);
                if (!out_.hasDust)
                {
                    out_.dust = at;
                    out_.hasDust = true;
                }
                out_.fragments.Add(new BurstFragment { pos = at, color = part.color, away = away });
            }
            return out_;
        }

        // The nearest point on the capsule's axis (clamped to its two centres).
        static N.Vector3 OnAxis(N.Vector3 p, HideCapsule cap)
        {
            N.Vector3 a = cap.foot, ab = cap.head - cap.foot;
            float t = Math.Clamp(N.Vector3.Dot(p - a, ab) / Math.Max(AXIS_FLOOR, ab.LengthSquared()), 0f, 1f);
            return a + ab * t;
        }

        static N.Vector3 V(S.Vector3 v) => new N.Vector3((float)v.x, (float)v.y, (float)v.z);
    }
}
