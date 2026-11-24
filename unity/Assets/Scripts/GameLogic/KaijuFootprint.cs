// Where the kaiju's body meets the ground, for the city's trample (scenes/kaiju_footprint.gd, D-065): read from the
// kaiju's own sculpt (assets/kaiju/<species>_<stage>.kvox), so it is right at every stage and species; the caller
// turns and scales it with the model (PropCrush.Under). Plain C# (System.Numerics) so SimTests/PropCrushCheck.cs
// checks it against Godot's KaijuFootprint.of. Presentation only.
using System;
using System.Text;
using N = System.Numerics;

namespace Kaiju.Game
{
    // Godot's Rect2: x across, y along the model's z.
    public struct FootRect
    {
        public N.Vector2 position, size;

        public FootRect(N.Vector2 position, N.Vector2 size)
        {
            this.position = position;
            this.size = size;
        }

        public N.Vector2 End => position + size;

        // Rect2.has_area.
        public bool HasArea => size.X > 0f && size.Y > 0f;

        // Rect2.has_point: the start edges in, the end edges out.
        public bool HasPoint(N.Vector2 p) =>
            p.X >= position.X && p.Y >= position.Y && p.X < position.X + size.X && p.Y < position.Y + size.Y;
    }

    public static class KaijuFootprint
    {
        // kaiju_footprint.gd _sculpt: the stages a model falls back through, as KaijuModel does.
        static readonly string[] STAGES = { "baby", "adolescent", "adult" };
        // _sculpt's empty bounds: lo starts this far out, hi as far the other way.
        const int FAR = 1 << 20;
        // Kvox.MAGIC; a voxel's bytes (x, y, z int16, r, g, b, face flags).
        const string MAGIC = "KVOX";
        const int VOXEL_BYTES = 10;

        // KaijuFootprint.of: the model's ground box in its own frame at scale 1, cut to the middle `share` of each
        // side (the splayed feet and the tail tip only reach its corners). `read` gives a repo file's bytes (null when
        // missing); `drawn` is the model's drawn bounds, asked for only when it has no sculpt (Godot's _drawn).
        public static FootRect Of(Func<string, byte[]> read, string species, long sizeTier, double share, Func<FootRect> drawn)
        {
            FootRect rect = Sculpt(read, species, TreeText.StageFor(sizeTier));
            if (!rect.HasArea) rect = drawn();
            return Cut(rect, share);
        }

        // of's cut: grow_individual by minus half the unshared size on every side.
        public static FootRect Cut(FootRect rect, double share)
        {
            N.Vector2 cut = rect.size * (float)(1.0 - share) * 0.5f;
            return new FootRect(rect.position + cut, rect.size - cut * 2f);
        }

        // _sculpt: the first sculpt from `stage` on that reads, its first pose's cells across x and z, sized as
        // KaijuRig sizes them (MODEL_HEIGHT tall). An empty rect when none reads.
        public static FootRect Sculpt(Func<string, byte[]> read, string species, string stage)
        {
            for (int i = Math.Max(0, Array.IndexOf(STAGES, stage)); i < STAGES.Length; i++)
            {
                if (!FirstPose(read($"assets/kaiju/{species}_{STAGES[i]}.kvox"), out int height, out byte[] buf, out int voxels))
                    continue;
                int loX = FAR, loZ = FAR, hiX = -FAR, hiZ = -FAR;
                for (int v = 0; v < voxels; v++)
                {
                    int x = BitConverter.ToInt16(buf, v * VOXEL_BYTES), z = BitConverter.ToInt16(buf, v * VOXEL_BYTES + 4);
                    loX = Math.Min(loX, x);
                    loZ = Math.Min(loZ, z);
                    hiX = Math.Max(hiX, x);
                    hiZ = Math.Max(hiZ, z);
                }
                double size = TreeText.MODEL_HEIGHT / height;
                return new FootRect(new N.Vector2((float)(loX * size), (float)(loZ * size)),
                    new N.Vector2((float)((hiX - loX + 1) * size), (float)((hiZ - loZ + 1) * size)));
            }
            return default;
        }

        // Kvox.read, the first pose only: false for a missing file, a wrong magic, a zero height or no poses.
        // Version 1 holds one pose (its voxel count before the height); later versions a pose count, each pose its own.
        static bool FirstPose(byte[] file, out int height, out byte[] voxels, out int count)
        {
            height = 0;
            voxels = Array.Empty<byte>();
            count = 0;
            if (file == null || file.Length < MAGIC.Length || Encoding.ASCII.GetString(file, 0, MAGIC.Length) != MAGIC)
                return false;
            int at = MAGIC.Length;
            uint version = BitConverter.ToUInt32(file, at);
            uint poses = version == 1 ? 1u : BitConverter.ToUInt32(file, at + 4);
            uint first = version == 1 ? BitConverter.ToUInt32(file, at + 4) : 0u;
            at += 8;
            height = BitConverter.ToUInt16(file, at);
            at += 2;
            if (height <= 0 || poses == 0) return false;
            long n = version == 1 ? first : BitConverter.ToUInt32(file, at);
            if (version != 1) at += 4;
            count = (int)Math.Min(n, (file.Length - at) / VOXEL_BYTES);
            voxels = new byte[count * VOXEL_BYTES];
            Array.Copy(file, at, voxels, 0, voxels.Length);
            return true;
        }
    }
}
