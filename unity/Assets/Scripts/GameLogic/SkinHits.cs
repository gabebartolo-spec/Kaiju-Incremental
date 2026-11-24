// Where a shot meets the skinned croc, and the faint wounds it leaves (scenes/skin_hits.gd; director 2026-10-25:
// shot impacts must hit the hide, wounds stay as battle wear). The skin's cubes live on a regular grid in each bone's
// rest space (the vskin; a cube is filed under its first bone, as voxel_skin.gd add_cell); a ray is carried into
// every bone's rest space by that bone's current pose and walked through the grid (a 3D DDA), so the hit is on the
// cube actually drawn, at its true face normal, however the body is bent. A wound is a point in rest space, so it
// rides the bone and stays on the same scales through the walk. Godot axes throughout (the croc's own); plain C#
// (System.Numerics, row vectors: a point is Vector3.Transform(p, M)) so SimTests/HideHitCheck.cs walks it.
// Presentation only; no sim state.
using System;
using System.Collections.Generic;
using N = System.Numerics;

namespace Kaiju.Game
{
    public struct SkinHit
    {
        public float t;  // 0..1 along the segment
        public N.Vector3 point, normal;  // world
        public N.Vector3 rest;  // the hit in the bone's rest space (a wound's point)
        public N.Vector3 color;  // the cube's base colour
        public int bone;
        public (int x, int y, int z) cell;
    }

    public sealed class SkinHits
    {
        // Wound points the skin shader reads at most (tuning "fx" "hide_hit" "max_wounds" must not exceed).
        public const int SHADER_CAP = 48;
        // Longest DDA walk through one bone's grid.
        const int MAX_STEPS = 600;
        // A wound weaker than this is not drawn.
        public const float WOUND_FLOOR = 0.02f;
        const float PARALLEL = 1e-9f, ENTER = 1e-5f;
        // skin_hits.gd's voxel before setup; a grid bound no cell reaches; the shortest wound life age divides by.
        const float FIRST_VOXEL = 0.12f, SHORTEST_LIFE = 0.001f;
        const int FAR = 1 << 20;
        // voxel_skin.gd's .vskin: the header (bone count, voxel size, cell count at these bytes), then per cell
        // x y z as s16, the base colour's bytes, and the first bone.
        const int HEADER = 26, CELL_BYTES = 15, BONES_AT = 16, VOXEL_AT = 18, CELLS_AT = 22;
        const int Y_AT = 2, Z_AT = 4, RED_AT = 6, GREEN_AT = 7, BLUE_AT = 8, FIRST_BONE_AT = 10;
        const float BYTE = 255f;

        public float voxel = FIRST_VOXEL;
        readonly List<Dictionary<(int, int, int), N.Vector3>> cells = new List<Dictionary<(int, int, int), N.Vector3>>();
        readonly List<(int x, int y, int z)> lo = new List<(int, int, int)>(), hi = new List<(int, int, int)>();
        // Wounds: x y z in rest space, w strength 0..1 (a ring buffer; the oldest is replaced first).
        readonly N.Vector4[] wounds = new N.Vector4[SHADER_CAP];
        int next, max = SHADER_CAP;

        public N.Vector4[] Wounds => wounds;

        public void Setup(int boneCount, float voxelSize, int maxWounds)
        {
            voxel = voxelSize;
            max = Math.Max(1, Math.Min(maxWounds, SHADER_CAP));
            cells.Clear();
            lo.Clear();
            hi.Clear();
            for (int i = 0; i < boneCount; i++)
            {
                cells.Add(new Dictionary<(int, int, int), N.Vector3>());
                lo.Add((FAR, FAR, FAR));
                hi.Add((-FAR, -FAR, -FAR));
            }
            Array.Clear(wounds, 0, wounds.Length);
            next = 0;
        }

        // voxel_skin.gd attach, raw a gunzipped .vskin: hits.setup, then hits.add_cell for each cube under its
        // first bone (raw[at + 10]) in its base colour.
        public static SkinHits FromVskin(byte[] raw, int maxWounds)
        {
            var hits = new SkinHits();
            hits.Setup(BitConverter.ToUInt16(raw, BONES_AT), BitConverter.ToSingle(raw, VOXEL_AT), maxWounds);
            int count = BitConverter.ToInt32(raw, CELLS_AT);
            for (int i = 0; i < count; i++)
            {
                int k = HEADER + i * CELL_BYTES;
                var cell = (BitConverter.ToInt16(raw, k), BitConverter.ToInt16(raw, k + Y_AT), BitConverter.ToInt16(raw, k + Z_AT));
                hits.AddCell(raw[k + FIRST_BONE_AT], cell, new N.Vector3(raw[k + RED_AT] / BYTE, raw[k + GREEN_AT] / BYTE, raw[k + BLUE_AT] / BYTE));
            }
            return hits;
        }

