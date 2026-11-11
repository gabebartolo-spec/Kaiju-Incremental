// The evolution tree as a map (scenes/tree_area.gd, D-275): the specimen plate, its graticule, a dish rim round
// each ring, glass tubes between linked nodes, and every node where the camera shows it. The mouse wheel zooms
// toward the cursor and a left-drag pans; WASD, the arrows and the right stick pan; the triggers zoom. The fx
// (motes, surges, bubbles, the scan band, the specimen at the centre) are not drawn yet (D-476: numbers first).
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using S = Kaiju.Sim;

public sealed class TreePlate : MaskableGraphic, IScrollHandler, IDragHandler
{
    // tree_area.gd: a link's core at the default zoom, and the thinnest any line is drawn.
    const float LINK_WIDTH = 4f, LINK_MIN_WIDTH = 1.5f;
    const int RIM_STEPS = 128;

    public S.UpgradeTree tree;
    public TreeLayout layout;
    public TreeView view;
    public readonly Dictionary<string, TreeNodeButton> buttons = new Dictionary<string, TreeNodeButton>();
    // False while something over the tree holds the keys (the evolution reveal).
    public bool live = true;
    S.GDict cfg, skin;
    S.Vector2 pending;
    bool hasPending;
    Action next;

    // The area's size in canvas px (0 until the layout has run).
    public Vector2 Size => rectTransform.rect.size;

    public void Setup(S.UpgradeTree upgradeTree, Func<string, TreeNodeButton> make)
    {
        tree = upgradeTree;
        cfg = S.Content.Section("tree")["view"];
        skin = S.Content.Section("tree")["skin"];
        layout = TreeLayout.Build(tree, TreeText.Ultimates(tree));
        view = new TreeView(layout.bounds, V(Size), S.Num.F(cfg["fit_margin"]));
        foreach (string id in tree.order) buttons[id] = make(id);
        Resized();
    }

    // Runs `action` on the next frame (Godot's call_deferred).
    public void Defer(Action action)
    {
        next += action;
    }

    // Centres the view on node `id` (as near as the clamps allow), now or once the area has a size.
    public void CentreOn(string id)
    {
        if (!layout.centres.ContainsKey(id)) return;
        pending = layout.centres[id];
        hasPending = true;
        if (Size.x > 0f && Size.y > 0f)
        {
            view.LookAt(pending);
            Place();
        }
    }

    protected override void OnRectTransformDimensionsChange()
    {
        base.OnRectTransformDimensionsChange();
        if (view != null) Resized();
    }

    void Resized()
    {
        view.Resize(V(Size));
        if (hasPending && Size.x > 0f && Size.y > 0f) view.LookAt(pending);
        Place();
    }

    // A node reached by the keyboard or pad comes into view.
    public void Focused(string id)
    {
        S.Rect2 box = layout.Rect(id);
        S.Vector2 at = view.ToScreen(box.position), end = view.ToScreen(box.end);
        if (at.x >= 0.0 && at.y >= 0.0 && end.x <= Size.x && end.y <= Size.y) return;
        view.LookAt(layout.centres[id]);
        Place();
    }

    // Puts every node where the camera shows it, at the camera's zoom.
    public void Place()
    {
        float zoom = (float)view.zoom;
        foreach (string id in tree.order)
        {
            RectTransform rt = (RectTransform)buttons[id].transform;
            S.Vector2 at = view.ToScreen(layout.Rect(id).position);
            rt.localScale = new Vector3(zoom, zoom, 1f);
            rt.anchoredPosition = new Vector2((float)at.x, -(float)at.y);
        }
        SetVerticesDirty();
    }

    public void Redraw()
    {
        SetVerticesDirty();
    }

    // A node's centre in the area (px from its top left).
    public Vector2 CentreOf(string id)
    {
        return U(view.ToScreen(layout.centres[id]));
    }

    static S.Vector2 V(Vector2 v) { return new S.Vector2(v.x, v.y); }
    static Vector2 U(S.Vector2 v) { return new Vector2((float)v.x, (float)v.y); }

    bool Shown(string id)
    {
        return buttons.TryGetValue(id, out TreeNodeButton b) && b.gameObject.activeSelf;
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        if (view == null) return;
        Rect area = GetPixelAdjustedRect();
        UiPen pen = new UiPen(vh, area);
        pen.Box(new Rect(0f, 0f, area.width, area.height), TreeNodeButton.Skin("plate"));
        DrawGrid(pen, area);
        DrawRims(pen);
        float width = Mathf.Max(LINK_MIN_WIDTH, LINK_WIDTH * (float)view.zoom);
        float tubeWidth = width + (float)S.Num.F(skin["tube_extra"]) * (float)view.zoom;
        // Two passes: the glass, then what runs inside it.
        for (int pass = 0; pass < 2; pass++)
        {
            foreach (TreeLayout.Link link in layout.links)
            {
                if (!Shown(link.from) || !Shown(link.to)) continue;
                Color c = pass == 0 ? TreeNodeButton.Skin("tube") : TreeNodeButton.Skin(tree.Level(link.from) > 0 ? "juice" : "empty");
                pen.Line(CentreOf(link.from), CentreOf(link.to), c, pass == 0 ? tubeWidth : width);
            }
        }
    }

