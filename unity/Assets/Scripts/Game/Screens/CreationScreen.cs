// Kaiju Creation (scenes/kaiju_creation.gd): the lab behind, a left column with the rack of genomes, then the dish
// line and INJECT SPECIAL K; the injection, the takeover and the dive to black run by themselves and the species
// is handed back. The steps and their numbers are CreationSteps (plain C#); this draws them and plays their sounds.
using System;
using System.Collections.Generic;
using System.Linq;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;
using S = Kaiju.Sim;

public static class CreationScreen
{
    // The first genome's button and the inject button, by name (the smoke run presses them).
    public const string SmokeButton = "Genome0", InjectButton = "Inject";
    // kaiju_creation.gd: the left column's least width, the gap between lines, the tape along the top (px at 1080p).
    public const float PANEL_WIDTH = 600f, LINE_GAP = 12f, TAPE = 18f;
    public const string HINT = "ENTER / A  CHOOSE      ESC / B  BACK";

    // Opens the lab. `onCreated` gets the species id once, after the black; `onBack` is Esc / B at the rack or the dish.
    public static RectTransform Show(S.GDict save, Action<string> onCreated, Action onBack)
    {
        RectTransform screen = UiKit.Screen("Creation");
        CreationDriver driver = screen.gameObject.AddComponent<CreationDriver>();
        driver.Open(screen, save, onCreated, onBack);
        return screen;
    }
}

// The lab screen's parts and its 60 Hz pacing.
public sealed class CreationDriver : MonoBehaviour
{
    // Godot's cap on physics steps in one frame.
    const int MAX_TICKS = 8;
    const float TICK = 1f / CreationLab.TICKS_PER_SECOND;

    CreationSteps steps;
    CreationLabView view;
    Action<string> created;
    Image white, black;
    GameObject overlay, rackPanel, dishPanel;
    Text dishLine;
    KitButton inject;
    readonly List<KitButton> rack = new List<KitButton>();
    CreationStep shown = CreationStep.Rack;
    float owed;
    bool smoke, handed;

    public void Open(RectTransform screen, S.GDict save, Action<string> onCreated, Action onBack)
    {
        created = onCreated;
        steps = new CreationSteps(save);
        view = CreationLabView.Build(steps.Lab);
        // The canvas covers the lab's camera, so the flat backdrop is only for a lab that could not be built.
        if (view == null) UiKit.Backdrop(screen);
        white = UiKit.Fill(screen, new Color(1f, 1f, 1f, 0f), "Flash");
        overlay = UiKit.Box(screen, "Overlay").gameObject;
        UiKit.FullRect((RectTransform)overlay.transform);
        RectTransform tape = UiKit.Tape(overlay.transform, CreationScreen.TAPE).rectTransform;
        tape.anchorMin = new Vector2(0f, 1f);
        tape.anchorMax = Vector2.one;
        tape.pivot = new Vector2(0.5f, 1f);
        tape.anchoredPosition = Vector2.zero;
        tape.sizeDelta = new Vector2(0f, CreationScreen.TAPE);
        RectTransform column = UiKit.Column(UiKit.SafeArea(overlay.transform), CreationScreen.LINE_GAP * 2f, "Left");
        column.anchorMin = Vector2.zero;
        column.anchorMax = new Vector2(0f, 1f);
        column.pivot = new Vector2(0f, 0.5f);
        column.offsetMin = column.offsetMax = Vector2.zero;
        column.gameObject.AddComponent<ContentSizeFitter>().horizontalFit = ContentSizeFitter.FitMode.PreferredSize;
        UiKit.Header(column, "KAIJU CREATION", UiKit.SIZE_HEAD);
        // The spacer pushes the panels to the foot and holds the column's least width.
        UiKit.Size(UiKit.Box(column, "Spacer"), CreationScreen.PANEL_WIDTH, 0f).flexibleHeight = 1f;
        RectTransform rackBox = UiKit.Panel(column, null, CreationScreen.LINE_GAP);
        rackPanel = rackBox.gameObject;
        UiKit.Label(rackBox, "PICK A GENOME", UiKit.SIZE_HEAD, UiKit.ACCENT);
        for (int i = 0; i < steps.Titans.Count; i++)
        {
            int index = i;
            KitButton b = UiKit.Button(rackBox, Tr.F("%s GENOME", Tr.T(steps.Titans[i].Name)), () => Pick(index), UiKit.SIZE_BODY, UiKit.PANEL_EDGE);
            b.name = "Genome" + i;
            b.interactable = steps.Titans[i].Selectable;
            rack.Add(b);
        }
        RectTransform dishBox = UiKit.Panel(column, null, CreationScreen.LINE_GAP);
        dishPanel = dishBox.gameObject;
        dishLine = UiKit.Label(dishBox, "", UiKit.SIZE_HEAD, UiKit.ACCENT);
        inject = UiKit.Button(dishBox, "INJECT SPECIAL K", Inject, UiKit.SIZE_BODY, UiKit.ACCENT);
        inject.name = CreationScreen.InjectButton;
        dishPanel.SetActive(false);
        UiKit.Label(column, CreationScreen.HINT, UiKit.SIZE_BODY, UiKit.MUTED);
        black = UiKit.Fill(screen, new Color(0f, 0f, 0f, 0f), "Black");
        UiFocus.Column(rack.Cast<Selectable>().ToArray());
        KitButton first = rack.FirstOrDefault(b => b.interactable);
        UiKit.Focus(first);
        UiFocus.OnCancel(gameObject, () => { if (steps.CanBack) onBack?.Invoke(); });
        smoke = Environment.GetCommandLineArgs().Contains("-flow-smoke");
        PlaySounds();
        Debug.Log("flow: creation shown, " + steps.Titans.Count + " genomes, lab " + (view != null ? view.Props + " of 5 models" : "flat"));
    }

