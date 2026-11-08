using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

// A sheet of water the ground asks for (scenes/water_surface.gd sheet, scenes/harbour_view.gd water), in Godot
// coordinates. bay: the open water (its swell, the open sea). lap: the beach's sea, its rows fading in from z0.
public struct WaterRect
{
    public float x0, z0, x1, z1, y;
    public bool bay, lap;
}

// The sim's liquid on screen (scenes/water_view.gd, scenes/water_surface.gd): each basin's surface heights go to
// a float texture every frame and the sheets over it lift their vertices by it and take its slope into their
// normals (SliceWater.hlsl), so the waves on screen are the sim's own. Presentation only: it reads the sim, never
// writes, except to take the splashes it has drawn.
public sealed class WaterView : IDisposable
{
    const float BOUNDS_LIFT = 30f;  // how far a sheet's waves can leave its plane (m), for culling
    // The bay reaches the horizon: 2 m cells only where the camera can bring them near, then longer with distance,
    // on a grid whose rows and columns run the whole way, so nothing cracks. The waves die out past that anyway.
    const float DENSE_MARGIN = 300f, FAR_GROWTH = 0.08f, FAR_CELL = 40f;
    // scenes/fire.gd WIND: the run's wind, which the waves run with.
    static readonly Vector2 WIND = new Vector2(2.2f, 0.9f);

    [StructLayout(LayoutKind.Sequential)]
    struct Vertex
    {
        public Vector3 position;
        public uint normal, tangent;
        public Color32 color;
        public Vector2 uv;
    }

    // HDRenderQueue.Priority.TransparentFirst (internal): drawn first of the transparent things, smoke over it.
    const int TRANSPARENT_FIRST = 2900;
    const uint NORMAL_UP = 0x00007F00u, TANGENT_X = 0x7F00007Fu;

    readonly S.RampageSim sim;
    readonly OceanWaves ocean;
    readonly List<Mesh> meshes = new List<Mesh>();
    readonly List<Material> materials = new List<Material>();
    readonly float film;
    readonly Texture2D[] textures;
    readonly float[][] heights;
    readonly float[][] low;
    readonly bool[] wasActive;

    public long VertexCount { get; private set; }

    public WaterView(S.RampageSim sim, List<WaterRect> sheets, Shader shader, ComputeShader oceanShader, S.GDict city, Transform parent)
    {
        this.sim = sim;
        S.GDict simCfg = S.Content.Section("water_sim");
        film = F(simCfg["film"]);
        int count = (int)sim.water.basins.Size();
        textures = new Texture2D[count];
        heights = new float[count][];
        low = new float[count][];
        wasActive = new bool[count];
        for (int n = 0; n < count; n++) MakeBasin(n);
        Fill(true);

        ocean = new OceanWaves(oceanShader);
        float seed = (float)(S.Num.I(city["map_seed"]) % 1000);
        foreach (WaterRect sheet in sheets)
        {
            Material mat = MakeMaterial(shader, sheet, seed, simCfg);
            materials.Add(mat);
            Mesh mesh = MakeMesh(sheet, simCfg);
            meshes.Add(mesh);
            VertexCount += mesh.vertexCount;
            Debug.Log($"rampage: water sheet x {sheet.x0:F0}..{sheet.x1:F0} z {sheet.z0:F0}..{sheet.z1:F0} y {sheet.y:F2} bay {sheet.bay} lap {sheet.lap} sim {mat.GetFloat("_SimOn")} verts {mesh.vertexCount}");
            var go = new GameObject("water");
            go.transform.SetParent(parent, false);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = go.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = mat;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.lightProbeUsage = LightProbeUsage.Off;
        }
    }

    static float F(S.Variant v) => (float)S.Num.F(v);
    static Vector4 Linear(string look) => SliceData.Hex(S.Gd.Str(S.Content.Look()[look])).linear;

    public void Step(float dt)
    {
        ocean.Step(dt);
        Fill(false);
        sim.water.splashes.Clear();
    }

    // ---- basins (scenes/water_view.gd) ----

    void MakeBasin(int n)
    {
        S.WaterBasin basin = sim.water.basins[n];
        int nx = (int)basin.nx, nz = (int)basin.nz;
        var h = new float[nx * nz * 2];  // (surface, ground) per column
        var l = new float[nx * nz];
        float[] floorY = basin.floorY.Raw;
        float rest = (float)basin.rest;
        for (int k = 0; k < nx * nz; k++)  // the bed never moves: its half is written once
        {
            float ground = Ground(floorY[k], rest);
            h[2 * k + 1] = ground;
            l[k] = ground + film;
        }
        heights[n] = h;
        low[n] = l;
        textures[n] = new Texture2D(nx, nz, TextureFormat.RGFloat, false, true)
        {
            wrapMode = TextureWrapMode.Clamp,
            filterMode = FilterMode.Bilinear,
        };
    }

