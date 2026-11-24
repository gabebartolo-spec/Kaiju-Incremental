// scenes/fx.gd's HideHit child and hide_hit(): a shot landing on the kaiju's hide, drawn with the fx's own bursts
// (the flash a Bursts.Flash, the sparks and mist two sprays). Built on first use.
public sealed partial class CityFx
{
    HideHitView hideHit;

    public HideHitView HideHit => hideHit ??= new HideHitView(this, bursts);
}
