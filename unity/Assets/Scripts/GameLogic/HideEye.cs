// Godot: scenes/kaiju_model.gd hide_cast and _near. A shot that lands within EYE_KEEP_OFF cubes of an eye (the
// species' eye colour, its ivory or its pupil) is an eye hit, which never takes a wound. Plain C#
// (System.Numerics), shared by Croc.HideCast and SimTests' HideHitCheck.
using System;
using System.Globalization;
using N = System.Numerics;

namespace Kaiju.Game
{
    public static class HideEye
    {
        public static readonly N.Vector3 IVORY = Hex("e8e0c8");
        public static readonly N.Vector3 PUPIL = Hex("15130f");
        // A wound stays this many cubes clear of an eye.
        public const int EYE_KEEP_OFF = 3;
        // _near: two colours this close (summed channel difference) count as the same.
        const float NEAR = 0.18f;
        // "rrggbb": six hex digits, a byte a channel.
        const int RED_SHIFT = 16, GREEN_SHIFT = 8, BYTE_MASK = 0xff;
        const float BYTE = 255f;

        // True when the hit's cube sits within EYE_KEEP_OFF cubes of an eye's colour on its bone.
        public static bool Is(SkinHits hits, in SkinHit hit, N.Vector3 eye)
        {
            return hits.AnyNear(hit.bone, hit.cell, EYE_KEEP_OFF, c => Near(c, eye) || Near(c, IVORY) || Near(c, PUPIL));
        }

        public static bool Near(N.Vector3 a, N.Vector3 b)
        {
            return Math.Abs(a.X - b.X) + Math.Abs(a.Y - b.Y) + Math.Abs(a.Z - b.Z) < NEAR;
        }

        // Godot's Color("rrggbb") (a leading # allowed), channels 0..1.
        public static N.Vector3 Hex(string hex)
        {
            string h = hex.TrimStart('#');
            int v = int.Parse(h.Substring(0, 6), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
            return new N.Vector3((v >> RED_SHIFT & BYTE_MASK) / BYTE, (v >> GREEN_SHIFT & BYTE_MASK) / BYTE, (v & BYTE_MASK) / BYTE);
        }
    }
}
