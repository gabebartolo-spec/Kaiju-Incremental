// The one outlined text style (ui_kit.gd text_style): a near-black outline round every letter and a soft drop
// shadow, so any kit colour reads over the brightest fire. uGUI's own Outline draws four copies, which leaves
// gaps at 6 px and more; this draws the letters again on a ring of offsets, and the shadow as that same
// outlined shape set down and right.
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public sealed class KitText : BaseMeshEffect
{
    // Godot's outline_size is the stroke's full width, half of it outside the letter. UNPROVEN against a Godot
    // capture: set from the engine's stroker, to be checked when the port is compared side by side (D-476).
    public const float OUTLINE_REACH = 0.5f;
    // Copies of the letters round the outline, by how far it reaches (px): more as the ring grows.
    const int RING_SMALL = 8, RING_MID = 12, RING_BIG = 16;
    const float MID_FROM = 4f, BIG_FROM = 8f;
    // uGUI meshes hold 65,000 corners: a long crawl drops to fewer copies before it would pass this.
    const int VERT_BUDGET = 60000;

    // The outline's width in Godot's terms (px at 1080p), the shadow's offset and both colours.
    public float outline = 6f;
    public float shadow = 4f;
    public Color outlineColor = Color.black;
    public Color shadowColor = new Color(0f, 0f, 0f, 0.7f);

    static readonly List<UIVertex> letters = new List<UIVertex>(1024);
    static readonly List<UIVertex> built = new List<UIVertex>(8192);

    public override void ModifyMesh(VertexHelper vh)
    {
        if (!IsActive()) return;
        letters.Clear();
        vh.GetUIVertexStream(letters);
        if (letters.Count == 0) return;
        float reach = outline * OUTLINE_REACH;
        int ringCount = reach <= 0f ? 0 : reach < MID_FROM ? RING_SMALL : reach < BIG_FROM ? RING_MID : RING_BIG;
        bool shadowOn = shadow > 0f && shadowColor.a > 0f;
        // Over the budget: thin the ring, then lose the shadow, then the outline.
        while (ringCount > 4 && letters.Count * Copies(ringCount, shadowOn) > VERT_BUDGET) ringCount -= 4;
        if (letters.Count * Copies(ringCount, shadowOn) > VERT_BUDGET) shadowOn = false;
        if (letters.Count * Copies(ringCount, shadowOn) > VERT_BUDGET) ringCount = 0;
        built.Clear();
        float alpha = graphic != null ? graphic.color.a : 1f;
        if (shadowOn)
        {
            Color32 dark = Faded(shadowColor, alpha);
            Vector2 drop = new Vector2(shadow, -shadow);
            Copy(drop, dark);
            // The shadow carries the outline's width (shadow_outline_size): four copies are enough for a blur.
            if (ringCount > 0)
                for (int i = 0; i < 4; i++) Copy(drop + Around(i, 4, reach, 0.5f), dark);
        }
        Color32 ink = Faded(outlineColor, alpha);
        for (int i = 0; i < ringCount; i++) Copy(Around(i, ringCount, reach, 0f), ink);
        built.AddRange(letters);
        vh.Clear();
        vh.AddUIVertexTriangleStream(built);
    }

    static int Copies(int ringCount, bool shadowOn)
    {
        return 1 + ringCount + (shadowOn ? (ringCount > 0 ? 5 : 1) : 0);
    }

    static Vector2 Around(int i, int count, float radius, float turn)
    {
        float angle = Mathf.PI * 2f * (i + turn) / count;
        return new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius;
    }

    static Color32 Faded(Color c, float alpha)
    {
        c.a *= alpha;
        return c;
    }

    static void Copy(Vector2 offset, Color32 colour)
    {
        Vector3 by = offset;
        for (int i = 0; i < letters.Count; i++)
        {
            UIVertex v = letters[i];
            v.position += by;
            v.color = colour;
            built.Add(v);
        }
    }
}
