using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Kaiju.Game;
using S = Kaiju.Sim;

// scenes/breath_aim.gd: while the breath is ready, a faint wedge on the street shows the very cone the sim burns
// when it fires (BreathCone.Of), outlined, with a line down its middle. It follows the kaiju's turns.
public sealed class HudAim
{
    // Never culled: the wedge is placed in the shader, so the mesh's own box says nothing.
    const float BOUNDS = 100000f;
    static readonly int AT = Shader.PropertyToID("_AimAt"), RIGHT = Shader.PropertyToID("_AimRight"), FWD = Shader.PropertyToID("_AimFwd");
    static readonly int ALPHA = Shader.PropertyToID("_AimAlpha"), GAIN = Shader.PropertyToID("_AimGain");

    readonly S.RampageSim sim;
    readonly Color tint;
    readonly float fadeS;
    readonly Material material;
    Mesh mesh;
    double builtReach = -1.0, builtHalf = -1.0;
    float age, shown;

    public bool Showing { get; private set; }

    public HudAim(S.RampageSim sim, Color tint, float exposureUnit, float fadeSeconds)
    {
        this.sim = sim;
        this.tint = tint;
        fadeS = fadeSeconds;
        Shader shader = Resources.Load<Shader>("Shaders/HudAim");
        if (shader == null)
        {
            Debug.LogWarning("hud: no Shaders/HudAim; the breath's aim wedge is not drawn");
            return;
        }
        material = new Material(shader);
        material.SetFloat(GAIN, exposureUnit);
    }

    // Once a frame, after the sim stepped.
    public void Step(float dt)
    {
        Showing = HudText.AimShowing(sim.abilityType, (double)sim.breathReadyIn, (double)sim.abilityReadyIn, sim.over, sim.emerge.active);
        if (!Showing)
        {
            shown = 0f;
            return;
        }
        age += dt;
        shown = Mathf.MoveTowards(shown, 1f, fadeS <= 0f ? 1f : dt / fadeS);
        if (material == null) return;
        S.GDict cone = S.BreathCone.Of(sim);
        double reach = S.Num.F(cone["reach"]), half = S.Num.F(cone["half_angle"]);
        if (mesh == null || !Mathf.Approximately((float)reach, (float)builtReach) || !Mathf.Approximately((float)half, (float)builtHalf))
        {
            Build(reach, half);
            builtReach = reach;
            builtHalf = half;
        }
        S.Vector2 origin = cone["origin"], dir = cone["dir"];
        float ox = (float)(double)origin.x, oz = (float)(double)origin.y, dx = (float)(double)dir.x, dz = (float)(double)dir.y;
        // Godot's z runs the other way: the wedge's +z along the facing, its +x to the facing's side.
        material.SetVector(AT, new Vector4(ox, (float)(double)sim.standY + (float)HudText.AIM_LIFT, -oz, 0f));
        material.SetVector(FWD, new Vector4(dx, 0f, -dz, 0f));
        material.SetVector(RIGHT, new Vector4(dz, 0f, dx, 0f));
        material.SetFloat(ALPHA, (float)HudText.AimAlpha(age, shown));
        Graphics.DrawMesh(mesh, Matrix4x4.identity, material, 0, null, 0, null, ShadowCastingMode.Off, false);
    }

    void Build(double reach, double half)
    {
        if (mesh == null) mesh = new Mesh { name = "BreathAim" };
        List<double[]> corners = HudText.Wedge(reach, half);
        Color fill = new Color(tint.r, tint.g, tint.b, (float)HudText.AIM_FILL_ALPHA);
        Color bright = UiKit.Lightened(tint, (float)HudText.AIM_LIGHTEN);
        bright.a = (float)HudText.AIM_LINE_ALPHA;
        var points = new Vector3[corners.Count];
        var colours = new Color[corners.Count];
        var order = new int[corners.Count];
        for (int i = 0; i < corners.Count; i++)
        {
            points[i] = new Vector3((float)corners[i][0], 0f, (float)corners[i][1]);
            colours[i] = corners[i][2] > 0.5 ? bright : fill;
            order[i] = i;
        }
        mesh.Clear();
        mesh.vertices = points;
        mesh.colors = colours;
        mesh.triangles = order;
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one * BOUNDS);
    }

    public void Dispose()
    {
        if (mesh != null) Object.Destroy(mesh);
        if (material != null) Object.Destroy(material);
    }
}