        // The bones the hide was set up for.
        public int Bones => cells.Count;

        public void AddCell(int bone, (int x, int y, int z) cell, N.Vector3 color)
        {
            if (bone >= cells.Count) return;
            cells[bone][cell] = color;
            (int x, int y, int z) l = lo[bone], h = hi[bone];
            lo[bone] = (Math.Min(l.x, cell.x), Math.Min(l.y, cell.y), Math.Min(l.z, cell.z));
            hi[bone] = (Math.Max(h.x, cell.x + 1), Math.Max(h.y, cell.y + 1), Math.Max(h.z, cell.z + 1));
        }

        // The first cube a segment from -> to (world) meets, or false. `pose` is each bone's rest -> rig, `rigToWorld`
        // the rig's place in the world.
        public bool Cast(N.Matrix4x4[] pose, N.Matrix4x4 rigToWorld, N.Vector3 from, N.Vector3 to, out SkinHit best)
        {
            best = default;
            float bestT = float.PositiveInfinity;
            for (int b = 0; b < cells.Count && b < pose.Length; b++)
            {
                if (cells[b].Count == 0) continue;
                N.Matrix4x4 full = pose[b] * rigToWorld;
                if (!N.Matrix4x4.Invert(full, out N.Matrix4x4 inv)) continue;
                N.Vector3 o = N.Vector3.Transform(from, inv);
                N.Vector3 d = N.Vector3.TransformNormal(to - from, inv);
                if (!Walk(b, o, d, out SkinHit hit) || hit.t >= bestT) continue;
                bestT = hit.t;
                hit.point = N.Vector3.Lerp(from, to, hit.t);
                hit.normal = N.Vector3.Normalize(N.Vector3.TransformNormal(hit.normal, Orthonormal(full)));
                hit.bone = b;
                best = hit;
            }
            return bestT < float.PositiveInfinity;
        }

        // Walks one bone's grid. o, d in the bone's rest space (d spans the whole segment, t 0..1). Grid units: a cube
        // spans x, z in [c - 0.5, c + 0.5] voxels and y in [c, c + 1].
        bool Walk(int b, N.Vector3 o, N.Vector3 d, out SkinHit hit)
        {
            hit = default;
            var go = new N.Vector3(o.X / voxel + 0.5f, o.Y / voxel, o.Z / voxel + 0.5f);
            N.Vector3 gd = d / voxel;
            if (!ClipBox(b, go, gd, out float t0, out float t1, out int entryAxis)) return false;
            N.Vector3 start = go + gd * (t0 + ENTER);
            int[] cell = { (int)MathF.Floor(start.X), (int)MathF.Floor(start.Y), (int)MathF.Floor(start.Z) };
            int[] step = { Math.Sign(gd.X), Math.Sign(gd.Y), Math.Sign(gd.Z) };
            float[] g = { go.X, go.Y, go.Z }, dir = { gd.X, gd.Y, gd.Z };
            float[] edge = new float[3], delta = new float[3];
            for (int a = 0; a < 3; a++)
            {
                edge[a] = step[a] == 0 ? float.PositiveInfinity : (cell[a] + (step[a] > 0 ? 1 : 0) - g[a]) / dir[a];
                delta[a] = step[a] == 0 ? float.PositiveInfinity : 1f / MathF.Abs(dir[a]);
            }
            float t = t0;
            N.Vector3 normal = EntryNormal(entryAxis, dir);
            for (int i = 0; i < MAX_STEPS; i++)
            {
                if (cells[b].TryGetValue((cell[0], cell[1], cell[2]), out N.Vector3 color))
                {
                    hit = MakeHit(go + gd * t, t, normal == N.Vector3.Zero ? -N.Vector3.Normalize(d) : normal, color, cell);
                    return true;
                }
                int axis = edge[1] < edge[0] ? 1 : 0;
                if (edge[2] < edge[axis]) axis = 2;
                t = edge[axis];
                if (t > t1) return false;
                edge[axis] += delta[axis];
                cell[axis] += step[axis];
                normal = StepNormal(axis, step);
            }
            return false;
        }

