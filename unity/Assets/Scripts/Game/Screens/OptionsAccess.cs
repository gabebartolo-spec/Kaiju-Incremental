// Settings > ACCESSIBILITY (scenes/access_menu.gd, D-259): held moves on hold or toggle, reduce flashing, pad
// rumble, gore, and the language (D-392). Every press steps its setting through PlayerSettings, which saves.
using System;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;
using Opt = Kaiju.Game.PlayerSettings;

public static class OptionsAccess
{
    public static OptionsPage Open(Transform host, Selectable opener)
    {
        OptionsPage page = OptionsPage.Open("Accessibility", "ACCESSIBILITY", host, opener);
        Add(page, "Held moves", Opt.ToggleHold, OptionsRows.Held);
        Add(page, "Reduce flashing", Opt.ToggleFlashing, () => OptionsRows.OnOff(Opt.ReduceFlashing));
        Add(page, "Rumble", Opt.ToggleRumble, () => OptionsRows.OnOff(Opt.Rumble));
        Add(page, "Gore", Opt.ToggleGore, OptionsRows.Gore);
        Add(page, "Language", NextLanguage, OptionsRows.Language);
        page.Finish();
        Debug.Log($"flow: settings accessibility shown, 5 rows, language {Tr.Language}");
        return page;
    }

    static void Add(OptionsPage page, string name, Action step, Func<string> value)
    {
        KitButton b = page.Choice(step);
        page.Labels.Add(b, value);
        page.Row(name, b);
    }

    // The open pages re-label themselves; a screen behind Settings hears SettingsScreen.LanguageChanged.
    static void NextLanguage()
    {
        Opt.NextLanguage();
        Debug.Log($"flow: settings language {Tr.Language}");
        SettingsScreen.RaiseLanguageChanged();
    }
}
