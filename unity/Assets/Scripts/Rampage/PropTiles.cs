using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// A field of small crushable voxel props, built new for Unity (D-474) in place of scenes/prop_field.gd: each prop is
// one of a few baked shapes at a spot, merged per ground tile as CityTrees merges its trees; a tile remakes its mesh
// when a prop in it is crushed. A crushed prop is gone (Godot flattens it; polish later, D-476). Presentation only.
public sealed class PropTiles
{
    const float TILE = 32f;

    sealed class Shape
    {
        public Vector3[] verts, normals;
        public Color32[] colors;
        public Vector2[] uvs;
        public int[] tris;
    }

    struct Prop
    {
        public Vector3 at;
        public int shape;
        public bool down;
    }

    sealed class Tile
    {
        public readonly List<int> props = new List<int>();
        public Mesh mesh;
        public bool dirty = true;
    }

    readonly Transform root;
    readonly Material material;
    readonly float voxel;
    readonly List<Shape> shapes = new List<Shape>();
    readonly List<Prop> props = new List<Prop>();
    readonly Dictionary<Vector2Int, Tile> tiles = new Dictionary<Vector2Int, Tile>();
    // Rects (Godot axes) nothing is planted in.
    public readonly List<S.Rect2> keepOut = new List<S.Rect2>();

    public int Count => props.Count;
    public int Crushed { get; private set; }

    // y: the field's height (its cells' y = 0 sits there).
    public PropTiles(string name, Shader shader, Transform parent, float voxel, float y)
    {
        this.voxel = voxel;
        root = new GameObject(name).transform;
        root.SetParent(parent, false);
        root.localPosition = new Vector3(0f, y, 0f);
        material = ArmyView.PlainMaterial(shader, voxel);
    }

    static Vector2Int Cell(float x, float z) => new Vector2Int(Mathf.FloorToInt(x / TILE), Mathf.FloorToInt(z / TILE));

    public static void Box(Dictionary<Vector3Int, int> cells, Vector3Int a, Vector3Int b, int color)
    {
        for (int x = Mathf.Min(a.x, b.x); x <= Mathf.Max(a.x, b.x); x++)
            for (int y = Mathf.Min(a.y, b.y); y <= Mathf.Max(a.y, b.y); y++)
                for (int z = Mathf.Min(a.z, b.z); z <= Mathf.Max(a.z, b.z); z++)
                    cells[new Vector3Int(x, y, z)] = color;
    }

    // Every cell whose centre lies in the ellipsoid (scenes/voxel_builder.gd blob).
    public static void Blob(Dictionary<Vector3Int, int> cells, Vector3 centre, Vector3 radii, int color)
    {
        Vector3Int lo = Vector3Int.FloorToInt(centre - radii), hi = Vector3Int.CeilToInt(centre + radii);
        for (int x = lo.x; x <= hi.x; x++)
            for (int y = lo.y; y <= hi.y; y++)
                for (int z = lo.z; z <= hi.z; z++)
                {
                    Vector3 d = new Vector3(x, y, z) - centre;
                    d = new Vector3(d.x / radii.x, d.y / radii.y, d.z / radii.z);
                    if (d.sqrMagnitude <= 1f) cells[new Vector3Int(x, y, z)] = color;
                }
    }

    public static ModelColors.Model Model(Dictionary<Vector3Int, int> cells)
    {
        var model = new ModelColors.Model { xyz = new S.PackedInt32Array(), rgb = new int[cells.Count] };
        model.xyz.Resize(cells.Count * 3);
        int[] raw = model.xyz.Raw;
        int i = 0;
        foreach (KeyValuePair<Vector3Int, int> cell in cells)
        {
            raw[i * 3] = cell.Key.x;
            raw[i * 3 + 1] = cell.Key.y;
            raw[i * 3 + 2] = cell.Key.z;
            model.rgb[i++] = cell.Value;
        }
        return model;
    }

    // A shape from its cells (Godot axes, colours 0xrrggbb); returns its index for Add.
    public int AddShape(Dictionary<Vector3Int, int> cells)
    {
        Mesh mesh = ArmyView.Faces(Model(cells), voxel, Vector3.zero);
        var uvs = new List<Vector2>();
        mesh.GetUVs(0, uvs);
        shapes.Add(new Shape { verts = mesh.vertices, normals = mesh.normals, colors = mesh.colors32, uvs = uvs.ToArray(), tris = mesh.triangles });
        Object.Destroy(mesh);
        return shapes.Count - 1;
    }