        // The hit at grid point `at`: its rest-space point (a wound's centre) and the cube it struck.
        SkinHit MakeHit(N.Vector3 at, float t, N.Vector3 normal, N.Vector3 color, int[] cell) => new SkinHit
        {
            t = t,
            normal = normal,
            rest = new N.Vector3((at.X - 0.5f) * voxel, at.Y * voxel, (at.Z - 0.5f) * voxel),
            color = color,
            cell = (cell[0], cell[1], cell[2]),
        };

        // The face normal after stepping across a cell edge on `axis`: it points back against the step.
        static N.Vector3 StepNormal(int axis, int[] step)
        {
            N.Vector3 n = N.Vector3.Zero;
            if (axis == 0) n.X = -step[0];
            else if (axis == 1) n.Y = -step[1];
            else n.Z = -step[2];
            return n;
        }

        // Clips the segment to one bone's grid box: t0, t1 and the axis it came in through (-1: it started inside).
        bool ClipBox(int b, N.Vector3 go, N.Vector3 gd, out float t0, out float t1, out int entryAxis)
        {
            float[] l = { lo[b].x, lo[b].y, lo[b].z }, h = { hi[b].x, hi[b].y, hi[b].z };
            float[] g = { go.X, go.Y, go.Z }, dir = { gd.X, gd.Y, gd.Z };
            t0 = 0f;
            t1 = 1f;
            entryAxis = -1;
            for (int a = 0; a < 3; a++)
            {
                if (MathF.Abs(dir[a]) < PARALLEL)
                {
                    if (g[a] < l[a] || g[a] > h[a]) return false;
                    continue;
                }
                float ta = (l[a] - g[a]) / dir[a], tb = (h[a] - g[a]) / dir[a];
                if (MathF.Min(ta, tb) > t0)
                {
                    t0 = MathF.Min(ta, tb);
                    entryAxis = a;
                }
                t1 = MathF.Min(t1, MathF.Max(ta, tb));
            }
            return t0 <= t1;
        }

        // The face normal of the box side the segment came in through (zero when it started inside).
        static N.Vector3 EntryNormal(int axis, float[] dir)
        {
            var n = N.Vector3.Zero;
            if (axis == 0) n.X = -MathF.Sign(dir[0]);
            else if (axis == 1) n.Y = -MathF.Sign(dir[1]);
            else if (axis == 2) n.Z = -MathF.Sign(dir[2]);
            return n;
        }

        // The rotation part of `m`, orthonormalised (Godot's basis.orthonormalized(), Gram-Schmidt on x, y, z).
        static N.Matrix4x4 Orthonormal(N.Matrix4x4 m)
        {
            var x = N.Vector3.Normalize(new N.Vector3(m.M11, m.M12, m.M13));
            var y = new N.Vector3(m.M21, m.M22, m.M23);
            y = N.Vector3.Normalize(y - x * N.Vector3.Dot(x, y));
            var z = new N.Vector3(m.M31, m.M32, m.M33);
            z = N.Vector3.Normalize(z - x * N.Vector3.Dot(x, z) - y * N.Vector3.Dot(y, z));
            return new N.Matrix4x4(x.X, x.Y, x.Z, 0, y.X, y.Y, y.Z, 0, z.X, z.Y, z.Z, 0, 0, 0, 0, 1);
        }

        // True if any cube within `reach` cells of `cell` on that bone passes `test` (its colour).
        public bool AnyNear(int bone, (int x, int y, int z) cell, int reach, Func<N.Vector3, bool> test)
        {
            Dictionary<(int, int, int), N.Vector3> own = cells[bone];
            for (int x = -reach; x <= reach; x++)
                for (int y = -reach; y <= reach; y++)
                    for (int z = -reach; z <= reach; z++)
                        if (own.TryGetValue((cell.x + x, cell.y + y, cell.z + z), out N.Vector3 c) && test(c)) return true;
            return false;
        }

        // Records a wound at a rest-space point, replacing the oldest when the buffer is full.
        public void AddWound(N.Vector3 rest, float strength)
        {
            wounds[next] = new N.Vector4(rest, strength);
            next = (next + 1) % max;
        }

        // Fades every wound by `dt` seconds of a `lifetime`-second wound.
        public void Age(float dt, float lifetime)
        {
            float fade = dt / MathF.Max(lifetime, SHORTEST_LIFE);
            for (int i = 0; i < max; i++)
                if (wounds[i].W > 0f) wounds[i].W = MathF.Max(0f, wounds[i].W - fade);
        }

        // How many wounds still show.
        public int Live()
        {
            int n = 0;
            for (int i = 0; i < max; i++) if (wounds[i].W > WOUND_FLOOR) n++;
            return n;
        }
    }
}
