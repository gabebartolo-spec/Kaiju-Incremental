using System;
using System.Collections.Generic;
using System.Globalization;
using N = System.Numerics;

// A turn (Godot's Basis, no scale), as three columns: what a stone chunk lies at while it flies and rests.
public struct Turn
{
    const float AXIS_FLOOR = 1e-6f;
    public N.Vector3 x, y, z;

    public static Turn Identity => new Turn { x = N.Vector3.UnitX, y = N.Vector3.UnitY, z = N.Vector3.UnitZ };

    // Godot's Basis(axis, angle): a right-handed turn of `angle` about the unit `axis`.
    public static Turn About(N.Vector3 axis, float angle)
    {
        float c = MathF.Cos(angle), s = MathF.Sin(angle), t = 1f - c;
        float ax = axis.X, ay = axis.Y, az = axis.Z;
        return new Turn
        {
            x = new N.Vector3(t * ax * ax + c, t * ax * ay + s * az, t * ax * az - s * ay),
            y = new N.Vector3(t * ax * ay - s * az, t * ay * ay + c, t * ay * az + s * ax),
            z = new N.Vector3(t * ax * az + s * ay, t * ay * az - s * ax, t * az * az + c),
        };
    }

    public N.Vector3 Apply(N.Vector3 v) => x * v.X + y * v.Y + z * v.Z;

    public static Turn operator *(Turn a, Turn b) => new Turn { x = a.Apply(b.x), y = a.Apply(b.y), z = a.Apply(b.z) };

    // transposed().y: the world's up in the turn's own space.
    public N.Vector3 UpInside => new N.Vector3(x.Y, y.Y, z.Y);

    // Godot's orthonormalized(): Gram-Schmidt over the columns, x first.
    public Turn Orthonormalized()
    {
        N.Vector3 nx = Unit(x);
        N.Vector3 ny = Unit(y - nx * N.Vector3.Dot(nx, y));
        N.Vector3 nz = Unit(z - nx * N.Vector3.Dot(nx, z) - ny * N.Vector3.Dot(ny, z));
        return new Turn { x = nx, y = ny, z = nz };
    }

    static N.Vector3 Unit(N.Vector3 v)
    {
        float l = v.Length();
        return l > AXIS_FLOOR ? v / l : N.Vector3.Zero;
    }
}

// One baked stone chunk (assets/death/chunk_*.obj, tools/blender/death_chunks.py, longest side 1): its corners,
// and its faces as flat triangles in Godot's chunk space, wound as SliceGame.CubeMesh(godot: true) winds a
// cube, so the z mirror into Unity draws their outsides.
public sealed class ObjChunk
{
    public readonly N.Vector3[] corners;
    public readonly List<N.Vector3> points = new List<N.Vector3>();
    public readonly List<N.Vector3> normals = new List<N.Vector3>();
    public readonly List<int> triangles = new List<int>();

    public ObjChunk(string text)
    {
        var v = new List<N.Vector3>();
        var vn = new List<N.Vector3>();
        foreach (string raw in text.Split('\n'))
        {
            string[] w = raw.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (w.Length == 0) continue;
            if (w[0] == "v") v.Add(Vec(w));
            else if (w[0] == "vn") vn.Add(Vec(w));
            else if (w[0] == "f") Face(w, v, vn);
        }
        corners = v.ToArray();
    }

    static N.Vector3 Vec(string[] w) => new N.Vector3(F(w[1]), F(w[2]), F(w[3]));

    static float F(string s) => float.Parse(s, CultureInfo.InvariantCulture);

