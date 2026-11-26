using UnityEngine;
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
    // scenes/gait_clip.gd run: a momentum slam stops the body in a keyed take, played once to its end over
    // whatever the gait does (scenes/clip_choice.gd holds "slam_stop" until it has played out). A held take still
    // playing keeps playing its tail under the new one (gait_clip.gd _go fades from the old state's pose), so a
    // stomp chained off the last one's tail never snaps the legs back to the idle.
    const float FADE_FLOOR_S = 0.001f;  // a zero clip_fade_s still divides
    Clip heldFrom;
    float heldFromTime, heldFromAge;

    public void Hold(string name)
    {
        heldFrom = heldClip;
        heldFromTime = heldClipTime;
        heldFromAge = heldClipAge;
        clips.TryGetValue(name, out heldClip);
        heldClipTime = 0f;
        heldClipAge = 0f;
    }

    void LayHeld(float dt, ref Vector3 offset)
    {
        if (!LayTake(heldFrom, dt, ref heldFromTime, ref heldFromAge, ref offset)) heldFrom = null;
        if (!LayTake(heldClip, dt, ref heldClipTime, ref heldClipAge, ref offset)) heldClip = null;
    }

    // One held take over the pose, faded in from its start and out to its end (clip_fade_s); false once it has ended.
    bool LayTake(Clip take, float dt, ref float time, ref float age, ref Vector3 offset)
    {
        if (take == null) return false;
        time += dt * fps;
        age += dt;
        float end = take.frames - 1;
        if (time >= end) return false;
        ClipPose(take, time, turnsA, out Vector3 heldOffset);
        float fadeS = Mathf.Max(FADE_FLOOR_S, tuning.clip_fade_s);
        float w = Mathf.SmoothStep(0f, 1f, Mathf.Min(1f, (end - time) / (fadeS * fps))) * Mathf.SmoothStep(0f, 1f, Mathf.Min(1f, age / fadeS));
        for (int i = 0; i < turnsOut.Length; i++) turnsOut[i] = Quaternion.Slerp(turnsOut[i], turnsA[i], w);
        offset = Vector3.Lerp(offset, heldOffset, w);
        return true;
    }
}
