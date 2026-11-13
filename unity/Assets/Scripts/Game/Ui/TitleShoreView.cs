// The title's near shore and the far one's edge (scenes/title_shore.gd), built in Godot's axes and drawn in
// Unity's (z negated): the far sea wall, its cap and the lit promenade, the promenade's lamp posts (their heads
// are glows, TitleFxView), the far shore's windows and fires reflected on the bay (TITLE_REFLECT), the near
// beach of the game's sand sloping into the bay (TITLE_SAND) and the shallows over its lip, the shallows and the
// reflections rising and falling with the game's lap (tuning water.lap). Shaders: Resources/Shaders/TitleFx.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

public sealed class TitleShoreView : IDisposable
{
    // title_shore.gd
    const float PROMENADE = 9f, WATER_Y = -0.8f, TIDE_LIFT = 0.03f, SHEET_LIFT = 0.04f;
    const float WALL_DEPTH = 1.4f, CAP_DEPTH = 2f, PROMENADE_HEIGHT = 0.3f, PROMENADE_BACK = 2f;
    const float POST_WIDTH = 0.3f, POST_FOOT = 0.3f;
    const string POST_COLOR = "1a1a20";
    const int MAX_FIRES = 12;
    const double SWELL_SHORT = 0.37;
    // harbour_view.gd: a grain is one city voxel, GRAIN_TILE grains to the texture's side, each shade straying
    // GRAIN_SHADE of its lightness, from the same seeded stream every run.
    const float GRAIN = 0.125f, GRAIN_SHADE = 0.065f;
    const int GRAIN_TILE = 64, GRAIN_SEED = 7301;
    const int QUAD_VERTS = 6;
    const float BOUNDS = 4000f;

    // A lamp head's glow (Godot axes): where, how big, its colour.
    public struct Head { public Vector3 at; public float size; }

    public readonly List<Head> heads = new List<Head>();
    public readonly Color lampColor;

    readonly S.GDict cfg, lap;
    readonly Shader shader;
    readonly Transform root;
    readonly List<(Transform node, float rest)> tide = new List<(Transform node, float rest)>();
    readonly List<Material> mats = new List<Material>();
    readonly List<Mesh> meshes = new List<Mesh>();
    readonly Material reflect, sand;
    readonly Texture2D grains;
    readonly float sheetRest, sheetLength;
    readonly Vector4 sheet;
    float time;

    // shoreZ: the far shore's front edge; coastZ: the play area's quay; cam: the title camera (Godot axes); fires:
    // the burning district's fire xs (TitleCity.District.lit); ripple: tuning title ripple; water: the variant's.
    public TitleShoreView(S.GDict cfg, float shoreZ, float coastZ, Vector3 cam, List<double> fires, S.GDict ripple, S.GDict water, Shader shader, Transform parent)
    {
        this.cfg = cfg;
        this.shader = shader;
        lap = S.Content.Section("water")["lap"];
        root = new GameObject("TitleShore").transform;
        root.SetParent(parent, false);
        float span = F(cfg, "half_span"), top = F(cfg, "wall_top");
        Walls(span, top, shoreZ);
        lampColor = Hex(cfg["lamp_color"]);
        Lamps(span, top, shoreZ);
        sheetLength = F(cfg, "reflect_length");
        sheetRest = WATER_Y + SHEET_LIFT;
        sheet = new Vector4(span, sheetRest, shoreZ, shoreZ + sheetLength);
        reflect = Reflect(shoreZ, cam, fires, ripple);
        grains = Grains(Hex(S.Content.Look()["sand"]));
        sand = Beach(span, coastZ, fires, water);
    }

    static float F(S.GDict d, string key) => (float)S.Num.F(d[key]);

    static Color Hex(S.Variant v) => SliceData.Hex(S.Gd.Str(v));

    void Walls(float span, float top, float shoreZ)
    {
        Color glow = Hex(cfg["promenade_glow"]);
        float energy = F(cfg, "promenade_energy");
        Solid("Wall", Box(new Vector3(span * 2f, top - WATER_Y, WALL_DEPTH), new Vector3(0f, (top + WATER_Y) * 0.5f, shoreZ - WALL_DEPTH * 0.5f)),
            Hex(cfg["wall_color"]), Color.black, 0f);
        float cap = F(cfg, "cap_height");
        Solid("Cap", Box(new Vector3(span * 2f, cap, CAP_DEPTH), new Vector3(0f, top + cap * 0.5f, shoreZ - CAP_DEPTH * 0.5f)),
            Hex(cfg["cap_color"]), glow, energy);
        Solid("Promenade", Box(new Vector3(span * 2f, PROMENADE_HEIGHT, PROMENADE),
            new Vector3(0f, top + PROMENADE_HEIGHT * 0.5f, shoreZ - PROMENADE_BACK - PROMENADE * 0.5f)), Hex(cfg["promenade_color"]), glow, energy);
    }

