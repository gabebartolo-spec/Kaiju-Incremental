// Constants the slice's bake reads from scenes/ GDScript (the scripts are the source; never copied here). Shared
// with unity/SimTests, which bakes the far beast's rig for its fixture.
using System;
using System.IO;
using System.Text.RegularExpressions;
using Kaiju.Sim;

static class GdConst
{
    public static double ModelHeight() => Read("scenes/kaiju_model.gd", "MODEL_HEIGHT");

    static double Read(string script, string name)
    {
        string text = File.ReadAllText(Path.Combine(Kaiju.Sim.FileAccess.Root, script));
        Match m = Regex.Match(text, @"^const\s+" + name + @"\s*:?=\s*([-0-9.eE+]+)\s*$", RegexOptions.Multiline);
        if (!m.Success) throw new InvalidOperationException($"slicebake: no const {name} in {script}");
        return Strtod.Parse(m.Groups[1].Value);
    }
}
