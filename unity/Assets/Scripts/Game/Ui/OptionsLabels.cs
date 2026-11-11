// The settings screens' texts, re-read every frame (settings_menu.gd and options_page.gd _process > _refresh):
// a value steps the moment its setting does, and a language change re-labels the open page, names and all.
// Update runs while the rampage is paused (the pause does not stop the clock).
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public sealed class OptionsLabels : MonoBehaviour
{
    readonly List<(Text label, Func<string> text)> labels = new List<(Text, Func<string>)>();
    readonly List<Action> steps = new List<Action>();

    // `label` shows text() from now on.
    public void Add(Text label, Func<string> text)
    {
        if (label == null) return;
        labels.Add((label, text));
        label.text = text();
    }

    public void Add(KitButton button, Func<string> text)
    {
        if (button != null) Add(button.label, text);
    }

    // The name label of a UiKit.OptionRow or the row of a UiKit.SliderRow: its first child.
    public void AddName(Transform row, Func<string> text)
    {
        Add(row.GetChild(0).GetComponent<Text>(), text);
    }

    // Anything else to do each frame (a slider following its setting).
    public void Each(Action step)
    {
        steps.Add(step);
        step();
    }

    void Update()
    {
        foreach ((Text label, Func<string> text) in labels)
        {
            if (label == null) continue;
            string now = text();
            if (label.text != now) label.text = now;
        }
        foreach (Action step in steps) step();
    }
}