    // The posts as one mesh; the heads are listed for the glow pass.
    void Lamps(float span, float top, float shoreZ)
    {
        float height = F(cfg, "lamp_height"), z = shoreZ - F(cfg, "lamp_back"), glow = F(cfg, "lamp_glow");
        var posts = new List<Mesh>();
        foreach (S.Vector2 spot in TitleCity.Lamps(cfg, span))
        {
            float x = (float)spot.x;
            posts.Add(Box(new Vector3(POST_WIDTH, height, POST_WIDTH), new Vector3(x, top + POST_FOOT + height * 0.5f, z)));
            heads.Add(new Head { at = new Vector3(x, top + POST_FOOT + height, z), size = glow * (float)spot.y });
        }
        var combine = new CombineInstance[posts.Count];
        for (int i = 0; i < posts.Count; i++) combine[i] = new CombineInstance { mesh = posts[i], transform = Matrix4x4.identity };
        var all = new Mesh { indexFormat = IndexFormat.UInt32 };
        all.CombineMeshes(combine, true, false);
        foreach (Mesh m in posts) UnityEngine.Object.Destroy(m);
        Solid("LampPosts", all, SliceData.Hex(POST_COLOR), Color.black, 0f);
    }

    // _lit_material on a node: albedo, emission at `energy` (none at 0), fogged.
    Transform Solid(string name, Mesh mesh, Color albedo, Color glow, float energy)
    {
        var mat = Make("TITLE_SOLID", BlendMode.One, BlendMode.Zero, true, (int)RenderQueue.Geometry);
        mat.SetVector("_SolidColor", albedo.linear);
        mat.SetVector("_SolidEmit", energy > 0f ? glow.linear * energy : Color.black);
        return Node(name, mesh, mat);
    }

    Transform Node(string name, Mesh mesh, Material mat)
    {
        var go = new GameObject(name);
        go.transform.SetParent(root, false);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var r = go.AddComponent<MeshRenderer>();
        r.sharedMaterial = mat;
        r.shadowCastingMode = ShadowCastingMode.Off;
        r.receiveShadows = false;
        if (!meshes.Contains(mesh)) meshes.Add(mesh);
        return go.transform;
    }

    Material Make(string keyword, BlendMode src, BlendMode dst, bool zwrite, int queue)
    {
        var mat = new Material(shader) { renderQueue = queue };
        mat.EnableKeyword(keyword);
        mat.SetFloat("_SrcBlend", (float)src);
        mat.SetFloat("_DstBlend", (float)dst);
        mat.SetFloat("_ZWrite", zwrite ? 1f : 0f);
        mats.Add(mat);
        return mat;
    }

    // The far shore on the bay (title_shore.gdshader): additive, drawn procedurally over the sheet each frame.
    Material Reflect(float shoreZ, Vector3 cam, List<double> fires, S.GDict ripple)
    {
        var mat = Make("TITLE_REFLECT", BlendMode.One, BlendMode.One, false, (int)RenderQueue.Transparent);
        mat.SetVector("_WindowColour", Hex(cfg["window_reflect"]).linear);
        mat.SetVector("_FireColour", Hex(cfg["fire_reflect"]).linear);
        mat.SetVector("_ShoreCam", new Vector4(shoreZ, cam.x, cam.z, sheetLength));
        mat.SetVector("_Lengths", new Vector4(F(cfg, "window_length"), F(cfg, "fire_length"), F(cfg, "window_strength"), F(cfg, "fire_strength")));
        mat.SetVector("_Ripple", new Vector4(F(cfg, "fire_radius"), (float)(1.0 / TitleCity.FAR_GRAIN), F(ripple, "amplitude"), F(ripple, "glow")));
        int count = Mathf.Min(fires.Count, MAX_FIRES);
        var xs = new Vector4[MAX_FIRES / 4];
        for (int i = 0; i < count; i++) xs[i / 4][i % 4] = (float)fires[i];
        mat.SetVectorArray("_FireX", xs);
        mat.SetVector("_Shiver", new Vector4(0f, count, 0f, 0f));
        return mat;
    }

