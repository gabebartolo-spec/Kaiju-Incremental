using System;
using System.Runtime.InteropServices;

// The destruction core (native/kaiju_core.cpp). Proven against Godot's by tools/unity/check_core.py.
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct KcVertex
{
    public float px, py, pz, nx, ny, nz;
    public byte r, g, b, a;
    public float u, v;
}

[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct KcTip
{
    public int part, level, dirX, dirZ;
    public float pivotX, pivotZ;
}

[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct KcParticle
{
    public float px, py, pz;
    public uint color;
    public float vx, vy, vz;
    public uint seed;
}

public static unsafe class Native
{
    const string L = "kaiju_core";

    [DllImport(L)] public static extern int kc_version();
    [DllImport(L)] public static extern int kc_carve_sphere(byte* cells, byte* drawn, int w, int h, int d, float cx, float cy, float cz, float r, int* output, int cap);
    [DllImport(L)] public static extern int kc_label(byte* cells, byte* fix, int hasFixtures, int w, int h, int d, int* lab);
    [DllImport(L)] public static extern int kc_islands(int* lab, byte* cells, byte* fix, int hasFixtures, int w, int h, int d, int* output, int outCap, int* sizes, int sizeCap, int* total);
    [DllImport(L)] public static extern int kc_topple(int* lab, byte* cells, byte* fix, int w, int h, int d, int count, KcTip* output, int cap);
    [DllImport(L)] public static extern int kc_region_bbox(byte* cells, int w, int h, int d, int rx, int ry, int rz, int* lo, int* hi);
    [DllImport(L)] public static extern void kc_cells_bounds(int* index, int n, int w, int d, int* lo, int* hi);
    [DllImport(L)] public static extern void kc_cells_move(byte* cells, byte* drawn, byte* looks, int* index, int n, int w, int d, int* lo, int nw, int nd, byte* dstCells, byte* dstDrawn, byte* dstLooks);
    [DllImport(L)] public static extern IntPtr kc_mesher_create(int w, int h, int d, int ox, int oy, int oz, float fx, float fy, float fz, float voxel, byte* looks, byte* palette, byte* finish, int mirror);
    [DllImport(L)] public static extern void kc_mesher_destroy(IntPtr m);
    [DllImport(L)] public static extern void kc_mesh_region(IntPtr m, byte* g, int rx, int ry, int rz, int* outVerts, int* outIndex);
    [DllImport(L)] public static extern void kc_mesh_copy(KcVertex* verts, uint* index);
    [DllImport(L)] public static extern int kc_debris(IntPtr m, int* index, int n, float* mat, float* velocity, float* centre, float burst, float up, float scatter, uint tick, KcParticle* output, int cap);
}
