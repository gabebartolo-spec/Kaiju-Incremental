// A liquid of the Kaiju Creation lab drawn on its own (scenes/creation_liquid.gd, D-207): a titan's serum in its
// vial, the Special K canister and the injector's glass barrel. Its blocks glow in the liquid's colour up to a
// level (0..1, filled from the bottom) and show their empty glass above it, so a vial drains and the barrel fills
// as the injector draws, then empties as it dispenses.
using System.Collections.Generic;
using UnityEngine;

public sealed class CreationLiquid
{
    // Each mesh face is a quad; its four corners share the cell's colour.
    const int QUAD = 4;
    const byte GLOWS = 0;

    readonly Mesh mesh;
    readonly int[] rows;
    readonly Color32[] empty, shown;
    readonly int y0, y1;
    float level = -1f;
    Color32 full;

    public Mesh Mesh => mesh;

    // empties: cell -> the colour it shows empty (0xRRGGBB); voxel: the prop's block size.
    public CreationLiquid(Dictionary<Vector3Int, int> empties, float voxel)
    {
        mesh = ArmyView.Faces(CreationPaint.Model(empties, null, out _), voxel, Vector3.zero);
        mesh.MarkDynamic();
        Vector3[] verts = mesh.vertices;
        Vector3[] normals = mesh.normals;
        empty = mesh.colors32;
        shown = (Color32[])empty.Clone();
        rows = new int[verts.Length / QUAD];
        y0 = int.MaxValue;
        y1 = int.MinValue;
        foreach (Vector3Int cell in empties.Keys)
        {
            y0 = Mathf.Min(y0, cell.y);
            y1 = Mathf.Max(y1, cell.y);
        }
        // A face's centre is its cell's centre pushed half a block out along the normal.
        for (int q = 0; q < rows.Length; q++)
        {
            Vector3 centre = (verts[q * QUAD] + verts[q * QUAD + 1] + verts[q * QUAD + 2] + verts[q * QUAD + 3]) / QUAD;
            float y = centre.y - normals[q * QUAD].y * voxel * 0.5f;
            rows[q] = Mathf.RoundToInt(y / voxel - 0.5f);
        }
    }

    // set_level and set_color: filled to `to` (0 empty, 1 full) from the bottom up in `colour`, which glows.
    public void Show(double to, Color colour)
    {
        float f = Mathf.Clamp01((float)to);
        Color32 c = colour;
        c.a = GLOWS;
        if (Mathf.Approximately(f, level) && c.Equals(full)) return;
        level = f;
        full = c;
        float top = y0 + f * (y1 - y0 + 1);
        for (int q = 0; q < rows.Length; q++)
            for (int k = 0; k < QUAD; k++)
                shown[q * QUAD + k] = rows[q] < top ? full : empty[q * QUAD + k];
        mesh.colors32 = shown;
    }
}