    // _beach: the sand strip from under the picture's bottom edge into the bay, the shallows over its lip.
    Material Beach(float span, float coastZ, List<double> fires, S.GDict water)
    {
        float nearZ = coastZ - F(cfg, "beach_from"), depth = F(cfg, "beach_depth"), under = F(cfg, "beach_under");
        float beachTop = F(cfg, "beach_top"), grade = (beachTop - WATER_Y) / depth;
        Material sandMat = SandMaterial(grade, fires);
        Node("Beach", BeachMesh(span, nearZ, depth, under, beachTop, grade), sandMat);
        var shallows = Node("Shallows", Plane(span * 2f, under * 2f), null);
        var mat = Make("TITLE_SOLID", BlendMode.One, BlendMode.Zero, true, (int)RenderQueue.Geometry);
        mat.SetVector("_SolidColor", Hex(water["color"]).linear);
        mat.SetVector("_SolidEmit", Color.black);
        shallows.GetComponent<MeshRenderer>().sharedMaterial = mat;
        shallows.localPosition = new Vector3(0f, WATER_Y + TIDE_LIFT, -(nearZ - depth));
        tide.Add((shallows, WATER_Y + TIDE_LIFT));
        return sandMat;
    }

    Mesh BeachMesh(float span, float nearZ, float depth, float under, float beachTop, float grade)
    {
        double[] phase = TitleCity.BeachPhases();
        float step = F(cfg, "beach_step"), wander = F(cfg, "beach_wander");
        double length = S.Num.F(cfg["beach_wander_length"]);
        int cols = Mathf.CeilToInt(span * 2f / step) + 1, rows = Mathf.CeilToInt(depth + under) + 1;
        var v = new Vector3[cols * rows];
        var uv = new Vector2[v.Length];
        for (int j = 0; j < rows; j++)
        {
            float back = Mathf.Min(j, depth + under);
            for (int i = 0; i < cols; i++)
            {
                float x = -span + i * step;
                float swell = (float)(Math.Sin(x / length + phase[0]) + 0.5 * Math.Sin(x / (length * SWELL_SHORT) + phase[1]));
                var at = new Vector3(x, beachTop - grade * back + wander * swell, nearZ - back);
                uv[j * cols + i] = new Vector2(at.x, at.z) / (GRAIN * GRAIN_TILE);
                v[j * cols + i] = new Vector3(at.x, at.y, -at.z);
            }
        }
        var tris = new int[(cols - 1) * (rows - 1) * QUAD_VERTS];
        int n = 0;
        for (int j = 0; j < rows - 1; j++)
            for (int i = 0; i < cols - 1; i++)
            {
                int a = j * cols + i;
                foreach (int k in new[] { a, a + cols, a + 1, a + 1, a + cols, a + cols + 1 }) tris[n++] = k;
            }
        var mesh = new Mesh { indexFormat = IndexFormat.UInt32, vertices = v, uv = uv, triangles = tris };
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();
        return mesh;
    }

    // _sand_material: the game's grains and wet line at night, the burning district's light on it.
    Material SandMaterial(float grade, List<double> fires)
    {
        var mat = Make("TITLE_SAND", BlendMode.One, BlendMode.Zero, true, (int)RenderQueue.Geometry);
        mat.SetTexture("_Grains", grains);
        mat.SetVector("_SandWet", new Vector4(F(lap, "wet_width"), F(lap, "wet_dark"), F(cfg, "beach_night"), grade));
        // title_sand.gdshader's defaults the gd never sets: foam 0.8 and fire_width 260; fire_x 60 with no fires.
        double fireX = TitleSandDefaults.FIRE_X;
        if (fires.Count > 0)
        {
            double total = 0.0;
            foreach (double x in fires) total += x;
            fireX = total / fires.Count;
        }
        mat.SetVector("_SandTide", new Vector4(WATER_Y + TIDE_LIFT, F(cfg, "beach_foam_width"), TitleSandDefaults.FOAM, (float)fireX));
        Color fire = Hex(cfg["fire_reflect"]).linear;
        mat.SetVector("_SandFire", new Vector4(fire.r, fire.g, fire.b, F(cfg, "beach_fire")));
        mat.SetVector("_SandReach", new Vector4(TitleSandDefaults.FIRE_WIDTH, F(cfg, "beach_fire_reach"), 0f, 0f));
        mat.SetVector("_FoamColor", Hex(cfg["beach_foam"]).linear);
        return mat;
    }