    // A column's ground over the still water (land past the basin: the street).
    static float Ground(float floorY, float rest) => floorY < S.WaterSim.WALL ? floorY - rest : 0f;

    // Writes the moving basins' heights (all of them, the first time).
    void Fill(bool all)
    {
        for (int n = 0; n < textures.Length; n++)
        {
            S.WaterBasin basin = sim.water.basins[n];
            bool now = basin.active.HasArea();
            bool stirred = wasActive[n] && !now;  // its last, settled heights still to draw
            wasActive[n] = now;
            if (!all && !now && !stirred) continue;
            float[] h = heights[n], l = low[n];
            float[] floorY = basin.floorY.Raw, depth = basin.depth.Raw, body = basin.body.Raw;
            float rest = (float)basin.rest;
            int columns = (int)(basin.nx * basin.nz);
            for (int k = 0; k < columns; k++)
            {
                float d = depth[k];
                // dry: the still water, under the sand there, so the sand hides it; a film never sinks into the
                // sand under it (it reads as water)
                if (d > 0f) h[2 * k] = Mathf.Max(floorY[k] + d + body[k] - rest, l[k]);
                else if (body[k] > 0f) h[2 * k] = Around(basin, k, h[2 * k + 1]);
                else h[2 * k] = 0f;
            }
            textures[n].SetPixelData(h, 0);
            textures[n].Apply(false);
        }
    }

    // The water round a column his body has emptied: its wet neighbours' surface, so his path never cuts a square
    // notch in the waterline; ground if none.
    static float Around(S.WaterBasin basin, int k, float ground)
    {
        int nx = (int)basin.nx, nz = (int)basin.nz;
        int x = k % nx, z = k / nx;
        float[] floorY = basin.floorY.Raw, depth = basin.depth.Raw, body = basin.body.Raw;
        float rest = (float)basin.rest;
        float sum = 0f;
        int wet = 0;
        for (int dz = -2; dz <= 2; dz++)
        {
            for (int dx = -2; dx <= 2; dx++)
            {
                int ax = x + dx, az = z + dz;
                if (ax < 0 || az < 0 || ax >= nx || az >= nz) continue;
                int a = az * nx + ax;
                if (depth[a] > 0f)
                {
                    sum += floorY[a] + depth[a] + body[a] - rest;
                    wet++;
                }
            }
        }
        return wet > 0 ? sum / wet : ground;
    }

    // ---- sheets (scenes/water_surface.gd) ----

