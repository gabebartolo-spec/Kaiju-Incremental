using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// RampageGame's far city across the bay (scenes/city_view.gd: SkylineRampage.attach, FarWaterGlow.cover): the
// skyline, the far rampage in it when tuning skyline_rampage.on says so, and its lit windows on the bay near the far
// shore (tuning city far_reflect).
public sealed partial class RampageGame
{
    const int GLOW_VERTS = 6;
    SkylineRampage farRampage;
    readonly List<(Material mat, Bounds bounds)> bayGlow = new List<(Material mat, Bounds bounds)>();

    void BuildFarCity(Shader lit, int seed, Transform root)
    {
        skyline = new CitySkyline(sim.city, lit, root);
        S.GDict city = S.Content.Section("city");
        if (S.Content.Section("skyline_rampage")["on"]) farRampage = new SkylineRampage(skyline, city, seed);
        BayGlow(city["far_reflect"], skyline.Shore);
        Debug.Log($"skyline: {skyline.Boxes} boxes, far rampage {(farRampage == null ? "off" : farRampage.plan.falls.Count + " falls, " + farRampage.plan.fires.Count + " fires")}, bay glow {bayGlow.Count}");
    }

    // FarWaterGlow.cover: a faint band of the window light over each bay sheet, `reach` metres out from the far shore.
    void BayGlow(S.GDict cfg, float shore)
    {
        S.GDict look = S.Content.Look();
        float lit = (float)S.Num.F(look["window_lit"]);
        if (!(bool)cfg["on"] || lit <= 0f) return;
        float reach = (float)S.Num.F(cfg["reach"]);
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(look["window_lit_color"]).TrimStart('#'), out Color glow);
        Color color = glow.linear * (float)S.Num.F(cfg["energy"]);
        Shader shader = Resources.Load<Shader>("Shaders/HorizonFx");
        foreach (WaterRect sheet in ground.Sheets)
        {
            float z1 = Mathf.Min(sheet.z1, shore + reach);
            if (!sheet.bay || z1 <= sheet.z0) continue;
            var mat = new Material(shader);
            mat.EnableKeyword("BAY_GLOW");
            mat.SetFloat("_ZTest", (float)CompareFunction.Always);
            mat.SetVector("_FarColor", color);
            mat.SetVector("_GlowRect", new Vector4(sheet.x0, sheet.z0, sheet.x1, z1));
            mat.SetVector("_GlowShape", new Vector4(sheet.y, shore, reach, (float)S.Num.F(cfg["strength"]) * lit));
            var size = new Vector3(sheet.x1 - sheet.x0, 1f, z1 - sheet.z0);
            bayGlow.Add((mat, new Bounds(new Vector3((sheet.x0 + sheet.x1) * 0.5f, sheet.y, -(sheet.z0 + z1) * 0.5f), size)));
        }
    }

    // The backdrop: the aircraft overhead and the far city.
    void StepBackdrop(float dt)
    {
        aircraft.Step(dt);
        Vector3 ear = cam.transform.position;
        farRampage?.Step(dt, new Vector3(ear.x, ear.y, -ear.z));
        foreach ((Material mat, Bounds bounds) in bayGlow)
            Graphics.DrawProcedural(mat, bounds, MeshTopology.Triangles, GLOW_VERTS, 1, null, null, ShadowCastingMode.Off, false, 0);
    }

    void DisposeFarCity()
    {
        if (farRampage != null) Debug.Log($"far rampage: {farRampage.Fallen()} of {farRampage.plan.falls.Count} towers down at {farRampage.Elapsed:F1} s");
        farRampage?.Dispose();
        skyline?.Dispose();
        foreach ((Material mat, Bounds _) in bayGlow) Destroy(mat);
    }
}
