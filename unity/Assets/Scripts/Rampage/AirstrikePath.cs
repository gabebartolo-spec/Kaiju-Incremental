using S = Kaiju.Sim;

// The jet run's geometry (scenes/airstrike_view.gd on_event and _process), free of the engine so
// unity/SimTests/AirstrikeCheck.cs can hold it to the sim's airstrike event. Godot axes; decides nothing.
public static class AirstrikePath
{
    // A V: the lead on the line, the others behind it, one each side in turn.
    public static long Rank(long i) => (i + 1) / 2;

    // Jet i's place in the formation, from the lead.
    public static S.Vector2 Offset(S.Vector2 from, S.Vector2 to, double spacing, long i)
    {
        S.Vector2 along = (to - from).Normalized();
        S.Vector2 side = along.Orthogonal();
        double rank = Rank(i);
        return side * spacing * rank * (i % 2 == 1 ? 1.0 : -1.0) - along * spacing * rank;
    }

    // How much of the run is flown; the jet is gone at 1.
    public static double Share(double gone, double seconds) => gone / System.Math.Max(0.01, seconds);

    public static S.Vector2 At(S.Vector2 from, S.Vector2 to, S.Vector2 offset, double share) => from + offset + (to - from) * share;
}