    Material MakeMaterial(Shader shader, WaterRect sheet, float seed, S.GDict simCfg)
    {
        S.GDict cfg = S.Content.Section("water");
        S.GDict kind = cfg[sheet.bay ? "bay" : "river"];
        var mat = new Material(shader) { renderQueue = TRANSPARENT_FIRST };
        mat.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
        // HDRP's transparent premultiplied state, the source's blend_premul_alpha, depth_draw_always, cull_back.
        mat.SetFloat("_SurfaceType", 1f);
        mat.SetFloat("_BlendMode", 4f);
        mat.SetFloat("_SrcBlend", (float)BlendMode.One);
        mat.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
        mat.SetFloat("_DstBlend2", (float)BlendMode.OneMinusSrcAlpha);
        mat.SetFloat("_AlphaSrcBlend", (float)BlendMode.One);
        mat.SetFloat("_AlphaDstBlend", (float)BlendMode.OneMinusSrcAlpha);
        mat.SetFloat("_ZWrite", 1f);
        mat.SetFloat("_CullModeForward", (float)CullMode.Back);
        mat.SetFloat("_ZTestDepthEqualForOpaque", (float)CompareFunction.LessEqual);
        mat.SetFloat("_EnableBlendModePreserveSpecularLighting", 1f);

        mat.SetVector("_WaterDeep", Linear("water"));
        mat.SetVector("_WaterShallow", Linear("water"));
        mat.SetVector("_WaterFoam", Linear("water_foam"));
        mat.SetVector("_WaterSky", Linear("ambient_color"));
        mat.SetFloat("_WaterNight", F(S.Content.Look()["window_lit"]));
        mat.SetFloat("_WaterAbsorb", F(cfg["absorb"]));
        mat.SetFloat("_WaterMurk", F(cfg["murk"]));
        mat.SetFloat("_WaterFoamDepth", F(cfg["foam_depth"]));
        mat.SetFloat("_WaterFoamShare", F(cfg["foam"]));
        mat.SetFloat("_RoughNear", F(cfg["rough_near"]));
        mat.SetFloat("_RoughFar", F(cfg["rough_far"]));
        mat.SetFloat("_WaterSpec", F(cfg["specular"]));
        mat.SetFloat("_CrestLight", F(cfg["crest_light"]));
        mat.SetFloat("_MottleLength", F(cfg["mottle_length"]));
        mat.SetFloat("_MottleAmp", F(cfg["mottle_amp"]));
        mat.SetFloat("_NightGlow", F(cfg["night_glow"]));
        mat.SetFloat("_DayGlow", F(cfg["day_glow"]));
        mat.SetFloat("_WaveLength", F(kind["wave_length"]));
        mat.SetFloat("_WaveSlope", F(kind["wave_slope"]));
        mat.SetFloat("_RippleLength", F(kind["ripple_length"]));
        mat.SetFloat("_RippleSlope", F(kind["ripple_slope"]));
        mat.SetFloat("_SwellLength", kind.Has("swell_length") ? F(kind["swell_length"]) : 0f);
        mat.SetFloat("_SwellSlope", kind.Has("swell_slope") ? F(kind["swell_slope"]) : 0f);
        mat.SetVector("_WaterWind", WIND.normalized);
        S.GDict lap = cfg["lap"];
        S.GArray<S.Variant> landward = lap["dir"];
        Vector2 dir = new Vector2(F(landward[0]), F(landward[1])).normalized;
        mat.SetVector("_SwellDir", dir);
        Vector2 along = sheet.x1 - sheet.x0 >= sheet.z1 - sheet.z0 ? Vector2.right : Vector2.up;
        mat.SetVector("_WaterFlow", along * (kind.Has("flow") ? F(kind["flow"]) : 0f));
        mat.SetFloat("_WaterSeed", seed);
        if (sheet.lap)
        {
            mat.SetFloat("_LapHeight", F(lap["height"]));
            mat.SetFloat("_LapLength", F(lap["length"]));
            mat.SetFloat("_LapPeriod", F(lap["period"]));
            mat.SetVector("_LapDir", dir);
        }
        else
        {
            mat.SetFloat("_LapHeight", 0f);
        }

        // Each sheet over a basin takes that basin's texture (the last it meets, as the source).
        var flat = new Rect(sheet.x0, sheet.z0, sheet.x1 - sheet.x0, sheet.z1 - sheet.z0);
        mat.SetFloat("_SimOn", 0f);
        mat.SetFloat("_OceanOn", 0f);
        for (int n = 0; n < textures.Length; n++)
        {
            S.WaterBasin basin = sim.water.basins[n];
            Vector2 origin = BasinOrigin(basin), size = BasinSize(basin);
            if (!flat.Overlaps(new Rect(origin, size))) continue;
            mat.SetTexture("_SimHeight", textures[n]);
            mat.SetVector("_SimOrigin", origin);
            mat.SetVector("_SimSize", size);
            mat.SetVector("_SimTexels", new Vector2(1f / basin.nx, 1f / basin.nz));
            mat.SetFloat("_SimOn", 1f);
            mat.SetFloat("_WhitecapSlope", F(simCfg["whitecap_slope"]));
            mat.SetFloat("_WhitecapLift", F(simCfg["whitecap_lift"]));
        }
        if (sheet.bay) ocean.Bind(mat);
        return mat;
    }

    static Vector2 BasinOrigin(S.WaterBasin b) => new Vector2((float)(double)b.origin.x, (float)(double)b.origin.y);
    static Vector2 BasinSize(S.WaterBasin b) => new Vector2((float)(b.nx * b.cell), (float)(b.nz * b.cell));

    Mesh MakeMesh(WaterRect sheet, S.GDict simCfg)
    {
        float[] xs, zs;
        if (sheet.lap)
        {
            S.GDict lap = S.Content.Section("water")["lap"];
            xs = Stops(sheet.x0, sheet.x1, sheet.x0, sheet.x1, F(lap["column"]));
            zs = Stops(sheet.z0, sheet.z1, sheet.z0, sheet.z1, F(lap["row"]));
            return Grid(sheet, xs, zs, F(lap["fade"]));
        }
        float cell = F(simCfg["cell"]);
        if (!sheet.bay)
        {
            xs = Stops(sheet.x0, sheet.x1, sheet.x0, sheet.x1, cell);
            zs = Stops(sheet.z0, sheet.z1, sheet.z0, sheet.z1, cell);
            return Grid(sheet, xs, zs, 0f);
        }
        Rect near = NearRect();
        xs = Stops(sheet.x0, sheet.x1, near.xMin, near.xMax, cell);
        zs = Stops(sheet.z0, sheet.z1, near.yMin, near.yMax, cell);
        return Grid(sheet, xs, zs, 0f);
    }

