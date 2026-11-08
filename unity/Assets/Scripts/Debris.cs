using Unity.Collections;
using Unity.Collections.LowLevel.Unsafe;
using UnityEngine;
using UnityEngine.Rendering;

// Carved cells as GPU particles: a ring of cubes stepped by a compute shader, landing on a heightfield
// so rubble piles up and stays.
public sealed unsafe class Debris
{
    readonly Tuning tuning;
    readonly ComputeShader compute;
    readonly int kernel;
    readonly GraphicsBuffer particles, heights;
    readonly Material material;
    readonly Mesh cube;
    readonly MaterialPropertyBlock block = new MaterialPropertyBlock();
    readonly int pool, gridCells;
    readonly Vector3 gridMin;
    NativeArray<KcParticle> staging;
    NativeArray<int> keep;
    int stagingCount, head;
    long spawned;

    const int STAGING = 1 << 18;

    public long Spawned => spawned;
    public int Live => (int)System.Math.Min(spawned, pool);

    public Debris(Tuning t, ComputeShader cs, Shader shader, Mesh cubeMesh, Vector3 centre)
    {
        tuning = t;
        compute = cs;
        cube = cubeMesh;
        pool = t.debris_pool;
        kernel = cs.FindKernel("Step");
        particles = new GraphicsBuffer(GraphicsBuffer.Target.Structured, pool, 32);
        var zero = new NativeArray<KcParticle>(pool, Allocator.Persistent, NativeArrayOptions.ClearMemory);
        particles.SetData(zero);
        zero.Dispose();
        gridCells = Mathf.CeilToInt(t.debris_grid_span / t.debris_grid_cell);
        heights = new GraphicsBuffer(GraphicsBuffer.Target.Structured, gridCells * gridCells, 4);
        var flat = new NativeArray<uint>(gridCells * gridCells, Allocator.Persistent, NativeArrayOptions.ClearMemory);
        heights.SetData(flat);
        flat.Dispose();
        gridMin = centre - new Vector3(t.debris_grid_span, 0, t.debris_grid_span) * 0.5f;
        material = new Material(shader) { enableInstancing = true };
        material.EnableKeyword("SLICE_DEBRIS");
        staging = new NativeArray<KcParticle>(STAGING, Allocator.Persistent);
        keep = new NativeArray<int>(STAGING, Allocator.Persistent);
    }

    public void Spawn(VoxelBody b, int* index, int n, Vector3 centre, Vector3 velocity, float burst, uint tick)
    {
        int every = Mathf.Max(1, tuning.debris_keep_every);
        int room = STAGING - stagingCount;
        if (room <= 0 || n <= 0) return;
        int* picked = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(keep);
        int count = 0;
        for (int k = 0; k < n && count < room; k += every) picked[count++] = index[k];
        Matrix4x4 mat = b.transform.localToWorldMatrix;
        KcParticle* output = (KcParticle*)NativeArrayUnsafeUtility.GetUnsafePtr(staging) + stagingCount;
        Vector3 v = velocity, c = centre;
        stagingCount += Native.kc_debris(b.mesher, picked, count, (float*)&mat, (float*)&v, (float*)&c, burst, tuning.debris_up, tuning.debris_scatter, tick, output, room);
    }

    public void Step(float dt)
    {
        if (stagingCount > 0)
        {
            int first = Mathf.Min(stagingCount, pool - head);
            particles.SetData(staging, 0, head, first);
            if (first < stagingCount) particles.SetData(staging, first, 0, stagingCount - first);
            head = (head + stagingCount) % pool;
            spawned += stagingCount;
            stagingCount = 0;
        }
        if (spawned == 0) return;
        compute.SetBuffer(kernel, "_Particles", particles);
        compute.SetBuffer(kernel, "_Height", heights);
        compute.SetFloat("_Dt", dt);
        compute.SetFloat("_Gravity", tuning.gravity);
        compute.SetInt("_Count", Live);
        compute.SetInt("_GridCells", gridCells);
        compute.SetFloats("_GridMin", gridMin.x, gridMin.z);
        compute.SetFloat("_GridStep", tuning.debris_grid_cell);
        float grain = tuning.debris_size * tuning.debris_size * tuning.debris_size * Mathf.Max(1, tuning.debris_keep_every) / (tuning.debris_grid_cell * tuning.debris_grid_cell);
        compute.SetFloat("_Grain", grain);
        compute.Dispatch(kernel, Mathf.CeilToInt(Live / 256f), 1, 1);
    }

    public void Draw()
    {
        if (spawned == 0) return;
        block.SetBuffer("_Particles", particles);
        Graphics.DrawMeshInstancedProcedural(cube, 0, material, new Bounds(Vector3.zero, Vector3.one * 8000), Live, block,
            tuning.debris_shadows ? ShadowCastingMode.On : ShadowCastingMode.Off, true);
    }

    public void Dispose()
    {
        particles.Dispose();
        heights.Dispose();
        staging.Dispose();
        keep.Dispose();
        Object.Destroy(material);
    }
}
