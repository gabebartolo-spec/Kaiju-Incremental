// The pause menu's state and keys (pause_menu.gd _unhandled_input): the pause action (Esc, Start) resumes
// while the menu's own card is up. Esc is both pause and cancel, and the press that opened the menu or closed
// the confirm or the settings must not also resume, so every resume goes through here.
using System;
using UnityEngine;

public sealed class PauseKeys : MonoBehaviour
{
    public Action onResume, onEndRun;
    // The menu's own card, RESUME on it, and the "Are you sure?" while it is up.
    public GameObject card;
    public KitButton resume;
    public GameObject confirm;
    // The frame the menu opened, and the last frame the card came back from the confirm or the settings.
    public int shownFrame = -1;
    int restoredFrame = -1, resumedFrame = -1;
    bool ended;

    void Update()
    {
        if (card != null && card.activeInHierarchy && Inputs.Down("pause")) Resume();
    }

    // RESUME, pause or cancel: once, and never from the press that opened the menu or brought the card back.
    public void Resume()
    {
        int now = Time.frameCount;
        // Esc reaches here twice in one frame (pause and cancel): answer once.
        if (ended || now == shownFrame || now == restoredFrame || now == resumedFrame) return;
        resumedFrame = now;
        Debug.Log("flow: pause resumed");
        onResume?.Invoke();
    }

    // KEEP PLAYING or cancel on the confirm: back to the menu.
    public void CloseConfirm()
    {
        if (confirm == null) return;
        // Off at once, so it no longer owns cancel in the frame it is destroyed.
        confirm.SetActive(false);
        Destroy(confirm);
        confirm = null;
        Debug.Log("flow: pause end kept playing");
        Restore();
    }

    // YES, END IT: the caller unpauses and ends the run.
    public void EndRun()
    {
        if (ended) return;
        ended = true;
        Debug.Log("flow: pause end confirmed");
        onEndRun?.Invoke();
    }

    // The card back with RESUME in focus (the confirm or the settings closed).
    public void Restore()
    {
        restoredFrame = Time.frameCount;
        if (card != null) card.SetActive(true);
        UiKit.Focus(resume);
        Debug.Log("flow: pause card back");
    }
}