    // Every basin, and the margin the camera and the open sea's waves reach past them.
    Rect NearRect()
    {
        S.WaterBasin first = sim.water.basins[0];
        Vector2 min = BasinOrigin(first), max = min + BasinSize(first);
        foreach (S.WaterBasin b in sim.water.basins)
        {
            min = Vector2.Min(min, BasinOrigin(b));
            max = Vector2.Max(max, BasinOrigin(b) + BasinSize(b));
        }
        var margin = new Vector2(DENSE_MARGIN, DENSE_MARGIN);
        return Rect.MinMaxRect(min.x - margin.x, min.y - margin.y, max.x + margin.x, max.y + margin.y);
    }

    static float[] Stops(float lo, float hi, float denseLo, float denseHi, float cell)
    {
        var stops = new List<float>();
        double at = lo;
        while (at < hi)
        {
            stops.Add((float)at);
            double off = Math.Max(0.0, Math.Max(denseLo - at, at - denseHi));
            at += Math.Min(FAR_CELL, cell + off * FAR_GROWTH);
        }
        stops.Add(hi);
        return stops.ToArray();
    }

    static Mesh Grid(WaterRect sheet, float[] xs, float[] zs, float fade)
    {
        int cols = xs.Length, rows = zs.Length;
        var verts = new NativeArray<Vertex>(cols * rows, Allocator.Temp, NativeArrayOptions.UninitializedMemory);
        var index = new NativeArray<int>((cols - 1) * (rows - 1) * 6, Allocator.Temp, NativeArrayOptions.UninitializedMemory);
        int v = 0, t = 0;
        for (int r = 0; r < rows; r++)
        {
            float z = zs[r];
            byte tint = fade > 0f ? (byte)Mathf.RoundToInt(Mathf.Clamp01((z - sheet.z0) / fade) * 255f) : (byte)0;
            for (int c = 0; c < cols; c++)
            {
                verts[v++] = new Vertex
                {
                    position = new Vector3(xs[c], sheet.y, -z),
                    normal = NORMAL_UP,
                    tangent = TANGENT_X,
                    color = new Color32(tint, 0, 0, 255),
                    uv = new Vector2(xs[c], z),
                };
                if (r == rows - 1 || c == cols - 1) continue;
                int q = r * cols + c;
                index[t++] = q;
                index[t++] = q + 1;
                index[t++] = q + cols + 1;
                index[t++] = q;
                index[t++] = q + cols + 1;
                index[t++] = q + cols;
            }
        }
        var mesh = new Mesh { name = "water", indexFormat = IndexFormat.UInt32 };
        mesh.SetVertexBufferParams(verts.Length,
            new VertexAttributeDescriptor(VertexAttribute.Position, VertexAttributeFormat.Float32, 3),
            new VertexAttributeDescriptor(VertexAttribute.Normal, VertexAttributeFormat.SNorm8, 4),
            new VertexAttributeDescriptor(VertexAttribute.Tangent, VertexAttributeFormat.SNorm8, 4),
            new VertexAttributeDescriptor(VertexAttribute.Color, VertexAttributeFormat.UNorm8, 4),
            new VertexAttributeDescriptor(VertexAttribute.TexCoord0, VertexAttributeFormat.Float32, 2));
        const MeshUpdateFlags QUIET = MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices;
        mesh.SetVertexBufferData(verts, 0, 0, verts.Length, 0, QUIET);
        mesh.SetIndexBufferParams(index.Length, IndexFormat.UInt32);
        mesh.SetIndexBufferData(index, 0, 0, index.Length, QUIET);
        var bounds = new Bounds();
        bounds.SetMinMax(new Vector3(sheet.x0, sheet.y - BOUNDS_LIFT, -sheet.z1), new Vector3(sheet.x1, sheet.y + BOUNDS_LIFT, -sheet.z0));
        mesh.subMeshCount = 1;
        mesh.SetSubMesh(0, new SubMeshDescriptor(0, index.Length) { bounds = bounds, vertexCount = verts.Length }, QUIET);
        mesh.bounds = bounds;
        verts.Dispose();
        index.Dispose();
        return mesh;
    }

    public void Dispose()
    {
        ocean?.Dispose();
        foreach (Mesh m in meshes) UnityEngine.Object.Destroy(m);
        foreach (Material m in materials) UnityEngine.Object.Destroy(m);
        foreach (Texture2D t in textures) if (t != null) UnityEngine.Object.Destroy(t);
    }
}
