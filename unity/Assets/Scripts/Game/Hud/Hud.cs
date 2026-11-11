using System;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

// scenes/rampage_hud.gd: the rampage HUD, as little as it can be: the clock and the threat bar on top, biomass
// bottom right, the breath, dash and ultimate rings bottom left, health as a red edge, the controls card at the
// first rampage's start, the news strip on big moments, then the end beat. Reads the sim; decides nothing.
public sealed class Hud : MonoBehaviour
{
    // Godot's default gap between a VBoxContainer's children (the end beat's two lines), px.
    const float BEAT_GAP = 4f;

    // Raised once when the end beat is over, with the run's result (rampage_hud.gd beat_done).
    public Action<S.GDict> BeatDone;
    public bool BeatRunning => beatT >= 0f && !beatDone;
    public bool BeatIsDone => beatDone;
    public int Widgets { get; private set; }

    RampageGame game;
    S.RampageSim sim;
    S.GDict cfg;
    CanvasGroup widgets;
    RectTransform clock;
    Text time, biomass, headline;
    HudThreat threat;
    HudRing breathRing, dashRing, ultimateRing;
    HudVignette vignette;
    HudNews news;
    HudAim aim;
    RectTransform card;
    CanvasGroup cardGroup;
    Image flash;
    long lastSecond = -1;
    double shownBiomass, lastBiomass;
    float pulseT = -1f, popT = -1f, fadeT = -1f, fadeS;
    float cardLeft, cardAge, cardFadeT = -1f, cardFadeS;
    float beatT = -1f, flashAlpha;
    bool beatDone, emerged, logged, beatSkipped;

    // Builds the HUD over `game`'s run and follows it frame by frame (RampageGame.Ticked).
    public static Hud Attach(RampageGame game)
    {
        RectTransform root = UiKit.Screen("Hud");
        Hud hud = root.gameObject.AddComponent<Hud>();
        hud.game = game;
        hud.sim = game.Sim;
        hud.Build();
        game.Ticked += hud.Tick;
        return hud;
    }

