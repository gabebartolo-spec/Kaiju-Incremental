// Stand-in Kaiju Creation until the lab is built (scenes/kaiju_creation.gd): no screen, the first species this
// build offers (the croc) is made at once.
using System;
using UnityEngine;
using S = Kaiju.Sim;

public static class StubCreation
{
    // Calls `onCreated` with the species id before it returns; null: nothing is on show. `onBack` is the lab's BACK.
    public static RectTransform Show(S.GDict save, Action<string> onCreated, Action onBack)
    {
        S.GArray<S.GDict> offered = S.Demo.Species();
        if (offered.IsEmpty())
        {
            Debug.LogWarning("flow: creation has no species to offer");
            onBack();
            return null;
        }
        onCreated(S.Gd.Str(offered[0]["id"]));
        return null;
    }
}
