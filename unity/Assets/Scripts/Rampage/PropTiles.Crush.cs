using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using N = System.Numerics;

// A prop going down (scenes/prop_field.gd crush, crush_box, _crush_group): each drawn cell becomes its own cube, a
// car's, bush's or lamp's flattened where it stands, an umbrella's pole and canopy (its fold colours) closed on the
// pole and fallen over away from the blow (GameLogic/PropCrush.cs, checked against Godot by SimTests/PropCrushCheck.cs).
// Godot hides a cell buried in its tile's merged cells; here a cell buried in its own prop's.
public sealed partial class PropTiles
{
    struct CrushCell
    {
        // From the prop's base in Godot axes: _index's origin, (cell + 0.5 up) * voxel.
        public N.Vector3 origin;
        public int color;
        public bool folds;
    }

    readonly List<CrushCell[]> shapeCells = new List<CrushCell[]>();
    // One cube a voxel wide per colour, centred on its origin.
    readonly Dictionary<int, Shape> cubes = new Dictionary<int, Shape>();

    void Keep(Dictionary<Vector3Int, int> cells, ICollection<int> folds)
    {
        var drawn = new List<CrushCell>();
        foreach (KeyValuePair<Vector3Int, int> cell in cells)
        {
            Vector3Int c = cell.Key;
            if (Buried(cells, c)) continue;
            drawn.Add(new CrushCell
            {
                origin = new N.Vector3(c.x, c.y + 0.5f, c.z) * voxel, color = cell.Value, folds = folds != null && folds.Contains(cell.Value),
            });
        }
        shapeCells.Add(drawn.ToArray());
    }

    static bool Buried(Dictionary<Vector3Int, int> cells, Vector3Int c) =>
        cells.ContainsKey(c + Vector3Int.right) && cells.ContainsKey(c + Vector3Int.left) && cells.ContainsKey(c + Vector3Int.up)
        && cells.ContainsKey(c + Vector3Int.down) && cells.ContainsKey(c + new Vector3Int(0, 0, 1)) && cells.ContainsKey(c + new Vector3Int(0, 0, -1));

    // crush_box: every prop whose base lies in the walking body's ground box (`body` in Godot axes, row-vector), crushed
    // from the body's origin; returns how many.
    public int CrushBox(N.Matrix4x4 body, FootRect foot)
    {
        float reach = PropCrush.Reach(body, foot);
        var middle = new Vector3(body.M41, 0f, -body.M43);
        var blow = new Vector3(body.M41, body.M42, body.M43);
        int n = 0;
        Vector2Int lo = Cell(middle.x - reach, middle.z - reach), hi = Cell(middle.x + reach, middle.z + reach);
        for (int x = lo.x; x <= hi.x; x++)
            for (int z = lo.y; z <= hi.y; z++)
            {
                if (!tiles.TryGetValue(new Vector2Int(x, z), out Tile tile)) continue;
                foreach (int index in tile.props)
                {
                    Prop prop = props[index];
                    if (prop.down || !PropCrush.Under(body, foot, new N.Vector3(prop.at.x, 0f, -prop.at.z))) continue;
                    Down(index, tile, blow);
                    n++;
                }
            }
        Crushed += n;
        return n;
    }

    // _crush_group: the prop goes down, its cells laid out from the blow at `at` (Godot axes).
    void Down(int index, Tile tile, Vector3 at)
    {
        Prop prop = props[index];
        prop.down = true;
        prop.flat = Flat(prop, new N.Vector3(at.x, at.y, at.z));
        props[index] = prop;
        tile.dirty = true;
    }

    Shape Flat(Prop prop, N.Vector3 at)
    {
        var baseAt = new N.Vector3(prop.at.x, 0f, -prop.at.z);
        N.Vector3 outward = PropCrush.Out(baseAt, at), foot = PropCrush.Foot(baseAt, voxel);
        CrushCell[] cells = shapeCells[prop.shape];
        var verts = new List<Vector3>();
        var normals = new List<Vector3>();
        var colors = new List<Color32>();
        var uvs = new List<Vector2>();
        var tris = new List<int>();
        foreach (CrushCell c in cells)
        {
            CellPose pose = PropCrush.Cell(baseAt + c.origin, c.folds, foot, outward, voxel);
            Shape cube = Cube(c.color);
            var centre = new Vector3(pose.origin.X, pose.origin.Y, -pose.origin.Z);
            var size = new Vector3(pose.scale.X, pose.scale.Y, pose.scale.Z) * voxel;
            int first = verts.Count;
            foreach (Vector3 v in cube.verts) verts.Add(centre + Vector3.Scale(v, size));
            normals.AddRange(cube.normals);
            colors.AddRange(cube.colors);
            uvs.AddRange(cube.uvs);
            foreach (int t in cube.tris) tris.Add(t + first);
        }
        return new Shape { verts = verts.ToArray(), normals = normals.ToArray(), colors = colors.ToArray(), uvs = uvs.ToArray(), tris = tris.ToArray() };
    }

    Shape Cube(int color)
    {
        if (cubes.TryGetValue(color, out Shape cube)) return cube;
        Mesh mesh = ArmyView.Faces(Model(new Dictionary<Vector3Int, int> { [Vector3Int.zero] = color }), 1f, new Vector3(0f, 0.5f, 0f));
        var uvs = new List<Vector2>();
        mesh.GetUVs(0, uvs);
        cube = new Shape { verts = mesh.vertices, normals = mesh.normals, colors = mesh.colors32, uvs = uvs.ToArray(), tris = mesh.triangles };
        Object.Destroy(mesh);
        cubes[color] = cube;
        return cube;
    }
}
