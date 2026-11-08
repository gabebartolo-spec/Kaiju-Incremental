using System;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;

// One voxel grid in the world: a standing building (static, identity transform) or a piece that broke
// off (a Rigidbody; its grid stays in the at-rest frame its parent had). Godot axes inside the grid,
// z negated at the render boundary: world = transform * (x, y, -z).
public sealed unsafe class VoxelBody : MonoBehaviour
{
    public const int REGION = 16;

    public sealed class Region
    {
        public GameObject go;
        public Mesh mesh;
        public MeshRenderer renderer;
        public BoxCollider box;
    }

    public struct Pending
    {
        public Vector3 world;
        public float radius;
        public Vector3 velocity;
        public float burst;
    }

    public City city;
    public int w, h, d, hasFix;
    public float voxel;
    public Vector3 origin;
    public NativeArray<byte> cells, drawn, looks;
    public byte* fixtures;
    public NativeArray<byte> palette, finish, fixturesArray; // owned by the BuildingBlob, shared with pieces
    public IntPtr mesher;
    public Material material;
    public Rigidbody rb;
    public long count;
    public bool busy, wantSettle, queued, gone;
    public float nextSettle;
    public int nrx, nry, nrz;
    public Region[] regions;
    public bool[] dirty;
    public readonly List<int> dirtyList = new List<int>();
    public readonly List<Pending> pending = new List<Pending>();
    public bool hasKick;
    public Vector3 kickAngular, kickPivotWorld, kickLinear;

    public bool Free => rb != null;
    public byte* Cells => (byte*)Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafePtr(cells);
    public byte* Drawn => (byte*)Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafePtr(drawn);
    public byte* Looks => (byte*)Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafePtr(looks);

    public void Init(City owner, int gw, int gh, int gd, float cell, Vector3 at, Material mat)
    {
        city = owner;
        w = gw;
        h = gh;
        d = gd;
        voxel = cell;
        origin = at;
        material = mat;
        nrx = (w + REGION - 1) / REGION;
        nry = (h + REGION - 1) / REGION;
        nrz = (d + REGION - 1) / REGION;
        regions = new Region[nrx * nry * nrz];
        dirty = new bool[regions.Length];
    }

    public void MarkAll()
    {
        for (int i = 0; i < dirty.Length; i++)
        {
            if (dirty[i]) continue;
            dirty[i] = true;
            dirtyList.Add(i);
        }
    }

    public void MarkRegion(int rx, int ry, int rz)
    {
        if (rx < 0 || ry < 0 || rz < 0 || rx >= nrx || ry >= nry || rz >= nrz) return;
        int i = rx + rz * nrx + ry * nrx * nrz;
        if (dirty[i]) return;
        dirty[i] = true;
        dirtyList.Add(i);
    }

    // Regions touched by cells [lo, hi] (a cell's open faces and AO reach one cell over).
    public void MarkBox(int x0, int y0, int z0, int x1, int y1, int z1)
    {
        for (int ry = (y0 - 1) >> 4; ry <= (y1 + 1) >> 4; ry++)
            for (int rz = (z0 - 1) >> 4; rz <= (z1 + 1) >> 4; rz++)
                for (int rx = (x0 - 1) >> 4; rx <= (x1 + 1) >> 4; rx++)
                    MarkRegion(rx, ry, rz);
    }

    public void MarkCell(int i)
    {
        int plan = w * d;
        int x = i % w, z = (i / w) % d, y = i / plan;
        MarkBox(x, y, z, x, y, z);
    }

    public Vector3 WorldToCell(Vector3 world)
    {
        Vector3 local = Free ? transform.InverseTransformPoint(world) : world;
        return new Vector3(
            (local.x - origin.x) / voxel + 0.5f,
            (local.y - origin.y) / voxel + 0.5f,
            (-local.z - origin.z) / voxel + 0.5f);
    }

    // The at-rest box of a region (lo inclusive, hi exclusive, cells) in this body's local Unity axes.
    public Bounds LocalBox(int* lo, int* hi)
    {
        float x0 = origin.x + (lo[0] - 0.5f) * voxel, x1 = origin.x + (hi[0] - 0.5f) * voxel;
        float y0 = origin.y + (lo[1] - 0.5f) * voxel, y1 = origin.y + (hi[1] - 0.5f) * voxel;
        float z0 = -(origin.z + (hi[2] - 0.5f) * voxel), z1 = -(origin.z + (lo[2] - 0.5f) * voxel);
        var b = new Bounds();
        b.SetMinMax(new Vector3(x0, y0, z0), new Vector3(x1, y1, z1));
        return b;
    }

    public Region RegionAt(int index, int rx, int ry, int rz)
    {
        Region r = regions[index];
        if (r != null) return r;
        r = new Region();
        r.go = new GameObject("r");
        r.go.transform.SetParent(transform, false);
        r.mesh = new Mesh { name = "region" };
        r.mesh.MarkDynamic();
        r.go.AddComponent<MeshFilter>().sharedMesh = r.mesh;
        r.renderer = r.go.AddComponent<MeshRenderer>();
        r.renderer.sharedMaterial = material;
        r.renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
        r.box = r.go.AddComponent<BoxCollider>();
        regions[index] = r;
        return r;
    }

    void OnCollisionEnter(Collision c)
    {
        if (city == null || !Free || c.contactCount == 0) return;
        float speed = c.relativeVelocity.magnitude;
        if (speed < city.tuning.impact_speed) return;
        Vector3 at = c.GetContact(0).point;
        VoxelBody other = c.collider.GetComponentInParent<VoxelBody>();
        city.QueueImpact(this, other, at, speed);
    }
}
