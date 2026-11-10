using System;

// scenes/clip_leap.gd: which frame of the keyed leap the sim's dash is on. The sim owns the timing and the
// height (sim/game/dash.gd); the clip only poses the body. No engine types, so unity/SimTests runs it.
public static class LeapFrames
{
    // clip_leap.gd _init: the frame the feet leave the ground and the frame they are back on it, read from
    // each frame's planted bits (bit 0 left, bit 1 right), never hard-coded.
    public static void Air(byte[] planted, out int off, out int land)
    {
        int n = planted.Length;
        off = 0;
        while (off < n - 1 && planted[off] != 0) off++;
        land = off;
        while (land < n - 1 && planted[land] == 0) land++;
    }

    // clip_leap.gd frame: crouch plays up to take-off, flight spans the air, the settle and the recovery
    // share the rest by their seconds (settleShare = settle / (settle + recover)).
    public static double Frame(string phase, double t, double settleShare, int off, int land, int last)
    {
        t = Math.Min(1.0, Math.Max(0.0, t));
        double mid = Lerp(land, last, settleShare);
        switch (phase)
        {
            case "crouch": return Lerp(0.0, off, t);
            case "flight": return Lerp(off, land, t);
            case "settle": return Lerp(land, mid, t);
            default: return Lerp(mid, last, t);
        }
    }

    // clip_leap.gd grounded: the clip's own rise comes out of the hips, since the sim lifts the body.
    public static double Grounded(double offsetY, double restY) => offsetY - Math.Max(0.0, offsetY - restY);

    static double Lerp(double a, double b, double t) => a + (b - a) * t;
}
