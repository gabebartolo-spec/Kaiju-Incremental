// Godot's SphereMesh for the globe (globe_view.gd _sphere: radial_segments SEGMENTS, rings RINGS): rows from the north
// pole (uv v 0) to the south (v 1), each turning from +z toward +x (u 0 to 1), so the uv is the one GlobeMath.UvOf
// reads. Built in Unity's axes (z mirrored) with every triangle wound to face outward.
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;

public static class GlobeSphere
{
    public static Mesh Make(float radius)
    {
        int segments = GlobeOrbit.SEGMENTS, rows = GlobeOrbit.RINGS + 1;
        int stride = segments + 1;
        var verts = new Vector3[(rows + 1) * stride];
        var normals = new Vector3[verts.Length];
        var uvs = new Vector2[verts.Length];
        for (int j = 0; j <= rows; j++)
        {
            float v = (float)j / rows, w = Mathf.Sin(Mathf.PI * v), y = Mathf.Cos(Mathf.PI * v);
            for (int i = 0; i <= segments; i++)
            {
                float u = (float)i / segments;
                float x = Mathf.Sin(u * Mathf.PI * 2f) * w, z = Mathf.Cos(u * Mathf.PI * 2f) * w;
                int k = j * stride + i;
                normals[k] = new Vector3(x, y, -z);
                verts[k] = normals[k] * radius;
                uvs[k] = new Vector2(u, v);
            }
        }
        var tris = new int[rows * segments * 6];
        int n = 0;
        for (int j = 1; j <= rows; j++)
        {
            for (int i = 1; i <= segments; i++)
            {
                int a = (j - 1) * stride + i - 1, b = (j - 1) * stride + i, c = j * stride + i - 1, d = j * stride + i;
                n = Tri(tris, n, verts, a, b, c);
                n = Tri(tris, n, verts, b, d, c);
            }
        }
        var mesh = new Mesh { name = "globe_sphere", indexFormat = IndexFormat.UInt32 };
        mesh.vertices = verts;
        mesh.normals = normals;
        mesh.uv = uvs;
        mesh.triangles = tris;
        mesh.RecalculateBounds();
        return mesh;
    }

    // One triangle, its order swapped where needed so Unity's front face (clockwise seen from outside) points out.
    static int Tri(int[] tris, int n, Vector3[] verts, int a, int b, int c)
    {
        Vector3 face = Vector3.Cross(verts[b] - verts[a], verts[c] - verts[a]);
        Vector3 mid = verts[a] + verts[b] + verts[c];
        bool flip = Vector3.Dot(face, mid) < 0f;
        tris[n] = a;
        tris[n + 1] = flip ? c : b;
        tris[n + 2] = flip ? b : c;
        return n + 3;
    }
}
