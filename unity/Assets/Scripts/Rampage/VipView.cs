using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

// The leader's escape helicopter on screen (D-149): scenes/vip_view.gd and helicopter_model.gd's vip_look.
// The white-and-gold model flies the sim's path (banking into its lap, leaning into its dash) under a blinking
// gold lamp, and each beat (lift-off, kill, escape) gets one headline along the bottom. ArmyView builds the
// model and plays its fall, burst and crash as a gunship's (heli_wreck.gd), so heli_crashed is not handled
// here. The sim (VipHeli) decides everything; this reads its state and events. Numbers: tuning "vip".
public sealed class VipView
{
    const string PARTS = "res://assets/vehicles/vip_heli.parts.json";
    // scenes/news_ticker.gd HEIGHT and TAG_WIDTH, scenes/ui_kit.gd SIZE_BODY and SIZE_HEAD: pixels at 1080p.
    const float STRIP_HEIGHT = 56f, TAG_WIDTH = 350f, UI_HEIGHT = 1080f;
    const int SIZE_BODY = 24, SIZE_HEAD = 36;
    // scenes/ui_kit.gd CRAWL_RED, BG and ACCENT.
    static readonly Color CRAWL_RED = Hex("d42a1f"), BG = Hex("0b0b0d"), ACCENT = Hex("ffcc00");

    readonly S.RampageSim sim;
    readonly ArmyView army;
    readonly S.GDict cfg, look, lamp, parts;
    readonly Color white, gold;
    readonly int whiteRgb, goldRgb;
    readonly float dark, bandFrom, bandTo, lightIntensity;
    Transform model;
    GameObject beacon;
    float yaw, clock, headlineLeft;
    string headline;
    GUIStyle tagStyle, lineStyle;

    public int Spawned { get; private set; }
    public int Downed { get; private set; }
    public int Escaped { get; private set; }
    // The strip's line now, or null: IMGUI never reaches a clip's frames, so the log and this are its proof.
    public string Headline => headline;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    static Color Hex(string hex)
    {
        ColorUtility.TryParseHtmlString("#" + hex, out Color c);
        return c;
    }

    static int Rgb(Color color)
    {
        Color32 c = color;
        return c.r << 16 | c.g << 8 | c.b;
    }

    public VipView(S.RampageSim sim, ArmyView army, float exposureUnit, float lightMatch)
    {
        this.sim = sim;
        this.army = army;
        cfg = S.Content.Section("vip");
        look = cfg["look"];
        lamp = cfg["beacon"];
        parts = S.Content.LoadJson(PARTS);
        white = Hex(S.Gd.Str(look["white"]));
        gold = Hex(S.Gd.Str(look["gold"]));
        whiteRgb = Rgb(white);
        goldRgb = Rgb(gold);
        S.GDict vehicles = S.Content.Section("vehicles");
        dark = F(vehicles, "vip_dark");
        S.GArray<S.Variant> band = vehicles["vip_band"];
        bandFrom = (float)(double)S.Num.F(band[0]);
        bandTo = (float)(double)S.Num.F(band[1]);
        // CityFx.FlashLight's units: one Godot light energy in candela.
        lightIntensity = F(lamp, "light") * Mathf.PI * exposureUnit * lightMatch;
    }

    public void OnEvent(S.GDict e)
    {
        switch (S.Gd.Str(e["type"]))
        {
            case "vip_spawned":
                Spawn();
                Show("liftoff", S.Gd.Str(e["rank"]));
                break;
            case "vip_down":
                Down(e);
                break;
            case "vip_killed":
                Show("killed", S.Gd.Str(e["rank"]));
                break;
            case "vip_escaped":
                army.RemoveHeli(S.VipHeli.ID);  // and its lamp with it
                model = null;
                beacon = null;
                Escaped++;
                Debug.Log($"vip escaped frame {Time.frameCount}");
                Show("escaped", S.Gd.Str(e["rank"]));
                break;
        }
    }

    // helicopter_model.gd vip_look: gold rotors, a white body with a gold band, its dark glass and skids left alone.
    bool[] Paint(string part, ModelColors.Model voxels)
    {
        bool body = part == "body";
        return VipPaint.Paint(voxels.xyz.Raw, voxels.rgb, body ? whiteRgb : goldRgb, goldRgb, body ? dark : 0f, bandFrom, bandTo);
    }

    void Spawn()
    {
        model = army.BuildHeli(S.VipHeli.ID, parts, "vip", white, gold, Paint);
        model.position = At();
        yaw = 0f;
        Beacon();
        Spawned++;
        Debug.Log($"vip spawned frame {Time.frameCount} at {sim.vip.pos.x:F2},{sim.vip.Altitude():F2},{sim.vip.pos.y:F2} rank {sim.vip.rank}");
    }

    // The sim's place in Unity's axes.
    Vector3 At() => new Vector3((float)(double)sim.vip.pos.x, (float)sim.vip.Altitude(), -(float)(double)sim.vip.pos.y);

