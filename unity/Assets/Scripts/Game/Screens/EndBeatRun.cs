// Runs the end beat EndBeat.Show built: the flash fades, the headline slams down to size (Godot's back-out
// tween), and after the beat's length, or a confirm once its least time has shown, it closes and reports.
// Real time, as the Godot tween ignored the time scale.
using System;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

public sealed class EndBeatRun : MonoBehaviour
{
    public Image flash;
    public float flashAlpha;
    public RectTransform headline;
    public S.GDict result;
    public Action<S.GDict> onDone;
    public float elapsed;

    bool done;

    void Update()
    {
        if (done) return;
        elapsed += Time.unscaledDeltaTime;
        Apply();
        if (elapsed >= ResultsBeat.Seconds) Finish(false);
        else if (elapsed >= ResultsBeat.MinSeconds && Inputs.Confirm()) Finish(true);
    }

    // The flash and the headline's size at `elapsed`.
    public void Apply()
    {
        if (flash != null)
        {
            Color c = flash.color;
            // The back-out curve passes its end before settling: an alpha under 0 draws as 0.
            c.a = Mathf.Max(flashAlpha * (1f - (float)ResultsBeat.BackOut(elapsed / EndBeat.FLASH_SECONDS)), 0f);
            flash.color = c;
        }
        if (headline != null)
        {
            float s = Mathf.LerpUnclamped(EndBeat.SLAM_SCALE, 1f, (float)ResultsBeat.BackOut(elapsed / EndBeat.SLAM_SECONDS));
            headline.localScale = new Vector3(s, s, 1f);
        }
    }

    // Only once: closes the beat, then hands the result on.
    public void Finish(bool skipped)
    {
        if (done) return;
        done = true;
        Debug.Log("flow: end beat done, after " + elapsed.ToString("0.00") + " s, skipped " + (skipped ? "yes" : "no"));
        gameObject.SetActive(false);
        Destroy(gameObject);
        onDone?.Invoke(result);
    }
}
