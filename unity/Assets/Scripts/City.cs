using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;
using Unity.Collections;
using Unity.Collections.LowLevel.Unsafe;
using Unity.Jobs;
using UnityEngine;
using UnityEngine.Rendering;

// The block: every voxel body, the carve, the settle pass (one worker at a time, on shared scratch) and
// the remesh (a parallel job over dirty regions into MeshData).
public sealed unsafe class City
{
    public struct Sphere
    {
        public Vector3 world;
        public float radius;
        public Vector3 velocity;
    }

    struct Impact
    {
        public VoxelBody a, b;
        public Vector3 at;
        public float speed;
    }

    struct Item
    {
        public IntPtr mesher, drawn;
        public int rx, ry, rz;
    }

    struct MeshJob : IJobParallelFor
    {
        [ReadOnly] public NativeArray<Item> items;
        [ReadOnly] public NativeArray<VertexAttributeDescriptor> layout;
        public Mesh.MeshDataArray data;

        public void Execute(int i)
        {
            Item it = items[i];
            int nv, ni;
            Native.kc_mesh_region(it.mesher, (byte*)it.drawn, it.rx, it.ry, it.rz, &nv, &ni);
            Mesh.MeshData m = data[i];
            m.SetVertexBufferParams(nv, layout);
            m.SetIndexBufferParams(ni, IndexFormat.UInt32);
            NativeArray<KcVertex> v = m.GetVertexData<KcVertex>();
            NativeArray<uint> x = m.GetIndexData<uint>();
            Native.kc_mesh_copy((KcVertex*)NativeArrayUnsafeUtility.GetUnsafePtr(v), (uint*)NativeArrayUnsafeUtility.GetUnsafePtr(x));
            m.subMeshCount = 1;
            m.SetSubMesh(0, new SubMeshDescriptor(0, ni), MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices);
        }
    }

    public readonly Tuning tuning;
    public readonly List<VoxelBody> bodies = new List<VoxelBody>();
    public readonly Debris debris;
    public double lastTickMs, lastMeshMs, lastSettleMs;
    public int lastRegions;

    readonly List<BuildingBlob> blobs;
    readonly List<Material> materials = new List<Material>();
    readonly List<Impact> impacts = new List<Impact>();
    readonly Queue<VoxelBody> settleQueue = new Queue<VoxelBody>();
    readonly Transform root;
    readonly List<Mesh> meshList = new List<Mesh>();
    readonly List<int> meshRegion = new List<int>();
    readonly List<VoxelBody> meshBody = new List<VoxelBody>();

    NativeArray<VertexAttributeDescriptor> layout;
    NativeArray<int> carved, labels, islandCells, sizes;
    NativeArray<KcTip> tips;
    Task settleTask;
    VoxelBody settling;
    int settleParts, settleTotal, settleCount, settleTips;
    double settleMs;
    uint tick;

    const int CARVE_CAP = 1 << 19;
    const int SIZE_CAP = 1 << 16;
    const int TIP_CAP = 64;

    public City(Tuning t, List<BuildingBlob> buildings, Shader buildingShader, Debris d, Transform parent)
    {
        tuning = t;
        blobs = buildings;
        debris = d;
        root = parent;
        layout = new NativeArray<VertexAttributeDescriptor>(4, Allocator.Persistent);
        layout[0] = new VertexAttributeDescriptor(VertexAttribute.Position, VertexAttributeFormat.Float32, 3);
        layout[1] = new VertexAttributeDescriptor(VertexAttribute.Normal, VertexAttributeFormat.Float32, 3);
        layout[2] = new VertexAttributeDescriptor(VertexAttribute.Color, VertexAttributeFormat.UNorm8, 4);
        layout[3] = new VertexAttributeDescriptor(VertexAttribute.TexCoord0, VertexAttributeFormat.Float32, 2);
        int biggest = 1;
        foreach (BuildingBlob b in buildings) biggest = Mathf.Max(biggest, b.w * b.h * b.d);
        carved = new NativeArray<int>(CARVE_CAP, Allocator.Persistent);
        labels = new NativeArray<int>(biggest, Allocator.Persistent);
        islandCells = new NativeArray<int>(biggest, Allocator.Persistent);
        sizes = new NativeArray<int>(SIZE_CAP, Allocator.Persistent);
        tips = new NativeArray<KcTip>(TIP_CAP, Allocator.Persistent);

        foreach (BuildingBlob b in buildings)
        {
            var mat = new Material(buildingShader);
            mat.EnableKeyword("SLICE_BUILDING");
            mat.SetFloat("_CullMode", 0);
            mat.SetFloat("_CullModeForward", 0);
            mat.SetVector("_VoxelOrigin", b.origin);
            mat.SetFloat("_VoxelSize", b.voxel);
            mat.SetFloat("_Salt", b.salt);
            mat.SetFloat("_Noise", b.noise);
            mat.SetVector("_WinUnit", b.unit);
            mat.SetVector("_WinAlign", b.align);
            materials.Add(mat);
            VoxelBody body = NewBody("building", b.w, b.h, b.d, b.voxel, b.origin, mat, b.cells, b.drawn, b.looks, b.palette, b.finish, b.fixtures, b.hasFix, b.ox, b.oy, b.oz);
            body.MarkAll();
        }
        Remesh(int.MaxValue);
    }