    // A face of three or more corners (v/vt/vn), fanned into triangles that face along its normal.
    void Face(string[] w, List<N.Vector3> v, List<N.Vector3> vn)
    {
        var at = new List<N.Vector3>();
        N.Vector3 n = N.Vector3.Zero;
        for (int k = 1; k < w.Length; k++)
        {
            string[] ids = w[k].Split('/');
            at.Add(v[int.Parse(ids[0], CultureInfo.InvariantCulture) - 1]);
            if (ids.Length > 2 && ids[2] != "") n = vn[int.Parse(ids[2], CultureInfo.InvariantCulture) - 1];
        }
        for (int k = 1; k + 1 < at.Count; k++)
        {
            N.Vector3 a = at[0], b = at[k], c = at[k + 1];
            N.Vector3 facing = n == N.Vector3.Zero ? N.Vector3.Cross(b - a, c - a) : n;
            bool outward = N.Vector3.Dot(N.Vector3.Cross(b - a, c - a), facing) > 0f;
            int first = points.Count;
            points.Add(a);
            points.Add(outward ? c : b);
            points.Add(outward ? b : c);
            for (int j = 0; j < 3; j++)
            {
                normals.Add(N.Vector3.Normalize(facing));
                triangles.Add(first + j);
            }
        }
    }
}

// scenes/death_chunks.gd's pieces: each one chunk (kind) at its own size (longest side, world units), lying at a
// turn. Launched pieces fly under gravity, tumbling, and stop where their lowest corner meets the street (they
// stay: rubble); the rest are placed by their owner. Godot axes. Plain C#: the draw is DeathView's.
public sealed class DeathPieces
{
    public readonly int[] kind;
    public readonly float[] size;
    public readonly Turn[] lie;
    // How each piece is drawn now: its turn (no scale) and its middle.
    public readonly Turn[] drawTurn;
    public readonly N.Vector3[] drawAt;
    readonly N.Vector3[][] corners;
    readonly N.Vector3[] pos, vel, axis;
    readonly float[] rate;

    public int Count => kind.Length;

    public DeathPieces(N.Vector3[][] corners, int[] kinds, float[] sizes, Turn[] turns)
    {
        this.corners = corners;
        kind = kinds;
        size = sizes;
        lie = turns;
        int n = kinds.Length;
        drawTurn = (Turn[])turns.Clone();
        drawAt = new N.Vector3[n];
        pos = new N.Vector3[n];
        vel = new N.Vector3[n];
        axis = new N.Vector3[n];
        rate = new float[n];
    }

    public void Place(int i, Turn turn, N.Vector3 at)
    {
        drawTurn[i] = turn;
        drawAt[i] = at;
    }

    // How high piece i's middle sits when it lies on the street at `turn`: its lowest corner's depth.
    public float Lift(int i, Turn turn)
    {
        float low = float.PositiveInfinity;
        N.Vector3 up = turn.UpInside;
        foreach (N.Vector3 c in corners[kind[i]]) low = MathF.Min(low, N.Vector3.Dot(c, up));
        return -low * size[i];
    }

    // Piece i sets off from `at` at `velocity`, tumbling about `spin` (its length the rate, rad/s).
    public void Launch(int i, N.Vector3 at, N.Vector3 velocity, N.Vector3 spin)
    {
        float r = spin.Length();
        pos[i] = at;
        vel[i] = velocity;
        axis[i] = r > 0f ? spin / r : N.Vector3.Zero;
        rate[i] = r;
        Place(i, lie[i], at);
    }

    public bool Moving(int i) => vel[i] != N.Vector3.Zero;

    // One step for the launched pieces.
    public void Fall(float dt, float gravity)
    {
        for (int i = 0; i < pos.Length; i++)
        {
            N.Vector3 v = vel[i];
            if (v == N.Vector3.Zero) continue;
            v.Y -= gravity * dt;
            N.Vector3 p = pos[i] + v * dt;
            Turn turn = Turn.About(axis[i], rate[i] * dt) * lie[i];
            if (p.Y <= size[i]) // near the street: is its lowest corner down?
            {
                float h = Lift(i, turn);
                if (p.Y <= h)
                {
                    turn = turn.Orthonormalized();
                    p.Y = h;
                    v = N.Vector3.Zero;
                }
            }
            lie[i] = turn;
            pos[i] = p;
            vel[i] = v;
            Place(i, turn, p);
        }
    }
}