    // vip_view.gd _lamp: a blinking gold lamp on the mast and its light on the roofs, so it reads at dusk as the leader.
    void Beacon()
    {
        beacon = new GameObject("vip_beacon");
        beacon.transform.SetParent(model, false);
        beacon.transform.localPosition = new Vector3(0f, F(lamp, "height"), 0f);
        army.GlowBox(gold, Vector3.zero, F(lamp, "size"), beacon.transform);
        var go = new GameObject("vip_light");
        go.transform.SetParent(beacon.transform, false);
        Light light = go.AddComponent<Light>();
        light.type = LightType.Point;
        light.shadows = LightShadows.None;
        light.lightUnit = UnityEngine.Rendering.LightUnit.Candela;
        go.AddComponent<HDAdditionalLightData>();
        light.color = gold;
        light.range = F(lamp, "range");
        light.intensity = lightIntensity;
    }

    // Shot down: ArmyView's wreck takes the model on this same event; only the lamp goes here.
    void Down(S.GDict e)
    {
        if (model == null) return;
        Object.Destroy(beacon);
        beacon = null;
        model = null;
        Downed++;
        Debug.Log($"vip down frame {Time.frameCount} fate {S.Gd.Str(e["fate"])}");
    }

    // One line on the strip along the bottom, from data, for a few seconds.
    void Show(string key, string rank)
    {
        S.GDict lines = cfg["headlines"];
        headline = S.Gd.Str(lines[key]).Replace("{rank}", rank);
        // the swatted headline stays up killed_seconds with play running on, then slides away
        headlineLeft = F(cfg, key == "killed" ? "killed_seconds" : "headline_seconds");
        Debug.Log($"vip headline frame {Time.frameCount}: {headline}");
    }

    // Per frame, after army.Update: the model on the sim's flight, the lamp's blink and the headline's time.
    public void Step(float dt)
    {
        clock += dt;
        if (beacon != null) beacon.SetActive(Mathf.Repeat(clock, F(lamp, "period")) < F(lamp, "on"));
        if (headline != null)
        {
            headlineLeft -= dt;
            if (headlineLeft <= 0f) headline = null;
        }
        if (model == null || !sim.vip.Flying()) return;
        S.VipHeli vip = sim.vip;
        float heading = (float)vip.heading;
        float want = Mathf.Atan2(-Mathf.Cos(heading), -Mathf.Sin(heading));
        yaw = Mathf.LerpAngle(yaw * Mathf.Rad2Deg, want * Mathf.Rad2Deg, Mathf.Min(1f, dt * F(look, "turn"))) * Mathf.Deg2Rad;
        army.HeliYaw(S.VipHeli.ID, yaw);  // a spinning fall turns on from this heading
        model.position = At();
        // Godot's rotation (-pitch * speed, yaw, -bank * turn_rate) through the z mirror: x and y turn the other way.
        model.rotation = Quaternion.Euler(
            F(look, "pitch") * (float)vip.speed * Mathf.Rad2Deg, -yaw * Mathf.Rad2Deg, -F(look, "bank") * (float)vip.turnRate * Mathf.Rad2Deg);
    }

    // A stand-in for scenes/news_ticker.gd until the HUD is ported: the red strip, the black BREAKING tag and
    // the held line, sliding down off the screen over its last slide_seconds. Call from OnGUI.
    public void DrawHeadline()
    {
        if (headline == null) return;
        float k = Screen.height / UI_HEIGHT;
        float height = STRIP_HEIGHT * k, tag = TAG_WIDTH * k;
        float gone = 1f - Mathf.Clamp01(headlineLeft / Mathf.Max(F(cfg, "slide_seconds"), 0.001f));
        float top = Screen.height - height * (1f - gone);
        if (tagStyle == null)
        {
            tagStyle = new GUIStyle(GUI.skin.label) { alignment = TextAnchor.MiddleCenter, fontStyle = FontStyle.Bold, normal = { textColor = ACCENT } };
            lineStyle = new GUIStyle(GUI.skin.label) { alignment = TextAnchor.MiddleLeft, normal = { textColor = Color.white } };
        }
        tagStyle.fontSize = Mathf.RoundToInt(SIZE_HEAD * k);
        lineStyle.fontSize = Mathf.RoundToInt(SIZE_BODY * k);
        Color before = GUI.color;
        GUI.color = CRAWL_RED;
        GUI.DrawTexture(new Rect(0f, top, Screen.width, height), Texture2D.whiteTexture);
        GUI.color = BG;
        GUI.DrawTexture(new Rect(0f, top, tag, height), Texture2D.whiteTexture);
        GUI.color = before;
        GUI.Label(new Rect(0f, top, tag, height), "BREAKING", tagStyle);
        GUI.Label(new Rect(tag, top, Screen.width - tag, height), "  " + headline, lineStyle);
    }
}
