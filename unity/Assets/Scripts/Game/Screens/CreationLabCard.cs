// The lab card (scenes/specimen_card.gd, D-260): the kaiju died, so before the next rampage a card names the
// specimen lost and the one released. No input; it is gone after its seconds (tuning "ui" "specimen_card").
using System;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;
using S = Kaiju.Sim;

public static class LabCard
{
    // Shows the card for the save's specimen; `onDone` runs once when its time is up.
    public static RectTransform Show(S.GDict save, Action onDone)
    {
        long specimen = CreationCard.Specimen(save);
        RectTransform screen = UiKit.Screen("LabCard");
        UiKit.Backdrop(screen);
        RectTransform card = UiKit.Panel(screen, null, CreationCard.Gap());
        card.anchorMin = card.anchorMax = card.pivot = new Vector2(0.5f, 0.5f);
        card.anchoredPosition = Vector2.zero;
        UiKit.Header(card, CreationCard.Title(specimen));
        Text line = UiKit.Label(card, CreationCard.Headline(specimen), UiKit.SIZE_HEAD, UiKit.ACCENT);
        line.alignment = TextAnchor.MiddleCenter;
        CreationCardTimer timer = screen.gameObject.AddComponent<CreationCardTimer>();
        timer.left = (float)CreationCard.Seconds();
        timer.done = onDone;
        Debug.Log("flow: lab card shown, specimen " + specimen + ", " + CreationCard.Seconds().ToString("0.0", System.Globalization.CultureInfo.InvariantCulture) + " s");
        return screen;
    }
}

// Counts the card's seconds down and says done once.
public sealed class CreationCardTimer : MonoBehaviour
{
    public float left;
    public Action done;

    void Update()
    {
        if (done == null) return;
        left -= Time.deltaTime;
        if (left > 0f) return;
        Action call = done;
        done = null;
        call();
    }
}