    // A prop of `shape` at p (Godot axes x, z), snapped to the voxel grid; false inside a keep-out rect.
    public bool Add(Vector2 p, int shape)
    {
        var q = new S.Vector2(p.x, p.y);
        foreach (S.Rect2 r in keepOut)
            if (r.HasPoint(q)) return false;
        var at = new Vector3(Mathf.Round(p.x / voxel) * voxel, 0f, -Mathf.Round(p.y / voxel) * voxel);
        Vector2Int t = Cell(at.x, at.z);
        if (!tiles.TryGetValue(t, out Tile tile)) tiles[t] = tile = new Tile();
        tile.props.Add(props.Count);
        props.Add(new Prop { at = at, shape = shape });
        return true;
    }

    // Every prop's base in Godot axes (x, -z), as diagonal_parking.gd _props_near reads CityDecor's.
    public List<S.Vector2> Bases()
    {
        var bases = new List<S.Vector2>(props.Count);
        foreach (Prop prop in props) bases.Add(new S.Vector2(prop.at.x, -prop.at.z));
        return bases;
    }

    readonly List<Vector3> vBuf = new List<Vector3>(), nBuf = new List<Vector3>();
    readonly List<Color32> cBuf = new List<Color32>();
    readonly List<Vector2> uBuf = new List<Vector2>();
    readonly List<int> tBuf = new List<int>();

    void Remake(Tile tile)
    {
        tile.dirty = false;
        vBuf.Clear();
        nBuf.Clear();
        cBuf.Clear();
        uBuf.Clear();
        tBuf.Clear();
        foreach (int index in tile.props)
        {
            Prop prop = props[index];
            if (prop.down) continue;
            Shape shape = shapes[prop.shape];
            int at = vBuf.Count;
            foreach (Vector3 v in shape.verts) vBuf.Add(v + prop.at);
            nBuf.AddRange(shape.normals);
            cBuf.AddRange(shape.colors);
            uBuf.AddRange(shape.uvs);
            foreach (int t in shape.tris) tBuf.Add(t + at);
        }
        if (tile.mesh == null)
        {
            tile.mesh = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
            var go = new GameObject("tile");
            go.transform.SetParent(root, false);
            go.AddComponent<MeshFilter>().sharedMesh = tile.mesh;
            go.AddComponent<MeshRenderer>().sharedMaterial = material;
        }
        tile.mesh.Clear();
        tile.mesh.SetVertices(vBuf);
        tile.mesh.SetNormals(nBuf);
        tile.mesh.SetColors(cBuf);
        tile.mesh.SetUVs(0, uBuf);
        tile.mesh.SetTriangles(tBuf, 0);
    }

    // Every prop whose base lies within `radius` of `at` (Godot axes) goes; returns how many, and where the first was.
    public int Crush(Vector3 at, float radius, out Vector3 first)
    {
        first = at;
        int n = 0;
        var unity = new Vector3(at.x, 0f, -at.z);
        Vector2Int lo = Cell(unity.x - radius, unity.z - radius), hi = Cell(unity.x + radius, unity.z + radius);
        for (int x = lo.x; x <= hi.x; x++)
            for (int z = lo.y; z <= hi.y; z++)
            {
                if (!tiles.TryGetValue(new Vector2Int(x, z), out Tile tile)) continue;
                foreach (int index in tile.props)
                {
                    Prop prop = props[index];
                    if (prop.down || (prop.at - unity).magnitude > radius) continue;
                    prop.down = true;
                    props[index] = prop;
                    tile.dirty = true;
                    if (n++ == 0) first = new Vector3(prop.at.x, at.y, -prop.at.z);
                }
            }
        Crushed += n;
        return n;
    }

    // Remakes the tiles a crush touched; call once a frame.
    public void Tick()
    {
        foreach (Tile tile in tiles.Values)
            if (tile.dirty) Remake(tile);
    }

    public void Dispose()
    {
        foreach (Tile tile in tiles.Values)
            if (tile.mesh != null) Object.Destroy(tile.mesh);
        Object.Destroy(material);
    }
}
