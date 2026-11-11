// The growth reveal after an evolution is bought (scenes/evolution_reveal.gd): "EVOLVING...", then at the swap
// the new stage's name and how tall the body now stands. First version: the words and the numbers at Godot's
// timings; the 3D body, its roar, the flash and the shake come with the polish pass (D-476).
using System;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public sealed class TreeReveal : Selectable, IPointerClickHandler, ISubmitHandler, ICancelHandler
{
    // evolution_reveal.gd, in 60 Hz frames: the body swaps, the reveal ends, a press may skip it.
    const float SWAP_S = 54f / 60f, END_S = 230f / 60f, SKIP_AFTER_S = 8f / 60f;
    const int SKIP_SIZE = 30;
    const float GAP = 16f;

    TreeText.Reveal reveal;
    Text headline, lines;
    Action done;
    float age;
    bool swapped, finished;

    // Covers `screen`, holds the focus and calls `onDone` once when it ends or is skipped.
    public static TreeReveal Show(RectTransform screen, TreeText.Reveal reveal, Action onDone)
    {
        Image back = UiKit.Fill(screen, UiKit.BG, "Reveal");
        back.raycastTarget = true;
        TreeReveal r = back.gameObject.AddComponent<TreeReveal>();
        r.targetGraphic = back;
        r.transition = Transition.None;
        // It keeps the focus: a confirm skips it instead of reaching the tree underneath and buying again.
        r.navigation = new Navigation { mode = Navigation.Mode.None };
        r.reveal = reveal;
        r.done = onDone;
        RectTransform col = UiKit.Column(back.transform, GAP, "Words");
        col.anchorMin = col.anchorMax = col.pivot = new Vector2(0.5f, 0.5f);
        UiKit.Fit(col);
        r.headline = UiKit.Label(col, "EVOLVING...", UiKit.SIZE_TITLE, UiKit.ACCENT);
        r.headline.alignment = TextAnchor.MiddleCenter;
        // Two lines tall from the start (empty before the swap), so the skip prompt never moves.
        r.lines = UiKit.Label(col, "", UiKit.SIZE_HEAD, UiKit.TEXT);
        r.lines.alignment = TextAnchor.MiddleCenter;
        r.lines.text = "\n";
        Text skip = UiKit.Label(col, "Enter / A to skip", SKIP_SIZE, UiKit.Lightened(UiKit.MUTED, 0.45f));
        skip.alignment = TextAnchor.MiddleCenter;
        UiFocus.OnCancel(back.gameObject, () => { });
        UiFocus.Grab(r);
        Debug.Log($"flow: tree reveal shown, {reveal.headline}, floors {reveal.floorsBefore} -> {reveal.floorsAfter}, towers to {reveal.towerFloors}");
        return r;
    }

    void Update()
    {
        if (finished) return;
        age += Time.unscaledDeltaTime;
        if (!swapped && age >= SWAP_S) Swap();
        if (age >= END_S) Finish();
    }

    void Swap()
    {
        swapped = true;
        headline.text = reveal.headline;
        lines.text = reveal.lines;
    }

    public void Finish()
    {
        if (finished) return;
        finished = true;
        Destroy(gameObject);
        done?.Invoke();
    }

    void TrySkip()
    {
        if (age >= SKIP_AFTER_S) Finish();
    }

    public void OnPointerClick(PointerEventData eventData) { TrySkip(); }
    public void OnSubmit(BaseEventData eventData) { TrySkip(); }
    public void OnCancel(BaseEventData eventData) { TrySkip(); }
}
