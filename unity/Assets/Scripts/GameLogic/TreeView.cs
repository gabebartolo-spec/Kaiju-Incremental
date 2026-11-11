// The evolution tree's camera (scenes/tree_view.gd, D-275): which point of the tree is at the middle of the view
// and how far it is zoomed. Zoom 1 is the default; the furthest zoom out fits the whole tree; panning is clamped
// so the tree never leaves the view. Pure maths on the sim's float32 vectors, as Godot's.
using Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class TreeView
    {
        public const double DEFAULT_ZOOM = 1.0;

        public double zoom = DEFAULT_ZOOM;
        // The tree point (canvas units) at the middle of the view.
        public Vector2 centre = Vector2.ZERO;
        // The view's size on screen.
        public Vector2 viewSize = new Vector2(1920, 1080);
        // The box round every node (TreeLayout.bounds).
        public Rect2 bounds;
        // A share of the view the whole tree fills at the furthest zoom out (tuning "tree" "view").
        public double fitMargin = 0.95;

        public TreeView(Rect2 bounds, Vector2 view, double fitMargin)
        {
            this.bounds = bounds;
            this.fitMargin = fitMargin;
            Resize(view);
        }

        // The zoom at which the whole tree fits the view (never above the default).
        public double FitZoom()
        {
            if (bounds.size.x <= 0.0 || bounds.size.y <= 0.0) return DEFAULT_ZOOM;
            double fit = Gd.Minf(viewSize.x / bounds.size.x, viewSize.y / bounds.size.y) * fitMargin;
            return Gd.Minf(fit, DEFAULT_ZOOM);
        }

        // The view changed size: keep the zoom and centre inside their limits.
        public void Resize(Vector2 view)
        {
            viewSize = new Vector2(Gd.Maxf(1.0, view.x), Gd.Maxf(1.0, view.y));
            SetZoom(zoom);
        }

        public void SetZoom(double z)
        {
            zoom = Gd.Clampf(z, FitZoom(), DEFAULT_ZOOM);
            ClampCentre();
        }

        // Zooms by `factor` keeping the tree point under `screenAt` (view coordinates) where it is, as far as
        // the clamps allow (the mouse wheel zooms toward the cursor).
        public void ZoomAt(Vector2 screenAt, double factor)
        {
            Vector2 held = ToTree(screenAt);
            zoom = Gd.Clampf(zoom * factor, FitZoom(), DEFAULT_ZOOM);
            centre = held - (screenAt - viewSize * 0.5) / zoom;
            ClampCentre();
        }

        // Moves the view by `screenDelta` (view pixels): dragging the tree right shows what is left.
        public void PanBy(Vector2 screenDelta)
        {
            centre -= screenDelta / zoom;
            ClampCentre();
        }

        // Puts `treePoint` at the middle of the view, as near as the clamps allow.
        public void LookAt(Vector2 treePoint)
        {
            centre = treePoint;
            ClampCentre();
        }

        public void ClampCentre()
        {
            Vector2 half = viewSize * 0.5 / zoom;
            centre.x = ClampAxis(centre.x, bounds.position.x, bounds.end.x, half.x);
            centre.y = ClampAxis(centre.y, bounds.position.y, bounds.end.y, half.y);
        }

        static double ClampAxis(double at, double low, double high, double half)
        {
            if (high - low <= half * 2.0) return (low + high) * 0.5;
            return Gd.Clampf(at, low + half, high - half);
        }

        // A tree point's place in the view (view pixels).
        public Vector2 ToScreen(Vector2 treePoint)
        {
            return (treePoint - centre) * zoom + viewSize * 0.5;
        }

        // The tree point under a place in the view.
        public Vector2 ToTree(Vector2 screenAt)
        {
            return (screenAt - viewSize * 0.5) / zoom + centre;
        }
    }
}
