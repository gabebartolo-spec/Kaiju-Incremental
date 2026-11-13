using System;
using S = Kaiju.Sim;

// The whale of Wildlife (scenes/wildlife_view.gd _build_whale, _move_whale, _surface): it surfaces a few times a run
// out in the bay, spouts, swims a while, dives, and dives at once on a roar. Its node's position and turn (rotation.y,
// float32 as Godot keeps it) are held here in Godot axes.
public sealed partial class Wildlife
{
    // The whale's surfacings, dives and spouts so far.
    public int surfacings, dives, spouts;
    public string whaleState = "wait";  // wait, rise, up, dive, gone
    public bool whaleVisible;
    public S.Vector3 whaleAt;
    public float whaleYaw;
    double whaleT;
    long whaleLeft;

    void BuildWhale()
    {
        S.GDict w = cfg["whale"];
        S.GArray<S.Variant> times = w["surfacings"];
        whaleLeft = rng.RandiRange(S.Num.I(times[0]), S.Num.I(times[1]));
        whaleT = -Range(w["first"]);
    }

    // The whale dives now if it is up or rising.
    public void Dive()
    {
        if (whaleState != "rise" && whaleState != "up") return;
        whaleState = "dive";
        whaleT = 0.0;
        dives += 1;
    }

    // Its node's -basis.z: ahead, for rotation (0, yaw, 0).
    S.Vector3 Ahead() => new S.Vector3(-MathF.Sin(whaleYaw), 0f, -MathF.Cos(whaleYaw));

    void MoveWhale(double delta)
    {
        if (whaleState == "gone") return;
        S.GDict w = cfg["whale"];
        whaleT += delta;
        double low = sea - S.Num.F(w["depth"]), high = sea;
        switch (whaleState)
        {
            case "wait":
                if (whaleT >= 0.0) Surface(w, low);
                break;
            case "rise":
                double k = S.Gd.Clampf(whaleT / S.Num.F(w["rise_seconds"]), 0.0, 1.0);
                whaleAt = new S.Vector3(whaleAt.x, S.Gd.Lerpf(low, high, k), whaleAt.z);
                if (k < 1.0) break;
                whaleState = "up";
                whaleT = -Range(w["stay"]);
                spouts += 1;
                break;
            case "up":
                whaleAt += Ahead() * S.Num.F(w["swim"]) * delta;
                if (whaleT >= 0.0) Dive();
                break;
            case "dive":
                MoveDive(w, low, high, delta);
                break;
        }
    }

    void MoveDive(S.GDict w, double low, double high, double delta)
    {
        double k = S.Gd.Clampf(whaleT / S.Num.F(w["dive_seconds"]), 0.0, 1.0);
        whaleAt = new S.Vector3(whaleAt.x, S.Gd.Lerpf(high, low, k), whaleAt.z);
        whaleAt += Ahead() * S.Num.F(w["swim"]) * delta;
        if (k < 1.0) return;
        whaleVisible = false;
        whaleState = "wait";
        whaleT = -Range(w["gap"]);
    }

    void Surface(S.GDict w, double low)
    {
        if (whaleLeft <= 0)
        {
            whaleState = "gone";
            return;
        }
        double coast = S.Num.F(sim.city["coast_z"]);
        double x = Range(w["area_x"]);
        whaleAt = new S.Vector3(x, low, coast + Range(w["area_z"]));
        whaleYaw = (float)(rng.Randf() * S.Gd.TAU);
        whaleVisible = true;
        whaleState = "rise";
        whaleT = 0.0;
        whaleLeft -= 1;
        surfacings += 1;
    }
}
