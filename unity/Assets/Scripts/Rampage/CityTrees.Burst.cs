using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using N = System.Numerics;
using S = Kaiju.Sim;

// A tree going down (scenes/prop_field.gd crush, crush_box, _burst and throw): its stump stays, the top row of it
// showing cut wood (stump_color); everything above goes, thrown as bark and leaf pieces into two DebrisFields
// (GameLogic/TreeBurst.cs, checked against Godot by SimTests/PropCrushCheck.cs), with two soft dust puffs over the
// stump. The burst's maths runs in Godot axes; a tree's cells sit at (cell + 0.5 up) * VOXEL from its base there.
public sealed partial class CityTrees
{
    // prop_field.gd: the debris fields' caps.
    const int LEAF_CAP = 160, BARK_CAP = 60;
    // throw: the two puffs sit this share of the puff size either side of the stump.
    const float PUFF_SIDE = 0.25f;
    const int HEX = 16;
    static readonly float[] PUFF_SIDES = { -1f, 1f };

    // Each shape's drawn (not buried) cells in the order it was built, and its stump's mesh.
    readonly List<BurstCell[]> shapeCells = new List<BurstCell[]>();
    readonly List<Shape> stumps = new List<Shape>();
    // prop_field.gd's tree_burst stream: where in its crown each leaf starts.
    readonly S.RandomNumberGenerator burstRng = S.Seeds.Make("tree_burst");
    readonly List<BurstPiece> thrown = new List<BurstPiece>();
    readonly List<Vector3> fallen = new List<Vector3>();
    readonly List<BurstCell> placed = new List<BurstCell>();
    DebrisField leafField, barkField;

    // Bakes a shape and keeps what its burst needs: the drawn cells, and the stump (cells under TreeBurst.STUMP,
    // the top row in stump_color).
    Shape Keep(Dictionary<Vector3Int, int> cells)
    {
        int cutWood = System.Convert.ToInt32(S.Gd.Str(city["stump_color"]), HEX);
        var drawn = new List<BurstCell>();
        var stump = new Dictionary<Vector3Int, int>();
        foreach (KeyValuePair<Vector3Int, int> cell in cells)
        {
            Vector3Int c = cell.Key;
            if (TreeBurst.Stands(c.y)) stump[c] = TreeBurst.CutTop(c.y) ? cutWood : cell.Value;
            if (Buried(cells, c)) continue;
            drawn.Add(new BurstCell { origin = new N.Vector3(c.x, c.y + 0.5f, c.z) * VOXEL, height = c.y, bark = cell.Value == BARK });
        }
        shapeCells.Add(drawn.ToArray());
        stumps.Add(Bake(stump));
        return Bake(cells);
    }

    // prop_field.gd _index: a cell with all six neighbours is never drawn.
    static bool Buried(Dictionary<Vector3Int, int> cells, Vector3Int c) =>
        cells.ContainsKey(c + Vector3Int.right) && cells.ContainsKey(c + Vector3Int.left) && cells.ContainsKey(c + Vector3Int.up)
        && cells.ContainsKey(c + Vector3Int.down) && cells.ContainsKey(c + new Vector3Int(0, 0, 1)) && cells.ContainsKey(c + new Vector3Int(0, 0, -1));

    static Vector3 Godot(Vector3 unity) => new Vector3(unity.x, unity.y, -unity.z);

    // crush: every tree whose base lies within `radius` of `at` (Godot axes) goes down.
    public void Crush(Vector3 at, float radius)
    {
        Vector3 unity = Godot(at);
        unity.y = 0f;
        Vector2Int lo = Cell(unity.x - radius, unity.z - radius, TILE), hi = Cell(unity.x + radius, unity.z + radius, TILE);
        for (int x = lo.x; x <= hi.x; x++)
            for (int z = lo.y; z <= hi.y; z++)
                if (tiles.TryGetValue(new Vector2Int(x, z), out Tile tile))
                    foreach (int index in tile.trees)
                        if (!trees[index].down && (trees[index].at - unity).magnitude <= radius) Fell(index, tile, at);
    }

    // crush_box: every tree whose base lies in the walking body's ground box (`body` in Godot axes, row-vector).
    public void CrushBox(N.Matrix4x4 body, FootRect foot)
    {
        float reach = PropCrush.Reach(body, foot);
        var middle = new Vector3(body.M41, 0f, -body.M43);
        Vector2Int lo = Cell(middle.x - reach, middle.z - reach, TILE), hi = Cell(middle.x + reach, middle.z + reach, TILE);
        for (int x = lo.x; x <= hi.x; x++)
            for (int z = lo.y; z <= hi.y; z++)
                if (tiles.TryGetValue(new Vector2Int(x, z), out Tile tile))
                    foreach (int index in tile.trees)
                    {
                        Vector3 b = Godot(trees[index].at);
                        if (!trees[index].down && PropCrush.Under(body, foot, new N.Vector3(b.x, b.y, b.z))) Fell(index, tile, new Vector3(body.M41, body.M42, body.M43));
                    }
    }

    // _burst: the tree goes down to its stump and its pieces wait for the next throw.
    void Fell(int index, Tile tile, Vector3 at)
    {
        Tree tree = trees[index];
        tree.down = true;
        trees[index] = tree;
        tile.dirty = true;
        Vector3 b = Godot(tree.at);
        var treeBase = new N.Vector3(b.x, b.y, b.z);
        placed.Clear();
        foreach (BurstCell c in shapeCells[tree.shape]) placed.Add(new BurstCell { origin = c.origin + treeBase, height = c.height, bark = c.bark });
        var tuning = new BurstTuning
        {
            throwSpeed = F(city, "tree_debris_speed"), leafSpeed = F(city, "tree_leaf_speed"), leafSpread = F(city, "tree_leaf_spread"),
        };
        TreeBurst.Burst(placed, treeBase, new N.Vector3(at.x, at.y, at.z), VOXEL, tuning, burstRng, thrown);
        fallen.Add(b);
    }

    // throw: the pieces into their fields, then two puffs over each stump.
    void Throw()
    {
        if (thrown.Count == 0 && fallen.Count == 0) return;
        if (leafField == null) DebrisField.Ground(root);
        leafField ??= new DebrisField(S.Seeds.Make("tree_leaf"), LEAF_CAP, F(city, "tree_debris_size"), false, material, root, "leaf debris");
        barkField ??= new DebrisField(S.Seeds.Make("tree_bark"), BARK_CAP, F(city, "tree_bark_size"), false, material, root, "bark debris");
        foreach (BurstPiece p in thrown)
            (p.bark ? barkField : leafField).Spawn(new Vector3(p.from.X, p.from.Y, p.from.Z), p.bark ? barkChunk : leafChunk,
                new Vector3(p.away.X, p.away.Y, p.away.Z));
        thrown.Clear();
        float size = F(city, "tree_puff_size"), alpha = F(city, "tree_puff_alpha");
        foreach (Vector3 stump in fallen)
            foreach (float side in PUFF_SIDES)
                fx.TreePuff(stump + new Vector3(side * size * PUFF_SIDE, 0f, 0f), size, alpha);
        fallen.Clear();
    }

    public int Debris => (leafField?.Live ?? 0) + (barkField?.Live ?? 0);

    public void Tick()
    {
        Throw();
        leafField?.Tick(Time.deltaTime);
        barkField?.Tick(Time.deltaTime);
        foreach (Tile tile in tiles.Values)
            if (tile.dirty) Remake(tile);
    }
}
