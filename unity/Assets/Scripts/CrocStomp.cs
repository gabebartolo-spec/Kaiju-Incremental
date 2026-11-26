using S = Kaiju.Sim;

// The standing stomp (scenes/clip_stomp.gd stomp with the keyed r13f stomps, scenes/gait_clip.gd stomp,
// scenes/stomp_landing.gd): the sim stomps on a beat even while he stands, and the scene waits (EventFx STOMP_WAIT)
// for the foot that delivers it. Walking, the walk's own feet deliver it. Standing, the next foot in turn plays its
// keyed stomp ("stomp_l", "stomp_r", in the reptile's kclips), held over the idle (Hold) so the foot lifts and lands
// inside that wait; only that landing kicks the camera. A keyed stomp still in the air delivers the next one too.
public sealed partial class Croc
{
    static readonly string[] KEYED_STOMPS = { "stomp_l", "stomp_r" };
    // gait_biped.gd STAND_SPEED (0.12 hip heights a second) is as good as still: here, the walk's weight this low.
    const float STAND_SHARE = 0.1f;
    int stompNext;
    string stompLifted = "", stompFoot = "";  // the latest stomp's lifted foot; the keyed foot still to land
    Clip stompHeld;

    // A sim event: on a "stomp", standing, the next foot in turn lifts in its keyed stomp. The side it lifted
    // ("left" or "right"), else "" (walking, roaring, a slam stop, a keyed foot still to land, or another event).
    public string StandingStomp(S.GDict e)
    {
        if (S.Gd.Str(e["type"]) != "stomp") return "";
        stompLifted = "";
        if (!StandsToStomp()) return "";
        string side = S.Gd.Str(e.Get("side", ""));
        if (side == FOOT_SIDES[0] || side == FOOT_SIDES[1]) stompNext = side == FOOT_SIDES[0] ? 0 : 1;  // clip_stomp.gd prefer
        int i = stompNext;
        stompNext = 1 - i;
        stompLifted = stompFoot = FOOT_SIDES[i];
        Hold(KEYED_STOMPS[i]);
        stompHeld = heldClip;
        return stompLifted;
    }

    // clip_stomp.gd stomp's `standing` (the idle, or a keyed stomp's tail) with no keyed foot still to land.
    bool StandsToStomp()
    {
        bool stomping = heldClip != null && heldClip == stompHeld;
        if (!stomping) stompFoot = "";
        if (stompFoot != "" || !clips.ContainsKey(KEYED_STOMPS[0])) return false;
        return stomping || (heldClip == null && roarTime < 0f && moveWeight < STAND_SHARE);
    }

    // stomp_landing.gd landed: the waiting stomp lands under `side`'s foot; whether it is the foot the standing
    // stomp lifted (its landing kicks the camera).
    public bool StompLanded(string side)
    {
        if (side == stompFoot) stompFoot = "";
        if (side == "" || side != stompLifted) return false;
        stompLifted = "";
        return true;
    }
}