    // The plate's graticule: a line every grid_step canvas units, fixed to the tree.
    void DrawGrid(UiPen pen, Rect area)
    {
        double step = S.Num.F(skin["grid_step"]);
        if (step <= 0.0) return;
        Color c = TreeNodeButton.Skin("grid");
        S.Vector2 low = view.ToTree(S.Vector2.ZERO), high = view.ToTree(V(new Vector2(area.width, area.height)));
        for (double x = Math.Floor(low.x / step) * step; x <= high.x; x += step)
        {
            float sx = (float)view.ToScreen(new S.Vector2(x, 0)).x;
            pen.Line(new Vector2(sx, 0f), new Vector2(sx, area.height), c, 1f);
        }
        for (double y = Math.Floor(low.y / step) * step; y <= high.y; y += step)
        {
            float sy = (float)view.ToScreen(new S.Vector2(0, y)).y;
            pen.Line(new Vector2(0f, sy), new Vector2(area.width, sy), c, 1f);
        }
    }

    // A dish rim round each ring, halfway across the gap outside its band.
    void DrawRims(UiPen pen)
    {
        Vector2 origin = U(view.ToScreen(S.Vector2.ZERO));
        Color rim = TreeNodeButton.Skin("rim");
        float rimWidth = Mathf.Max(LINK_MIN_WIDTH, (float)S.Num.F(skin["rim_width"]) * (float)view.zoom);
        for (int r = 0; r < layout.radii.Count; r++)
        {
            float reach = (float)(layout.RimRadius(r) * view.zoom);
            Vector2 from = origin + new Vector2(reach, 0f);
            for (int k = 1; k <= RIM_STEPS; k++)
            {
                float a = Mathf.PI * 2f * k / RIM_STEPS;
                Vector2 to = origin + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * reach;
                pen.Line(from, to, rim, rimWidth);
                from = to;
            }
        }
    }

    // The cursor in the area, px from its top left.
    Vector2 Local(PointerEventData e)
    {
        RectTransformUtility.ScreenPointToLocalPointInRectangle(rectTransform, e.position, e.enterEventCamera, out Vector2 p);
        Rect r = rectTransform.rect;
        return new Vector2(p.x - r.xMin, r.yMax - p.y);
    }

    // The wheel zooms toward the cursor; over a node too (the event climbs to the plate).
    public void OnScroll(PointerEventData e)
    {
        if (!live || e.scrollDelta.y == 0f) return;
        double wheel = S.Num.F(cfg["wheel_step"]);
        view.ZoomAt(V(Local(e)), e.scrollDelta.y > 0f ? wheel : 1.0 / wheel);
        Place();
    }

    public void OnDrag(PointerEventData e)
    {
        if (!live || e.button != PointerEventData.InputButton.Left) return;
        float scale = canvas != null && canvas.scaleFactor > 0f ? canvas.scaleFactor : 1f;
        // Screen y runs up, the tree's down.
        view.PanBy(new S.Vector2(e.delta.x / scale, -e.delta.y / scale));
        Place();
    }

    static bool Key(KeyCode a, KeyCode b)
    {
        return Input.GetKey(a) || Input.GetKey(b);
    }

    // Keys, the right stick and the triggers, each frame the tree is on screen.
    void Update()
    {
        if (next != null)
        {
            Action run = next;
            next = null;
            run();
        }
        if (!live || view == null || UiFocus.Paused || Inputs.Capturing) return;
        Vector2 move = new Vector2(
            (Key(KeyCode.D, KeyCode.RightArrow) ? 1f : 0f) - (Key(KeyCode.A, KeyCode.LeftArrow) ? 1f : 0f),
            (Key(KeyCode.S, KeyCode.DownArrow) ? 1f : 0f) - (Key(KeyCode.W, KeyCode.UpArrow) ? 1f : 0f));
        float dead = (float)S.Num.F(cfg["deadzone"]);
        float squeeze = 0f;
        XInput.Pad pad = XInput.Read();
        if (pad.connected)
        {
            // The stick's y is up; the tree's is down.
            if (pad.right.magnitude > dead) move += new Vector2(pad.right.x, -pad.right.y);
            squeeze = pad.rightTrigger - pad.leftTrigger;
        }
        if (move == Vector2.zero && Mathf.Abs(squeeze) <= dead) return;
        float delta = Time.unscaledDeltaTime;
        if (move != Vector2.zero)
        {
            // The view moves the way the stick points: the tree slides the other way.
            Vector2 by = -Vector2.ClampMagnitude(move, 1f) * (float)S.Num.F(cfg["pan_per_second"]) * delta;
            view.PanBy(V(by));
        }
        if (Mathf.Abs(squeeze) > dead)
            view.ZoomAt(V(Size * 0.5f), Math.Pow(S.Num.F(cfg["zoom_per_second"]), squeeze * delta));
        Place();
    }
}
