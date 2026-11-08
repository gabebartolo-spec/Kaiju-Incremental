// No golden rampage fires a beam, so the DLL's beam_at is held to the sim's own loop instead:
// Carving._force_at's fallback over RampageSim.Beam.Reaches, column by column, bit for bit.
using System;
using Kaiju.Sim;

static class BeamCheck
{
    const int Cases = 200;

    public static int Run()
    {
        Random rng = new Random(1);
        KaijuSettle nat = new KaijuSettle();
        int differ = 0, columns = 0, hit = 0;
        for (int c = 0; c < Cases; c++)
        {
            int res = rng.Next(1, 5), w = rng.Next(4, 60), d = rng.Next(4, 60);
            int ox = rng.Next(-8, 9), oz = rng.Next(-8, 9);
            RampageSim.Building b = new RampageSim.Building
            {
                x = rng.NextDouble() * 400.0 - 200.0,
                z = rng.NextDouble() * 400.0 - 200.0,
                w = w / res + 1,
                d = d / res + 1,
            };
            double angle = rng.NextDouble() * 6.283185307179586;
            Vector2 origin = new Vector2(b.x + rng.NextDouble() * 40.0 - 20.0, b.z + rng.NextDouble() * 40.0 - 20.0);
            Vector2 dir = new Vector2(Math.Cos(angle), Math.Sin(angle));
            RampageSim.Beam beam = new RampageSim.Beam(origin, dir, rng.NextDouble() * 30.0, rng.NextDouble() * 6.0);

            PackedInt32Array spans = new PackedInt32Array();
            foreach (int v in new[] { 0, w, 0, d, 0 }) spans.Append(v);
            PackedInt32Array ints = new PackedInt32Array();
            foreach (int v in new[] { w, d, ox, oz, res }) ints.Append(v);
            PackedFloat64Array nums = new PackedFloat64Array();
            foreach (double v in new[] { b.x - b.w * 0.5, b.z - b.d * 0.5, origin.x, origin.y, dir.x, dir.y, beam.length, beam.half })
                nums.Append(v);
            PackedFloat32Array at = nat.Call("beam_at", spans, ints, nums);

            for (int gz = 0; gz < d; gz++)
                for (int gx = 0; gx < w; gx++)
                {
                    Vector3 local = new Vector3(gx + ox + 0.5, 0.0, gz + oz + 0.5) / res;
                    Vector3 p = b.LocalToWorld(local);
                    double k = beam.Reaches(new Vector2(p.x, p.z), 0.5 / res);
                    double got = at[gx + gz * w];
                    columns++;
                    if (k > 0.0) hit++;
                    if (got != Math.Max(0.0, k)) differ++;
                }
        }
        Console.WriteLine($"beam_at: {columns} columns, {hit} in the beam, {differ} differ from Beam.Reaches");
        // A check that never lands a beam on a column proves nothing.
        return differ + (hit == 0 ? 1 : 0);
    }
}
