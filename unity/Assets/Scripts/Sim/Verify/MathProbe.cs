using System;
using System.IO;

namespace Kaiju.Sim
{
    // TEMPORARY (U2 diagnosis): dumps math results as raw bits, one file per runtime.
    public static class MathProbe
    {
        public const int N = 200000;

        public static void Run(string path)
        {
            using var w = new BinaryWriter(File.Create(path));
            uint s = 12345u;
            double Next()
            {
                s = unchecked(s * 1664525u + 1013904223u);
                return s / 4294967296.0 * 4.0 * Math.PI - 2.0 * Math.PI;
            }
            for (int i = 0; i < N; i++)
            {
                double x = Next(), y = Next();
                float fx = (float)x, fy = (float)y;
                w.Write(MathF.Sin(fx));
                w.Write(MathF.Cos(fx));
                w.Write(MathF.Atan2(fy, fx));
                w.Write(Math.Sin(x));
                w.Write(Math.Cos(x));
                w.Write(Math.Atan2(y, x));
                w.Write(Math.Acos(x / 6.3));
                w.Write(Math.Pow(Math.Abs(x), y / 2.0));
                w.Write(Math.Exp(y));
                w.Write((float)Math.Sin((double)fx));
                w.Write((float)Math.Cos((double)fx));
                w.Write((float)Math.Atan2((double)fy, (double)fx));
            }
        }
    }
}
