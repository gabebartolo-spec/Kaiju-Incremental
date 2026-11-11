// tools/unity/slice_digests.gd: a fixed carve sequence on the block's tallest buildings, each step
// recording the sphere and what the destruction core made of it. Godot ran its extension
// (KaijuCarve, KaijuSettle, KaijuMesher); this runs kaiju_core.dll, which check_core.py holds to it.
using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using Kaiju.Sim;
using RandomNumberGenerator = Kaiju.Sim.RandomNumberGenerator;

static unsafe class SliceDigests
{
    // Buildings the digests run on: the tallest of the block, so carves cut real load paths.
    const int DIGEST_BUILDINGS = 3;
    const int RANDOM_CARVES = 12;
    const int CUT_STEPS = 3;
    const long DIGEST_SEED = 20261108;
    const double CENTRE_SNAP = 0.125;
    // CellMesher.REGION
    const int REGION = 16;

    public static GDict Of(List<SliceBuilding> built)
    {
        var order = new List<int>();
        for (int i = 0; i < built.Count; i++) order.Add(i);
        order.Sort((a, b) =>
        {
            long ha = built[a].b.height, hb = built[b].b.height;
            if (ha != hb) return ha > hb ? -1 : 1;
            return a.CompareTo(b);
        });
        var rng = new RandomNumberGenerator();
        rng.seed = DIGEST_SEED;
        var o = new GArray<Variant>();
        for (int k = 0; k < Math.Min(DIGEST_BUILDINGS, order.Count); k++) o.Append(Building(order[k], built[order[k]], rng));
        return new GDict { { "buildings", o } };
    }

    // Vector3.snappedf: 32-bit parts snapped in 32-bit floats.
    static float Snap32(float v, float step) => MathF.Floor(v / step + 0.5f) * step;

    static Vector3 Snapped(Vector3 c, double step)
    {
        float s = (float)step;
        return new Vector3(Snap32((float)c.x, s), Snap32((float)c.y, s), Snap32((float)c.z, s));
    }

    static List<(Vector3, double)> Spheres(Vector3i dims, RandomNumberGenerator rng)
    {
        var o = new List<(Vector3, double)>();
        for (int i = 0; i < RANDOM_CARVES; i++)
        {
            double x = rng.RandfRange(0.0, dims.x);
            double y = rng.RandfRange(0.0, dims.y);
            double z = rng.RandfRange(0.0, dims.z);
            var c = new Vector3(x, y, z);
            o.Add((Snapped(c, CENTRE_SNAP), Gd.Snappedf(rng.RandfRange(4.0, 24.0), CENTRE_SNAP)));
        }
        // A cut right through at a quarter height: what brings a building's top down.
        double r = (double)Math.Max(dims.x, dims.z) / (double)CUT_STEPS * 0.8;
        for (int ix = 0; ix < CUT_STEPS; ix++)
        {
            for (int iz = 0; iz < CUT_STEPS; iz++)
            {
                var c = new Vector3((ix + 0.5) * dims.x / CUT_STEPS, dims.y * 0.25, (iz + 0.5) * dims.z / CUT_STEPS);
                o.Add((Snapped(c, CENTRE_SNAP), Gd.Snappedf(r, CENTRE_SNAP)));
            }
        }
        return o;
    }

    static GDict Building(int n, SliceBuilding one, RandomNumberGenerator rng)
    {
        Vector3i dims = one.dims;
        int w = (int)dims.x, h = (int)dims.y, d = (int)dims.z, cellCount = w * h * d;
        byte[] cells = SliceBuilding.Bytes(one.grid.cells);
        byte[] drawn = (byte[])one.drawn.Clone();
        byte[] fix = SliceBuilding.Bytes(one.frame.fixtures);
        bool hasFix = one.frame.hasFixtures;
        int[] labels = new int[cellCount], flat = new int[cellCount], sizes = new int[cellCount];
        var steps = new GArray<Variant>();
        IntPtr mesher;
        fixed (byte* looks = one.looks, palette = one.palette, finish = one.finish)
        {
            mesher = Native.kc_mesher_create(w, h, d, (int)one.offset.x, (int)one.offset.y, (int)one.offset.z,
                (float)one.origin.x, (float)one.origin.y, (float)one.origin.z, one.voxel, looks, palette, finish, 0);
        }
        try
        {
            foreach ((Vector3 centre, double radius) in Spheres(dims, rng))
            {
                int removed;
                fixed (byte* pc = cells, pd = drawn)
                {
                    removed = Native.kc_carve_sphere(pc, pd, w, h, d, (float)centre.x, (float)centre.y, (float)centre.z, (float)radius, null, 0);
                }
                int count = KaijuNative.kc_label(cells, fix, hasFix ? 1 : 0, w, h, d, labels);
                int parts = KaijuNative.kc_islands(labels, cells, fix, hasFix ? 1 : 0, w, h, d, flat, cellCount, sizes, cellCount, out int total);
                GArray<GDict> tips = Tips(labels, cells, fix, dims, count, one);
                var step = new GDict
                {
                    { "centre", Gd.Arr(centre.x, centre.y, centre.z) },
                    { "radius", radius },
                    { "removed", (long)removed },
                    { "cells_sha", Sha(cells, cells.Length) },
                    { "labels_sha", Sha(Ints(labels, cellCount), cellCount * 4) },
                    { "count", (long)count },
                };
                var islandSizes = new GArray<Variant>();
                for (int p = 0; p < parts; p++) islandSizes.Append((long)sizes[p]);
                step["island_sizes"] = islandSizes;
                step["islands_sha"] = Sha(Ints(flat, total), total * 4);
                step["tips"] = TipRows(tips);
                Mesh(step, mesher, drawn, dims);
                steps.Append(step);
                // The islands leave the grid, as the game's settle takes them.
                for (int i = 0; i < total; i++)
                {
                    cells[flat[i]] = 0;
                    drawn[flat[i]] = 0;
                }
            }
        }
        finally
        {
            Native.kc_mesher_destroy(mesher);
        }
        return new GDict { { "index", (long)n }, { "dims", Gd.Arr(dims.x, dims.y, dims.z) }, { "steps", steps } };
    }

