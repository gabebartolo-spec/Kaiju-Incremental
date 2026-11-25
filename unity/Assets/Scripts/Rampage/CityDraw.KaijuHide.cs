using System.Collections.Generic;
using Kaiju.Game;
using Unity.Collections;
using UnityEngine;
using N = System.Numerics;
using S = Kaiju.Sim;

// The kaiju's hide in the city (scenes/city_view.gd, scenes/kaiju_hide.gd, scenes/city_falls.gd _shatter): the
// rigid capsule round him (KaijuHideBody), no city debris piece ever thrown from inside it (DebrisField keep-out),
// and a falling part that came down on him or a neighbour (fall_land "contact") breaks up where it is, its samples
// thrown off what it hit from outside his hide, with a puff of dust where the first one flies. The maths is
// GameLogic/KaijuHide.cs, checked against Godot by SimTests/KaijuHideCheck.cs; the picks draw on their own stream, as
// the bite's and the blast break's do.
public sealed unsafe partial class CityDraw
{
    sealed partial class Fall
    {
        // Its pivot and its samples at rest (Godot axes, CarveJob.samples): what it breaks up into on a contact
        // landing.
        public N.Vector3 pivotAt;
        public List<BurstPart> parts;
    }

    S.GDict hideCfg;
    float hideMargin;
    KaijuHideBody hideBody;
    S.RandomNumberGenerator shatterRng;
    // The last fall to land and where (Godot axes); a break-up that threw nothing (quietId) raises no dust.
    long landedId = -1, quietId = -1;
    Vector3 landedAt;

    // Where fall `id`, the last to land, came down (Godot axes): EventFx puts the landing dust there, none when
    // `dust` is false.
    public bool Landed(long id, out Vector3 at, out bool dust)
    {
        at = landedAt;
        dust = id != quietId;
        return id == landedId;
    }

    // city_view.gd: the hide, and the city debris' keep-out. Made with the city's DebrisField (BurstSetup): its
    // pieces are all the hide ever meets, as in Godot.
    void HideStart()
    {
        hideCfg = S.Content.Section("fall_contact");
        hideMargin = (float)S.Num.F(hideCfg["fragment_margin"]);
        var go = new GameObject("kaiju hide");
        go.transform.SetParent(root, false);
        hideBody = go.AddComponent<KaijuHideBody>();
        hideBody.capsule = Hide;
        hideBody.Follow(true);
        cityDebris.keepOut = HideOutside;  // no fragment is ever thrown from inside his hide
    }

    HideCapsule Hide() => KaijuHide.Of(S.FallContact.Hide(sim, hideCfg));

    // DebrisField keep_out (kaiju_hide.gd outside): `pos` (Godot axes) clear of his hide.
    Vector3 HideOutside(Vector3 pos)
    {
        N.Vector3 p = KaijuHide.Outside(new N.Vector3(pos.x, pos.y, pos.z), Hide(), hideMargin);
        return new Vector3(p.X, p.Y, p.Z);
    }

    // A falling part's samples (city_carve.gd piece: CarveJob.samples of its cells), taken before they leave `f`.
    List<BurstPart> FallParts(Site s, FineBody f, int[] index)
    {
        NativeArray<byte> palette = s.palette, looks = f.looks;
        return LandmarkBurst.Samples(index, f.w, f.d, new N.Vector3(f.origin.x, f.origin.y, f.origin.z), VOXEL,
            i => PaletteColor(palette, looks[i]));
    }

    // A piece's hinge at `at` (Unity axes) and the holder under it that keeps the piece's cells where they were.
    Transform Hinge(string name, Vector3 at, out Transform holder)
    {
        var hinge = new GameObject(name).transform;
        hinge.SetParent(root, false);
        hinge.position = at;
        holder = new GameObject("rest").transform;
        holder.SetParent(hinge, false);
        holder.localPosition = -at;
        return hinge;
    }

    // The fall's piece as Godot's node.global_transform: the hinge seen through the z mirror.
    static PieceXf Xf(Transform hinge)
    {
        return new PieceXf
        {
            x = Mirror(hinge.TransformVector(Vector3.right)),
            y = Mirror(hinge.TransformVector(Vector3.up)),
            z = Mirror(hinge.TransformVector(Vector3.back)),
            origin = Mirror(hinge.position),
        };
    }

    static N.Vector3 Mirror(Vector3 v) => new N.Vector3(v.x, v.y, -v.z);

    // city_falls.gd land: a landing with a "contact" goes to _shatter. The piece breaks up into city debris and goes;
    // the dust goes where the first fragment flies (EventFx reads Landed), none when it threw nothing. False: no
    // contact, the plain landing.
    bool Shatter(long id, Fall f, S.GDict e)
    {
        if (S.Gd.Str(e.Get("contact", "")) == "") return false;
        if (burstMaterial == null) BurstSetup();
        shatterRng ??= S.Seeds.Make("fall_shatter");
        bool onKaiju = S.Gd.Str(e["contact"]) == "kaiju";
        var kaijuAt = new N.Vector2((float)(double)sim.kaijuPos.x, (float)(double)sim.kaijuPos.y);
        HideShatter shatter = KaijuHide.Shatter(f.parts ?? new List<BurstPart>(), Xf(f.pivot), f.pivotAt, onKaiju,
            kaijuAt, Hide(), hideMargin, shatterRng);
        foreach (BurstFragment b in shatter.fragments)
            cityDebris.Spawn(V(b.pos), new Color(b.color.X, b.color.Y, b.color.Z, b.color.W), V(b.away));
        landedId = id;
        landedAt = V(shatter.dust);
        if (!shatter.hasDust) quietId = id;
        Free(f.body);
        Object.Destroy(f.pivot.gameObject);
        return true;
    }
}
