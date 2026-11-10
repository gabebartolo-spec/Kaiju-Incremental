using UnityEngine;
using S = Kaiju.Sim;

// scenes/leap_view.gd: what the player sees of the croc's leap (sim/game/dash.gd, the dash button). The body
// rides the sim's arc (RampageGame.Feet adds Dash.Height) in the keyed leap clip; the street's trees go down
// under the landing ring. The take-off dust and the landing ring are EventFx's, the landing shake
// RampageGame.ShakeFor's. Presentation only: the sim decided where, when and what broke.
public sealed class LeapView
{
    readonly S.RampageSim sim;
    readonly Croc croc;
    readonly CityTrees trees;

    public int Offs { get; private set; }
    public int Lands { get; private set; }

    public LeapView(S.RampageSim sim, Croc croc, CityTrees trees)
    {
        this.sim = sim;
        this.croc = croc;
        this.trees = trees;
    }

    public void OnEvent(S.GDict e)
    {
        switch (S.Gd.Str(e["type"]))
        {
            case "leap_off":
                S.Vector2 off = e["at"];
                Offs++;
                Debug.Log($"leap off at frame {Time.frameCount}: {(float)off.x:F1},{(float)off.y:F1}");
                break;
            case "leap_land":
                S.Vector2 land = e["at"];
                float radius = (float)(double)S.Num.F(e["radius"]);
                trees.Crush(new Vector3((float)land.x, 0f, (float)land.y), radius);
                Lands++;
                Debug.Log($"leap land at frame {Time.frameCount}: {(float)land.x:F1},{(float)land.y:F1} radius {radius:F1} building {S.Num.I(e["building"])}");
                break;
        }
    }

    // scenes/leap_view.gd update: the clip on the sim's phase, and how far through it the leap is.
    public void Pose(Vector3 feet, Vector2 facing, float scale, float dt)
    {
        S.Dash dash = sim.body.dash;
        double settle = dash.PhaseSeconds("settle");
        double share = settle / System.Math.Max(0.001, settle + dash.PhaseSeconds("recover"));
        croc.DriveLeap(feet, facing, scale, dash.Phase(), (float)dash.PhaseT(), (float)share, dt);
    }
}