    void Pick(int index)
    {
        if (steps.Step != CreationStep.Rack) return;
        steps.Pick(index);
        foreach (KitButton b in rack) b.interactable = false;
    }

    void Inject()
    {
        if (steps.Step != CreationStep.Dish) return;
        steps.Inject();
        overlay.SetActive(false);
    }

    void Update()
    {
        if (steps == null || handed) return;
        // The smoke run needs no hands: the first genome, then the injection.
        if (smoke && !FlowStills.Busy && steps.Step == CreationStep.Rack && rack.Count > 0) rack[0].onClick.Invoke();
        if (smoke && !FlowStills.Busy && steps.Step == CreationStep.Dish && shown == CreationStep.Dish) inject.onClick.Invoke();
        if (steps.Step == CreationStep.Rack)
            for (int i = 0; i < rack.Count; i++)
                if (UiFocus.Current == rack[i] && steps.Lab.Focused != i) steps.Lab.Focus(i);
        owed += Time.deltaTime;
        for (int n = 0; n < MAX_TICKS && owed >= TICK; n++)
        {
            owed -= TICK;
            steps.Tick();
        }
        if (owed > TICK) owed = TICK;
        PlaySounds();
        if (steps.Step != shown) Stepped();
        white.color = new Color(1f, 1f, 1f, Mathf.Clamp01((float)(steps.Lab.Flash * PlayerSettings.FlashScale())));
        black.color = new Color(0f, 0f, 0f, Mathf.Clamp01((float)steps.Black));
        if (view != null) view.Draw(steps.Lab);
        if (steps.Step != CreationStep.Done) return;
        handed = true;
        Debug.Log("flow: creation made " + steps.Species + ", " + steps.Cues.Count + " sound cues");
        created?.Invoke(steps.Species);
    }

    // What the screen shows changes with the step: the genome is in the dish, so the rack gives way to INJECT.
    void Stepped()
    {
        shown = steps.Step;
        if (shown != CreationStep.Dish) return;
        rackPanel.SetActive(false);
        dishLine.text = Tr.F("%s GENOME IN THE DISH", Tr.T(steps.Titans[steps.Picked].Name));
        dishPanel.SetActive(true);
        UiKit.Focus(inject);
    }

    void PlaySounds()
    {
        foreach (CreationSound s in steps.Sounds)
        {
            if (s.What == CreationSound.Kind.Loop) Sfx.Loop(s.Id);
            else if (s.What == CreationSound.Kind.Play) Shot(s);
            else if (Sfx.Looping(s.Id)) Sfx.Stop(s.Id);
            else StopShots(s.Id);
        }
        steps.Sounds.Clear();
    }

    // The one-shots this screen started (kaiju_creation.gd _shots), so the black can stop them.
    readonly List<(AudioChannel c, float asked)> shots = new List<(AudioChannel, float)>();

    // kaiju_creation.gd _play on a player of its own; an egg crack plays its cut (crack.play(from_s), freed after len_s).
    void Shot(CreationSound s)
    {
        AudioHost host = AudioHost.Ensure();
        AudioRow row = host.Table.Get(s.Id);
        if (row == null)
        {
            Sfx.Play(s.Id);  // logs the unknown sound once
            return;
        }
        AudioChannel c = host.Direct();
        host.Begin(c, s.Id, row.file, row.bus, row.db, 1.0, s.From, false);
        Sfx.Note(s.Id, "sfx: " + s.Id + (s.Len > 0 ? $" (cut {s.From:0.##}+{s.Len:0.##} s)" : ""));
        shots.RemoveAll(p => p.c.asked != p.asked || !host.Sounding(p.c));
        shots.Add((c, c.asked));
        // The cut's end outlives the screen, as Godot's timer on the root does.
        if (s.Len > 0) host.StartCoroutine(EndCut(host, c, c.asked, (float)s.Len));
    }

    static System.Collections.IEnumerator EndCut(AudioHost host, AudioChannel c, float asked, float len)
    {
        yield return new WaitForSecondsRealtime(len);
        if (c.asked == asked) host.Halt(c);
    }

    void StopShots(string id)
    {
        AudioHost host = AudioHost.I;
        if (host == null) return;
        foreach ((AudioChannel c, float asked) in shots)
            if (c.id == id && c.asked == asked) host.Halt(c);
    }

    // Godot's loops die with the screen.
    void OnDestroy()
    {
        if (steps != null)
            foreach (string id in steps.Held())
                if (Sfx.Looping(id)) Sfx.Stop(id);
        if (view != null) view.Close();
        view = null;
    }
}