    // KaijuSettle.floors (as Sim/Runtime/Native.cs calls it), then VoxelTopple.scan_levels.
    static GArray<GDict> Tips(int[] labels, byte[] cells, byte[] fix, Vector3i dims, int count, SliceBuilding one)
    {
        long slots = (long)count * (dims.y + 1);
        var mass = new PackedInt64Array();
        var sx = new PackedInt64Array();
        var sz = new PackedInt64Array();
        var box = new PackedInt32Array();
        mass.Resize(slots);
        sx.Resize(slots);
        sz.Resize(slots);
        box.Resize(count * dims.y * 4);
        Array.Fill(box.Raw, -1, 0, (int)box.Size());
        if (count > 0)
            KaijuNative.kc_floors(labels, cells, fix, (int)dims.x, (int)dims.y, (int)dims.z, count, mass.Raw, sx.Raw, sz.Raw, box.Raw);
        return VoxelTopple.ScanLevels(mass, sx, sz, box, count, dims.y, one.grid.offset, one.grid.res);
    }

    static GArray<Variant> TipRows(GArray<GDict> tips)
    {
        var rows = new GArray<Variant>();
        foreach (GDict t in tips)
        {
            Vector3 pivot = t["pivot"];
            Vector2i dir = t["dir"];
            rows.Append(new GDict
            {
                { "part", t["label"] },
                { "level", t["level"] },
                { "dir", Gd.Arr(dir.x, dir.y) },
                { "pivot", Gd.Arr(pivot.x, pivot.y, pivot.z) },
            });
        }
        return rows;
    }

    // slice_digests.gd _add_mesh: every region's arrays in Godot's order (positions, normals, rgba8
    // colours, UVs, indices), the DLL's interleaved vertices split apart.
    static void Mesh(GDict step, IntPtr mesher, byte[] drawn, Vector3i dims)
    {
        using var sha = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        long nx = (dims.x + REGION - 1) / REGION, ny = (dims.y + REGION - 1) / REGION, nz = (dims.z + REGION - 1) / REGION;
        long verts = 0, indices = 0;
        for (int rx = 0; rx < nx; rx++)
        {
            for (int ry = 0; ry < ny; ry++)
            {
                for (int rz = 0; rz < nz; rz++)
                {
                    int nv, ni;
                    fixed (byte* g = drawn) Native.kc_mesh_region(mesher, g, rx, ry, rz, &nv, &ni);
                    if (nv == 0) continue;
                    var v = new KcVertex[nv];
                    var index = new uint[ni];
                    fixed (KcVertex* pv = v)
                    fixed (uint* pi = index)
                        Native.kc_mesh_copy(pv, pi);
                    verts += nv;
                    indices += ni;
                    byte[] pos = new byte[nv * 12], nrm = new byte[nv * 12], col = new byte[nv * 4], uv = new byte[nv * 8];
                    fixed (byte* pp = pos, pn = nrm, pc = col, pu = uv)
                    {
                        float* fp = (float*)pp, fn = (float*)pn, fu = (float*)pu;
                        for (int i = 0; i < nv; i++)
                        {
                            KcVertex x = v[i];
                            fp[i * 3] = x.px; fp[i * 3 + 1] = x.py; fp[i * 3 + 2] = x.pz;
                            fn[i * 3] = x.nx; fn[i * 3 + 1] = x.ny; fn[i * 3 + 2] = x.nz;
                            pc[i * 4] = x.r; pc[i * 4 + 1] = x.g; pc[i * 4 + 2] = x.b; pc[i * 4 + 3] = x.a;
                            fu[i * 2] = x.u; fu[i * 2 + 1] = x.v;
                        }
                    }
                    byte[] ib = new byte[ni * 4];
                    Buffer.BlockCopy(index, 0, ib, 0, ib.Length);
                    sha.AppendData(pos);
                    sha.AppendData(nrm);
                    sha.AppendData(col);
                    sha.AppendData(uv);
                    sha.AppendData(ib);
                }
            }
        }
        step["verts"] = verts;
        step["indices"] = indices;
        step["mesh_sha"] = Hex(sha.GetHashAndReset());
    }

    static byte[] Ints(int[] a, int n)
    {
        var o = new byte[n * 4];
        Buffer.BlockCopy(a, 0, o, 0, o.Length);
        return o;
    }

    static string Sha(byte[] data, int n) => Hex(SHA256.HashData(new ReadOnlySpan<byte>(data, 0, n)));

    static string Hex(byte[] h) => Convert.ToHexString(h).ToLowerInvariant();
}