    // HarbourView._grains: the sand's colour, each grain lightened or darkened a little, nearest-filtered, sRGB.
    static Texture2D Grains(Color sand)
    {
        var tex = new Texture2D(GRAIN_TILE, GRAIN_TILE, TextureFormat.RGB24, true, false)
        {
            filterMode = FilterMode.Point, wrapMode = TextureWrapMode.Repeat,
        };
        var rng = new S.RandomNumberGenerator { seed = GRAIN_SEED };
        var px = new Color[GRAIN_TILE * GRAIN_TILE];
        // Godot's image rows run down and its v does too: row y of the image is the row v samples in both.
        for (int y = 0; y < GRAIN_TILE; y++)
            for (int x = 0; x < GRAIN_TILE; x++)
            {
                float p = (float)rng.RandfRange(-GRAIN_SHADE, GRAIN_SHADE);
                px[y * GRAIN_TILE + x] = new Color(sand.r + (1f - sand.r) * p, sand.g + (1f - sand.g) * p, sand.b + (1f - sand.b) * p, 1f);
            }
        tex.SetPixels(px);
        tex.Apply(true, true);
        return tex;
    }

    // A box `size` round `centre` (Godot axes), as a Unity mesh.
    static Mesh Box(Vector3 size, Vector3 centre)
    {
        Mesh cube = SliceGame.CubeMesh(1f, false);
        var v = cube.vertices;
        for (int i = 0; i < v.Length; i++) v[i] = new Vector3(centre.x + v[i].x * size.x, centre.y + v[i].y * size.y, -centre.z + v[i].z * size.z);
        cube.vertices = v;
        cube.RecalculateBounds();
        return cube;
    }

    // A flat plane `width` by `depth` round the origin, facing up.
    static Mesh Plane(float width, float depth)
    {
        float x = width * 0.5f, z = depth * 0.5f;
        var mesh = new Mesh
        {
            vertices = new[] { new Vector3(-x, 0f, -z), new Vector3(-x, 0f, z), new Vector3(x, 0f, z), new Vector3(x, 0f, -z) },
            normals = new[] { Vector3.up, Vector3.up, Vector3.up, Vector3.up },
            triangles = new[] { 0, 1, 2, 0, 2, 3 },
        };
        mesh.RecalculateBounds();
        return mesh;
    }

    // _process and set_shiver: the lap's rise this frame on the shallows, the sheet and the sand's tide line.
    public void Step(float dt, float shiver)
    {
        time += dt;
        float rise = F(lap, "height") * (0.5f + 0.5f * Mathf.Sin(2f * Mathf.PI * time / F(lap, "period")));
        foreach ((Transform node, float rest) in tide) node.localPosition = new Vector3(node.localPosition.x, rest + rise, node.localPosition.z);
        Vector4 tideLine = sand.GetVector("_SandTide");
        tideLine.x = WATER_Y + TIDE_LIFT + rise;
        sand.SetVector("_SandTide", tideLine);
        Vector4 shake = reflect.GetVector("_Shiver");
        shake.x = shiver;
        reflect.SetVector("_Shiver", shake);
        reflect.SetVector("_Sheet", new Vector4(sheet.x, sheetRest + rise, sheet.z, sheet.w));
        var bounds = new Bounds(Vector3.zero, Vector3.one * BOUNDS);
        Graphics.DrawProcedural(reflect, bounds, MeshTopology.Triangles, QUAD_VERTS, 1, null, null, ShadowCastingMode.Off, false, 0);
    }

    public void Dispose()
    {
        foreach (Material m in mats) UnityEngine.Object.Destroy(m);
        foreach (Mesh m in meshes) UnityEngine.Object.Destroy(m);
        if (grains != null) UnityEngine.Object.Destroy(grains);
        if (root != null) UnityEngine.Object.Destroy(root.gameObject);
    }
}

// title_sand.gdshader's uniform defaults that title_shore.gd never sets.
static class TitleSandDefaults
{
    public const float FOAM = 0.8f, FIRE_WIDTH = 260f, FIRE_X = 60f;
}
