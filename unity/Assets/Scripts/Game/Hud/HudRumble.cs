using Kaiju.Game;
using S = Kaiju.Sim;

// scenes/pad_rumble.gd: each footfall thuds, harder at every growth stage; a landed stomp and a toppled building
// jolt; the breath and the ultimate beam buzz while they burn. Rows of tuning "rumble"; Settings > ACCESSIBILITY >
// Rumble turns it off. Presentation only.
public static class HudRumble
{
    // The rumbles sent this session (pad_rumble.gd sent), for a log or a check.
    public static int Sent { get; private set; }

    static S.GDict Cfg() => S.Content.Section("rumble");

    // A foot came down: its stage's thud. A tail slam is not a footfall.
    public static void Footfall(string side, S.RampageSim sim)
    {
        if (side != "tail") Send(HudText.StagedRumble(Cfg(), "footfall", S.Num.I(sim.SizeTier())));
    }

    // A stomp landed under its foot: its stage's jolt.
    public static void Stomp(S.RampageSim sim)
    {
        Send(HudText.StagedRumble(Cfg(), "stomp", S.Num.I(sim.SizeTier())));
    }

    // The sim's events: a toppled building lands, the breath fires, the beam starts.
    public static void OnEvent(S.GDict e)
    {
        Send(HudText.EventRumble(Cfg(), e));
    }

    static void Send(S.GDict row)
    {
        if (row == null || !PlayerSettings.Rumble) return;
        Sent++;
        // Godot's start_joy_vibration(weak, strong, s): the heavy motor is the strong one.
        Inputs.Rumble((float)S.Num.F(row["strong"]), (float)S.Num.F(row["weak"]), (float)S.Num.F(row["seconds"]));
    }
}