    void Build()
    {
        S.GDict ui = UiKit.Ui();
        cfg = ui["hud"];
        S.GDict intro = S.Content.Section("intro");
        fadeS = (float)S.Num.F(intro["hud_fade_seconds"]);
        RectTransform all = UiKit.Box(transform, "Widgets");
        UiKit.FullRect(all);
        widgets = all.gameObject.AddComponent<CanvasGroup>();
        widgets.blocksRaycasts = false;
        widgets.interactable = false;
        // Hidden through the rise from the bay (rampage_rise.gd); it fades in when he is up.
        widgets.alpha = 0f;
        vignette = HudVignette.Create(all);
        RectTransform safe = UiKit.SafeArea(all);
        news = HudNews.Create(all);
        BuildClock(safe);
        float lift = (float)HudText.Lift(S.Num.F(cfg["bottom_margin"]), UiKit.SafeMargin().y);
        BuildBiomass(safe, lift);
        BuildRings(safe, lift);
        Widgets = 8;  // clock, threat bar, biomass, three rings, hurt edge, news strip
        if (!PlayerSettings.ControlsSeen)
        {
            ShowControls(safe, ui["controls_card"]);
            Widgets++;
        }
        S.GDict colours = game.Species["colors"];
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(colours["eye"]), out Color eye);
        aim = new HudAim(sim, eye, game.ExposureUnit, (float)S.Num.F(intro["aim_fade_seconds"]));
        shownBiomass = lastBiomass = (double)sim.rubble;
        Refresh();
    }

    // hud_clock.gd: the clock over the threat bar, top centre of the safe area.
    void BuildClock(RectTransform safe)
    {
        clock = UiKit.Column(safe, (float)S.Num.F(cfg["meter_gap"]), "Clock");
        clock.anchorMin = clock.anchorMax = clock.pivot = new Vector2(0.5f, 1f);
        clock.anchoredPosition = Vector2.zero;
        UiKit.Fit(clock);
        time = UiKit.Label(clock, "", (int)S.Num.I(cfg["clock_size"]), Color.white);
        time.alignment = TextAnchor.UpperCenter;
        // The digits keep a least width, so the box does not jump as they change; the pulse grows from the middle.
        time.gameObject.AddComponent<LayoutElement>().minWidth = (float)HudText.CLOCK_MIN_WIDTH;
        time.rectTransform.pivot = new Vector2(0.5f, 0.5f);
        threat = HudThreat.Create(clock);
    }

    // One boxless outlined figure in the bottom right; the pop grows from its bottom right corner.
    void BuildBiomass(RectTransform safe, float lift)
    {
        RectTransform col = UiKit.Column(safe, 0f, "Biomass");
        col.anchorMin = col.anchorMax = col.pivot = new Vector2(1f, 0f);
        col.anchoredPosition = new Vector2(0f, lift);
        UiKit.Fit(col);
        Text word = UiKit.Label(col, "BIOMASS", UiKit.SIZE_BODY, UiKit.TEXT);
        word.alignment = TextAnchor.UpperRight;
        biomass = UiKit.Label(col, "0", (int)S.Num.I(cfg["biomass_size"]), UiKit.ACCENT);
        biomass.alignment = TextAnchor.UpperRight;
        biomass.rectTransform.pivot = new Vector2(1f, 0f);
    }

    // Three rings in the bottom left: the breath, the dash and the ultimate.
    void BuildRings(RectTransform safe, float lift)
    {
        RectTransform row = UiKit.Row(safe, (float)S.Num.F(cfg["ring_gap"]), "Rings");
        row.anchorMin = row.anchorMax = row.pivot = Vector2.zero;
        row.anchoredPosition = new Vector2(0f, lift);
        UiKit.Fit(row);
        float big = (float)S.Num.F(cfg["ring_radius"]), small = (float)S.Num.F(cfg["ring_small_radius"]);
        float w = (float)S.Num.F(cfg["ring_width"]);
        breathRing = HudRing.Create(row, "breath", big, w);
        dashRing = HudRing.Create(row, "dash", small, w);
        ultimateRing = HudRing.Create(row, "ultimate", small, w);
        foreach (HudRing ring in new[] { breathRing, dashRing, ultimateRing }) ring.rectTransform.pivot = new Vector2(0.5f, 0.5f);
    }

    // The controls, once: a card in the bottom left, above the rings; Settings > CONTROLS has them for good.
    void ShowControls(RectTransform safe, S.GDict cardCfg)
    {
        card = HudControlsCard.Create(safe, true);
        card.anchorMin = card.anchorMax = card.pivot = Vector2.zero;
        card.anchoredPosition = new Vector2(0f, (float)S.Num.F(cardCfg["first_run_lift"]));
        cardGroup = card.gameObject.AddComponent<CanvasGroup>();
        cardGroup.blocksRaycasts = false;
        cardLeft = (float)S.Num.F(cardCfg["seconds"]);
        cardFadeS = (float)S.Num.F(cardCfg["fade_s"]);
        // A standalone -rampage-hud run never booted the user folder (UserDir.Root ""): no settings.json to write.
        if (UserDir.Root.Length > 0) PlayerSettings.MarkControlsSeen();
    }

    // One sim event (RampageGame hands each over as it steps): the news strip's big moments.
    public void OnEvent(S.GDict e)
    {
        news.OnEvent(e);
    }

    // rampage_hud.gd refresh: the sim's numbers onto the widgets.
    void Refresh()
    {
        bool endless = sim.endless != null;
        long second = HudText.Second((double)sim.timeLeft);
        time.text = HudText.Clock((double)sim.timeLeft, (double)sim.elapsed, endless);
        bool hurry = HudText.Hurry((double)sim.timeLeft, endless, S.Num.F(cfg["hurry_seconds"]));
        time.color = hurry ? UiKit.ALERT : Color.white;
        if (HudText.HurryPulse(hurry, second, lastSecond, sim.over)) pulseT = 0f;
        lastSecond = second;
        threat.ShowLevel(S.Num.I(sim.news.level), 0.0);
        double gain = (double)sim.rubble - lastBiomass;
        lastBiomass = (double)sim.rubble;
        if (HudText.Pops(gain, S.Num.F(cfg["biomass_pop_gain"])) && popT < 0f) popT = 0f;
        double breathIn = HudText.BreathIn(sim.abilityType, (double)sim.breathReadyIn, (double)sim.abilityReadyIn);
        breathRing.SetRatio(HudText.Ratio(breathIn, (double)sim.Stat("ability_cooldown"), 0.5));
        ultimateRing.Show(sim.powers.HasUltimate());
        ultimateRing.SetRatio(HudText.Ratio((double)sim.ultimateReadyIn, S.Num.F(sim.powersCfg["ultimate_cooldown"]), 0.001));
        S.Dash dash = sim.body.dash;
        dashRing.Show(dash.Available());
        if (dash.Available()) dashRing.SetRatio(HudText.Ratio((double)dash.readyIn, (double)dash.Cooldown(), 0.001));
    }

    // Once a frame after the sim stepped; `dt` is 0 while the run is paused.
    public void Tick(float dt)
    {
        if (beatDone) return;
        Inputs.Poll();
        Refresh();
        vignette.Step((double)sim.hp, (double)sim.maxHp, dt);
        news.Tick(dt);
        aim.Step(dt);
        // The figure rolls toward the true biomass rather than ticking digit by digit.
        shownBiomass = HudText.Roll(shownBiomass, (double)sim.rubble, S.Num.F(cfg["biomass_roll_rate"]), dt);
        biomass.text = HudText.Biomass(shownBiomass);
        Animate(dt);
        StepCard(dt);
        if (!emerged && !sim.emerge.active)
        {
            emerged = true;
            fadeT = 0f;
        }
        if (fadeT >= 0f && fadeT < fadeS) fadeT += dt;
        float shown = !emerged ? 0f : fadeS <= 0f ? 1f : Mathf.Clamp01(fadeT / fadeS);
        // Hidden while the pause menu is up (rampage_hud.gd pause).
        widgets.alpha = game.Paused ? 0f : shown;
        if (emerged && !logged)
        {
            logged = true;
            Debug.Log($"hud: shown, {Widgets} widgets");
        }
        if (BeatRunning) StepBeat(Time.unscaledDeltaTime);
    }

    void Animate(float dt)
    {
        if (pulseT >= 0f)
        {
            pulseT += dt;
            float seconds = (float)S.Num.F(cfg["hurry_pulse_s"]);
            float s = (float)HudText.Linear(S.Num.F(cfg["hurry_pulse_scale"]), 1.0, pulseT, seconds);
            time.rectTransform.localScale = new Vector3(s, s, 1f);
            if (pulseT >= seconds) pulseT = -1f;
        }
        if (popT >= 0f)
        {
            popT += dt;
            float seconds = (float)S.Num.F(cfg["biomass_pop_s"]);
            float s = (float)HudText.BackOut(S.Num.F(cfg["biomass_pop_scale"]), 1.0, popT, seconds);
            biomass.rectTransform.localScale = new Vector3(s, s, 1f);
            if (popT >= seconds) popT = -1f;
        }
        float readyScale = (float)S.Num.F(cfg["ring_ready_scale"]), readyS = (float)S.Num.F(cfg["ring_ready_s"]);
        breathRing.Step(dt, readyScale, readyS);
        dashRing.Step(dt, readyScale, readyS);
        ultimateRing.Step(dt, readyScale, readyS);
    }

    // The card goes after its seconds, or on any key once it has been up long enough that the key which
    // started the run is not "any key".
    void StepCard(float dt)
    {
        if (card == null) return;
        if (cardFadeT < 0f)
        {
            cardLeft -= dt;
            cardAge += dt;
            if (cardLeft <= 0f || (cardAge > HudText.CARD_MIN_SHOWN && dt > 0f && Inputs.AnyDown())) cardFadeT = 0f;
            return;
        }
        cardFadeT += dt;
        cardGroup.alpha = (float)HudText.Linear(1.0, 0.0, cardFadeT, cardFadeS);
        if (cardFadeT < cardFadeS) return;
        Destroy(card.gameObject);
        card = null;
    }

    // The rampage is over (the sim said so): why it ended slams onto the screen while the city keeps falling.
    public void RunOver(string reason)
    {
        if (beatT >= 0f) return;
        Refresh();
        beatT = 0f;
        clock.gameObject.SetActive(false);
        news.Mute();
        flashAlpha = (float)(HudText.BEAT_FLASH_ALPHA * PlayerSettings.FlashScale());  // Reduce flashing
        flash = UiKit.Fill(transform, new Color((float)HudText.BEAT_FLASH_R, (float)HudText.BEAT_FLASH_G, (float)HudText.BEAT_FLASH_B, flashAlpha), "Flash");
        flash.raycastTarget = false;
        RectTransform col = UiKit.Column(transform, BEAT_GAP, "EndBeat");
        col.anchorMin = col.anchorMax = col.pivot = new Vector2(0.5f, 1f);
        col.anchoredPosition = new Vector2(0f, -(float)HudText.BEAT_TOP);
        UiKit.Fit(col);
        string[] lines = HudText.Headline(reason);
        headline = UiKit.Label(col, lines[0], HudText.BEAT_SIZE, UiKit.ACCENT);
        headline.alignment = TextAnchor.UpperCenter;
        headline.rectTransform.pivot = new Vector2(0.5f, 0.5f);
        Text sub = UiKit.Label(col, lines[1], UiKit.SIZE_HEAD, UiKit.TEXT);
        sub.alignment = TextAnchor.UpperCenter;
        StepBeat(0f);
    }

    // The beat runs on real time (Godot's tween ignores the time scale); a confirm ends it once it has shown
    // long enough that a held attack button cannot skip it by accident.
    void StepBeat(float dt)
    {
        beatT += dt;
        float s = (float)HudText.BackOut(HudText.BEAT_LAND_SCALE, 1.0, beatT, HudText.BEAT_LAND_SECONDS);
        headline.rectTransform.localScale = new Vector3(s, s, 1f);
        Color c = flash.color;
        c.a = (float)HudText.Linear(flashAlpha, 0.0, beatT, HudText.BEAT_FLASH_SECONDS);
        flash.color = c;
        // A skipping confirm ends the beat next frame, so the results' focused Go cannot take the same press
        // (rampage_hud.gd set_input_as_handled).
        if (beatT >= HudText.BEAT_SECONDS || beatSkipped) FinishBeat();
        else if (beatT >= HudText.BEAT_MIN_SECONDS && Inputs.Confirm()) beatSkipped = true;
    }

    // Ends the end beat now; the report takes over the screen and the city stays behind it.
    public void FinishBeat()
    {
        if (!BeatRunning) return;
        beatDone = true;
        gameObject.SetActive(false);
        BeatDone?.Invoke(game.Result);
    }

    void OnDestroy()
    {
        if (game != null) game.Ticked -= Tick;
        aim?.Dispose();
    }
}