    VoxelBody NewBody(string name, int w, int h, int d, float voxel, Vector3 origin, Material mat, NativeArray<byte> cells, NativeArray<byte> drawn, NativeArray<byte> looks, NativeArray<byte> palette, NativeArray<byte> finish, NativeArray<byte> fixtures, int hasFix, int ox, int oy, int oz)
    {
        var go = new GameObject(name);
        go.transform.SetParent(root, false);
        VoxelBody body = go.AddComponent<VoxelBody>();
        body.Init(this, w, h, d, voxel, origin, mat);
        body.cells = cells;
        body.drawn = drawn;
        body.looks = looks;
        body.hasFix = hasFix;
        body.fixtures = (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(fixtures);
        body.mesher = Native.kc_mesher_create(w, h, d, ox, oy, oz, origin.x, origin.y, origin.z, voxel, body.Looks,
            (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(palette), (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(finish), 1);
        long n = 0;
        byte* c = body.Cells;
        for (int i = 0, end = w * h * d; i < end; i++)
            if (c[i] != 0) n++;
        body.count = n;
        bodies.Add(body);
        body.palette = palette;
        body.finish = finish;
        body.fixturesArray = fixtures;
        return body;
    }

    public void QueueImpact(VoxelBody a, VoxelBody b, Vector3 at, float speed)
    {
        if (impacts.Count < 64) impacts.Add(new Impact { a = a, b = b, at = at, speed = speed });
    }

    public void Tick(List<Sphere> spheres, Debris d)
    {
        var watch = Stopwatch.StartNew();
        tick++;
        foreach (Sphere s in spheres)
            for (int i = 0, n = bodies.Count; i < n; i++)
                CarveBody(bodies[i], s.world, s.radius, s.velocity, tuning.debris_burst);
        foreach (Impact im in impacts)
        {
            float r = Mathf.Clamp(im.speed * tuning.impact_radius_per_speed, tuning.impact_radius_min, tuning.impact_radius_max);
            if (im.a != null && !im.a.gone) CarveBody(im.a, im.at, r, Vector3.zero, tuning.impact_burst);
            if (im.b != null && !im.b.gone) CarveBody(im.b, im.at, r, Vector3.zero, tuning.impact_burst);
        }
        impacts.Clear();
        SettleStep();
        Remesh(2048);
        lastTickMs = watch.Elapsed.TotalMilliseconds;
    }

    void CarveBody(VoxelBody b, Vector3 world, float radius, Vector3 velocity, float burst)
    {
        if (b.gone) return;
        Vector3 c = b.WorldToCell(world);
        float r = radius / b.voxel;
        if (c.x + r < 0 || c.y + r < 0 || c.z + r < 0 || c.x - r > b.w || c.y - r > b.h || c.z - r > b.d) return;
        if (b.busy)
        {
            if (b.pending.Count < 256)
                b.pending.Add(new VoxelBody.Pending { world = world, radius = radius, velocity = velocity, burst = burst });
            return;
        }
        int* output = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(carved);
        int n = Native.kc_carve_sphere(b.Cells, b.Drawn, b.w, b.h, b.d, c.x, c.y, c.z, r, output, CARVE_CAP);
        if (n <= 0) return;
        b.count -= n;
        debris.Spawn(b, output, Mathf.Min(n, CARVE_CAP), world, velocity, burst, tick);
        b.MarkBox(Mathf.FloorToInt(c.x - r), Mathf.FloorToInt(c.y - r), Mathf.FloorToInt(c.z - r),
            Mathf.CeilToInt(c.x + r), Mathf.CeilToInt(c.y + r), Mathf.CeilToInt(c.z + r));
        WantSettle(b);
    }

    void WantSettle(VoxelBody b)
    {
        if (b.queued) return;
        b.queued = true;
        settleQueue.Enqueue(b);
    }

    void SettleStep()
    {
        if (settleTask != null)
        {
            if (!settleTask.IsCompleted) return;
            settleTask.Wait();
            settleTask = null;
            ApplySettle();
        }
        int tries = settleQueue.Count;
        while (tries-- > 0)
        {
            VoxelBody b = settleQueue.Dequeue();
            if (b == null || b.gone) continue;
            if (Time.time < b.nextSettle)
            {
                settleQueue.Enqueue(b);
                continue;
            }
            b.queued = false;
            b.nextSettle = Time.time + tuning.settle_cooldown_s;
            if (b.Free && b.count < tuning.island_min_cells)
            {
                Dissolve(b);
                continue;
            }
            StartSettle(b);
            return;
        }
    }

    void StartSettle(VoxelBody b)
    {
        settling = b;
        b.busy = true;
        byte* cells = b.Cells;
        byte* fix = b.fixtures;
        int* lab = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(labels);
        int* outCells = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(islandCells);
        int* outSizes = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(sizes);
        KcTip* outTips = (KcTip*)NativeArrayUnsafeUtility.GetUnsafePtr(tips);
        int w = b.w, h = b.h, d = b.d, hasFix = b.hasFix, cap = w * h * d;
        bool free = b.Free;
        IntPtr cellsP = (IntPtr)cells, fixP = (IntPtr)fix, labP = (IntPtr)lab, outP = (IntPtr)outCells, sizesP = (IntPtr)outSizes, tipsP = (IntPtr)outTips;
        settleTask = Task.Run(() =>
        {
            var watch = Stopwatch.StartNew();
            byte* c = (byte*)cellsP;
            byte* f = (byte*)fixP;
            int* l = (int*)labP;
            int count = Native.kc_label(c, f, hasFix, w, h, d, l);
            int total = 0;
            int parts = Native.kc_islands(l, c, f, hasFix, w, h, d, (int*)outP, cap, (int*)sizesP, SIZE_CAP, &total);
            settleTips = free ? 0 : Native.kc_topple(l, c, f, w, h, d, count, (KcTip*)tipsP, TIP_CAP);
            settleParts = parts;
            settleTotal = total;
            settleCount = count;
            settleMs = watch.Elapsed.TotalMilliseconds;
        });
    }

    void ApplySettle()
    {
        VoxelBody b = settling;
        settling = null;
        lastSettleMs = settleMs;
        if (b == null || b.gone) return;
        int* index = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(islandCells);
        int* size = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(sizes);
        int at = 0;
        var kept = new List<(int first, int n)>();
        for (int k = 0; k < settleParts; k++)
        {
            kept.Add((at, size[k]));
            at += size[k];
        }
        foreach ((int first, int n) in kept)
        {
            if (n < tuning.island_min_cells)
            {
                debris.Spawn(b, index + first, n, b.transform.TransformPoint(new Vector3(0, 0, 0)), PointVelocity(b), 0.5f, tick);
                byte* c = b.Cells;
                byte* dr = b.Drawn;
                for (int k = 0; k < n; k++)
                {
                    int i = index[first + k];
                    c[i] = 0;
                    dr[i] = 0;
                    b.MarkCell(i);
                }
                b.count -= n;
            }
            else
            {
                Split(b, index + first, n);
            }
        }
        if (settleTips > 0) ApplyTips(b);
        b.busy = false;
        if (b.pending.Count > 0)
        {
            var list = new List<VoxelBody.Pending>(b.pending);
            b.pending.Clear();
            foreach (VoxelBody.Pending p in list) CarveBody(b, p.world, p.radius, p.velocity, p.burst);
        }
        if (b.Free && b.count <= 0) Dissolve(b);
    }

    // Cells of a grounded part at or above the tip level come away as a piece, tipped over its edge.
    void ApplyTips(VoxelBody b)
    {
        int* lab = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(labels);
        int* index = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(islandCells);
        int plan = b.w * b.d;
        byte* cells = b.Cells;
        for (int t = 0; t < settleTips; t++)
        {
            KcTip tip = tips[t];
            int n = 0;
            for (int i = tip.level * plan, end = plan * b.h; i < end; i++)
                if (lab[i] == tip.part && cells[i] != 0)
                    index[n++] = i;
            if (n == 0) continue;
            VoxelBody piece = Split(b, index, n);
            var dir = new Vector3(tip.dirX, 0, -tip.dirZ);
            piece.hasKick = true;
            piece.kickAngular = new Vector3(dir.z, 0, -dir.x) * tuning.topple_turn;
            piece.kickPivotWorld = new Vector3(
                b.origin.x + (tip.pivotX - 0.5f) * b.voxel,
                b.origin.y + (tip.level - 0.5f) * b.voxel,
                -(b.origin.z + (tip.pivotZ - 0.5f) * b.voxel));
        }
    }

    Vector3 PointVelocity(VoxelBody b) => b.Free ? b.rb.linearVelocity : Vector3.zero;

    VoxelBody Split(VoxelBody b, int* index, int n)
    {
        int* lo = stackalloc int[3];
        int* hi = stackalloc int[3];
        Native.kc_cells_bounds(index, n, b.w, b.d, lo, hi);
        int nw = hi[0] - lo[0], nh = hi[1] - lo[1], nd = hi[2] - lo[2];
        int size = nw * nh * nd;
        var cells = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.ClearMemory);
        var drawn = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.ClearMemory);
        var looks = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.ClearMemory);
        Native.kc_cells_move(b.Cells, b.Drawn, b.Looks, index, n, b.w, b.d, lo, nw, nd,
            (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(cells),
            (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(drawn),
            (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(looks));
        for (int k = 0; k < n; k++) b.MarkCell(index[k]);
        b.count -= n;
        Vector3 origin = b.origin + new Vector3(lo[0], lo[1], lo[2]) * b.voxel;
        // A huge offset up: nothing sits below a falling piece, so its underside draws.
        VoxelBody piece = NewBody("piece", nw, nh, nd, b.voxel, origin, b.material, cells, drawn, looks, b.palette, b.finish, b.fixturesArray, b.hasFix, 0, 1 << 20, 0);
        piece.transform.SetPositionAndRotation(b.transform.position, b.transform.rotation);
        Rigidbody rb = piece.gameObject.AddComponent<Rigidbody>();
        rb.mass = Mathf.Max(1, piece.count * tuning.cell_mass);
        rb.interpolation = RigidbodyInterpolation.Interpolate;
        rb.maxDepenetrationVelocity = tuning.depenetration;
        rb.linearVelocity = PointVelocity(b);
        if (b.Free) rb.angularVelocity = b.rb.angularVelocity;
        piece.rb = rb;
        piece.MarkAll();
        return piece;
    }

    // A piece too small to stand as a body goes wholly to debris.
    void Dissolve(VoxelBody b)
    {
        b.gone = true;
        int n = 0;
        byte* c = b.Cells;
        int* output = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(carved);
        for (int i = 0, end = b.w * b.h * b.d; i < end && n < CARVE_CAP; i++)
            if (c[i] != 0)
                output[n++] = i;
        debris.Spawn(b, output, n, b.transform.position, PointVelocity(b), 0.5f, tick);
        DestroyBody(b);
    }

    void DestroyBody(VoxelBody b)
    {
        foreach (VoxelBody.Region r in b.regions)
            if (r != null)
                UnityEngine.Object.Destroy(r.mesh);
        Native.kc_mesher_destroy(b.mesher);
        b.cells.Dispose();
        b.drawn.Dispose();
        b.looks.Dispose();
        bodies.Remove(b);
        UnityEngine.Object.Destroy(b.gameObject);
    }

    void Remesh(int limit)
    {
        var watch = Stopwatch.StartNew();
        meshList.Clear();
        meshRegion.Clear();
        meshBody.Clear();
        int* lo = stackalloc int[3];
        int* hi = stackalloc int[3];
        foreach (VoxelBody b in bodies)
        {
            if (b.dirtyList.Count == 0) continue;
            for (int k = b.dirtyList.Count - 1; k >= 0 && meshList.Count < limit; k--)
            {
                int index = b.dirtyList[k];
                b.dirtyList.RemoveAt(k);
                b.dirty[index] = false;
                int rx = index % b.nrx, rz = (index / b.nrx) % b.nrz, ry = index / (b.nrx * b.nrz);
                int n = Native.kc_region_bbox(b.Cells, b.w, b.h, b.d, rx, ry, rz, lo, hi);
                VoxelBody.Region r = b.regions[index];
                if (n == 0)
                {
                    if (r == null) continue;
                    r.renderer.enabled = false;
                    r.box.enabled = false;
                    continue;
                }
                r = b.RegionAt(index, rx, ry, rz);
                Bounds box = b.LocalBox(lo, hi);
                r.box.center = box.center;
                r.box.size = box.size;
                r.box.enabled = true;
                r.renderer.enabled = true;
                meshList.Add(r.mesh);
                meshRegion.Add(index);
                meshBody.Add(b);
            }
        }
        lastRegions = meshList.Count;
        if (meshList.Count > 0)
        {
            var items = new NativeArray<Item>(meshList.Count, Allocator.TempJob);
            for (int i = 0; i < items.Length; i++)
            {
                VoxelBody b = meshBody[i];
                int index = meshRegion[i];
                items[i] = new Item
                {
                    mesher = b.mesher,
                    drawn = (IntPtr)b.Drawn,
                    rx = index % b.nrx,
                    rz = (index / b.nrx) % b.nrz,
                    ry = index / (b.nrx * b.nrz),
                };
            }
            Mesh.MeshDataArray data = Mesh.AllocateWritableMeshData(meshList.Count);
            var job = new MeshJob { items = items, layout = layout, data = data };
            job.Schedule(items.Length, 4).Complete();
            Mesh.ApplyAndDisposeWritableMeshData(data, meshList, MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices);
            for (int i = 0; i < items.Length; i++)
            {
                VoxelBody b = meshBody[i];
                Item it = items[i];
                lo[0] = it.rx * VoxelBody.REGION;
                lo[1] = it.ry * VoxelBody.REGION;
                lo[2] = it.rz * VoxelBody.REGION;
                hi[0] = lo[0] + VoxelBody.REGION;
                hi[1] = lo[1] + VoxelBody.REGION;
                hi[2] = lo[2] + VoxelBody.REGION;
                meshList[i].bounds = b.LocalBox(lo, hi);
            }
            items.Dispose();
        }
        lastMeshMs = watch.Elapsed.TotalMilliseconds;
        // Pieces meshed for the first time now have colliders: mass centre known, the topple kick can go.
        foreach (VoxelBody b in bodies)
        {
            if (!b.hasKick || !b.Free || b.dirtyList.Count != 0) continue;
            b.hasKick = false;
            Physics.SyncTransforms();
            b.rb.ResetCenterOfMass();
            b.rb.angularVelocity = b.kickAngular;
            b.rb.linearVelocity = Vector3.Cross(b.kickAngular, b.rb.worldCenterOfMass - b.kickPivotWorld);
        }
    }

    public int Pieces()
    {
        int n = 0;
        foreach (VoxelBody b in bodies)
            if (b.Free)
                n++;
        return n;
    }

    public void Dispose()
    {
        settleTask?.Wait();
        foreach (VoxelBody b in bodies)
        {
            foreach (VoxelBody.Region r in b.regions)
                if (r != null)
                    UnityEngine.Object.Destroy(r.mesh);
            Native.kc_mesher_destroy(b.mesher);
            b.cells.Dispose();
            b.drawn.Dispose();
            b.looks.Dispose();
        }
        bodies.Clear();
        foreach (BuildingBlob b in blobs) SliceData.Dispose(b);
        foreach (Material m in materials) UnityEngine.Object.Destroy(m);
        layout.Dispose();
        carved.Dispose();
        labels.Dispose();
        islandCells.Dispose();
        sizes.Dispose();
        tips.Dispose();
    }
}
