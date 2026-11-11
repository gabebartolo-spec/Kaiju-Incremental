// The graphics preview beside Settings (scenes/graphics_preview.gd): a card with the level in use and the
// frame rate under a 16:9 view. The view is a flat panel for now: Godot's burning street corner is not built,
// because the graphics levels change nothing in the Unity renderer yet. While it is open the menu frame cap
// is lifted to the player's own (PlayerSettings.Previewing), so the frame rate shown is the real one.
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;
using Opt = Kaiju.Game.PlayerSettings;

public sealed class OptionsPreview : MonoBehaviour
{
    // The view's size at 1080p (px), 16:9, and its backdrop (graphics_preview.gd VIEW, the viewport's clear colour).
    public const float VIEW_WIDTH = 420f, VIEW_HEIGHT = 236f;
    public static readonly Color VIEW_BACK = new Color32(0x1a, 0x1c, 0x24, 0xff);
    // The frame rate is counted over this long, as Godot's Engine.get_frames_per_second.
    const float COUNT_SECONDS = 1f;

    Text line;
    int frames;
    float since;
    float fps;

    public static OptionsPreview Build(Transform parent)
    {
        RectTransform card = UiKit.Panel(parent);
        Text title = UiKit.Label(card, "PREVIEW", UiKit.SIZE_BODY, UiKit.ACCENT);
        title.alignment = TextAnchor.MiddleCenter;
        Image view = UiKit.Box(card, "View").gameObject.AddComponent<Image>();
        view.color = VIEW_BACK;
        view.raycastTarget = false;
        UiKit.Size(view, VIEW_WIDTH, VIEW_HEIGHT);
        OptionsPreview p = card.gameObject.AddComponent<OptionsPreview>();
        p.line = UiKit.Label(card, "", UiKit.SIZE_SMALL);
        p.line.alignment = TextAnchor.MiddleCenter;
        p.fps = Time.unscaledDeltaTime > 0f ? 1f / Time.unscaledDeltaTime : 0f;
        p.title = title;
        Opt.Previewing = true;
        p.Refresh();
        return p;
    }

    Text title;

    void Update()
    {
        frames++;
        since += Time.unscaledDeltaTime;
        if (since >= COUNT_SECONDS)
        {
            fps = frames / since;
            frames = 0;
            since = 0f;
        }
        Refresh();
    }

    void Refresh()
    {
        string now = OptionsRows.PreviewText(Opt.GraphicsLevel(), fps);
        if (line.text != now) line.text = now;
        string head = Tr.T("PREVIEW");
        if (title.text != head) title.text = head;
    }

    void OnDestroy()
    {
        Opt.Previewing = false;
    }
}
