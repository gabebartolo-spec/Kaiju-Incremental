// The Chinese fallback face (autoload/cjk_font.gd, D-392). Our faces draw Latin and Cyrillic; Chinese falls back to
// the Noto Sans SC subset (tools/fonts/subset_cjk.py, copied into Resources/Fonts by the build), which has no Latin,
// so it is a fallback and never the face. A legacy Font has no list of fallback Font objects: a missing glyph is
// looked up by the family names in the face's fontNames, project fonts first, so the subset is loaded and its own
// family name is added after the face's. Godot attaches it only under Chinese because a fallback grows a Godot
// font's line height; a legacy Text line keeps the face's own height, so here it is attached in every language,
// and the Language button's Chinese name draws in it too.
using System;
using UnityEngine;

public static class CjkFont
{
    public const string PATH = "Fonts/kaiju_cjk";
    // A character the subset has and our faces lack (U+4E2D), for the log line.
    const char PROBE = '中';

    static Font cjk;
    static bool warned;

    // `face` with the subset's family added to its fallback names, and a line saying so; null stays null.
    public static Font Attach(Font face)
    {
        if (face == null) return null;
        if (cjk == null) cjk = Resources.Load<Font>(PATH);
        if (cjk == null)
        {
            if (!warned) Debug.LogWarning("ui: font " + PATH + " missing from Resources, Chinese text has no face");
            warned = true;
            return face;
        }
        string[] own = face.fontNames ?? Array.Empty<string>();
        string[] add = cjk.fontNames ?? Array.Empty<string>();
        if (Array.IndexOf(own, add.Length > 0 ? add[0] : "") >= 0) return face;
        string[] names = new string[own.Length + add.Length];
        own.CopyTo(names, 0);
        add.CopyTo(names, own.Length);
        face.fontNames = names;
        Debug.Log($"ui: {face.name} falls back to {cjk.name}: names {string.Join(", ", names)}; "
            + $"U+{(int)PROBE:X4} in {face.name} {face.HasCharacter(PROBE)}, in {cjk.name} {cjk.HasCharacter(PROBE)}");
        return face;
    }
}
