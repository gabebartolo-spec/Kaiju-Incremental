using UnityEngine;

// ArmyView's hide hit callers (scenes/tank_fx.gd fire_shell, powers_view.gd _heli_fired): shells and gun rounds land
// on the real hide through CityFx.HideHit (HideHitView), and armour turns a shell into a glance.
public sealed partial class ArmyView
{
    // tank_fx.gd fire_shell: whether the shell glances is read when it is fired (sim.stat("armor") > 0), and the
    // glance flies off away from where the tank stands (node.position, Godot axes).
    Shell Armour(Shell s, Tank t)
    {
        s.armoured = sim.Stat("armor") > 0.0;
        s.tank = Mirror(t.root.position);
        return s;
    }

    // powers_view.gd _heli_fired: the muzzle flash, and the round lands on the hide at body height
    // (kaiju_at + up * 3 * body_scale).
    void HeliFired(long id, Vector3 kaiju)
    {
        if (!helis.TryGetValue(id, out Heli h)) return;
        Vector3 muzzle = Mirror(h.gun.TransformPoint(Mirror(new Vector3(0f, 0f, h.muzzleZ))));
        fx.FlashLight(muzzle, MUZZLE_FLASH, MUZZLE_LIGHT, MUZZLE_LIGHT_S);
        fx.HideHit.Land(muzzle, kaiju + Vector3.up * (HELI_AIM_HEIGHT * (float)sim.BodyScale()));
    }
}
