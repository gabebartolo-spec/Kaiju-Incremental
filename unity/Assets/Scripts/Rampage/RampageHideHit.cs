using Kaiju.Game;
using S = Kaiju.Sim;

// RampageGame's hide hit glue (scenes/kaiju_model.gd _colors, scenes/fx.gd's HideHit child): the croc's eye check
// gets the species' own eye colour, and every shot fx lands (HideHitView) lands on this croc.
public sealed partial class RampageGame
{
    // Wraps Load's new CityFx: KaijuModel.new(species, colors, ...) keeps colors["eye"] for hide_cast's eye check
    // (black when the species has none, as Godot's _colors.get("eye", Color.BLACK)).
    CityFx HideHitFx(CityFx made)
    {
        S.GDict colours = Species["colors"];
        if (colours.Has("eye")) croc.HideEyeColour = HideEye.Hex(S.Gd.Str(colours["eye"]));
        made.HideHit.Kaiju = croc;
        return made;
    }
}
