// Where each node of the evolution tree sits (scenes/tree_layout.gd, D-275): polar rings, the young croc's ring
// round the centre and each growth stage's ring further out. Pure maths over the tree's data, in canvas units at
// the default zoom, on the sim's float32 vectors so the numbers match Godot's. Sizes and spacing: tuning "tree"
// "layout".
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class TreeLayout
    {
        // One tube of the tree: `to` needs `from`.
        public struct Link
        {
            public string from, to;
        }

        // id -> the node's centre (canvas units, the tree's centre at 0, 0), in the order they were placed.
        public readonly Dictionary<string, Vector2> centres = new Dictionary<string, Vector2>();
        public readonly List<string> placed = new List<string>();
        // id -> the node's box size.
        public readonly Dictionary<string, Vector2> sizes = new Dictionary<string, Vector2>();
        // id -> the node's angle round the centre (radians).
        public readonly Dictionary<string, double> angles = new Dictionary<string, double>();
        // Ring radius by ring (index 0 = ring 1).
        public readonly List<double> radii = new List<double>();
        // Half the radial depth each ring's band takes: a node's box stays inside radius +/- this.
        public readonly List<double> halfDepth = new List<double>();
        // Every requires link, in data order (the node, then each node it needs).
        public readonly List<Link> links = new List<Link>();
        // The box round every node.
        public Rect2 bounds;
        double ringGap;

        // Lays out `tree` (every node, shown or not, so a node never moves as rings open).
        // ultimateIds: nodes drawn as their branch's capstone (a taller box).
        public static TreeLayout Build(UpgradeTree tree, ICollection<string> ultimateIds)
        {
            var o = new TreeLayout();
            GDict layout = Content.Section("tree")["layout"];
            List<List<string>> byRing = ByRing(tree);
            foreach (string id in tree.order) o.sizes[id] = SizeOf(layout, tree.Kind(id), ultimateIds.Contains(id));
            double gap = Num.F(layout["node_gap"]);
            double inner = Num.F(layout["centre_radius"]);
            o.ringGap = Num.F(layout["ring_gap"]);
            double lastHalf = 0.0;
            for (int r = 1; r <= byRing.Count; r++)
            {
                List<string> ids = byRing[r - 1];
                double widest = 0.0;
                foreach (string id in ids) widest = Gd.Maxf(widest, o.sizes[id].Length());
                double around = ids.Count * (widest + gap) / Gd.TAU;
                double outward = inner + lastHalf + widest * 0.5 + o.ringGap;
                if (r == 1) outward = inner;
                double radius = Gd.Maxf(around, outward);
                o.radii.Add(radius);
                o.halfDepth.Add(widest * 0.5);
                o.PlaceRing(tree, ids, radius, r == 1);
                inner = radius;
                lastHalf = widest * 0.5;
            }
            o.Measure();
            foreach (string id in tree.order)
                foreach (string req in Requires(tree, id))
                    o.links.Add(new Link { from = req, to = id });
            return o;
        }

        // The box of node `id` (canvas units, centred on its centre).
        public Rect2 Rect(string id)
        {
            Vector2 size = sizes[id];
            return new Rect2(centres[id] - size * 0.5, size);
        }

        // The dish rim round ring `r` (0-based): halfway across the gap outside its band (tree_area.gd rim_radius).
        public double RimRadius(int r)
        {
            return radii[r] + halfDepth[r] + ringGap * 0.5;
        }

        // The ids a node needs, in data order.
        public static List<string> Requires(UpgradeTree tree, string id)
        {
            var o = new List<string>();
            GDict def = tree.defs[id];
            GArray<Variant> requires = def.Get("requires", new GArray<Variant>());
            foreach (Variant req in requires) o.Add(Gd.Str(req));
            return o;
        }

        // The nodes of each ring, ring 1 first (a ring with no nodes is an empty list).
        static List<List<string>> ByRing(UpgradeTree tree)
        {
            long top = 1;
            foreach (string id in tree.order) top = System.Math.Max(top, tree.Ring(id));
            var o = new List<List<string>>();
            for (long r = 0; r < top; r++) o.Add(new List<string>());
            foreach (string id in tree.order) o[(int)tree.Ring(id) - 1].Add(id);
            return o;
        }

        static Vector2 SizeOf(GDict layout, string kind, bool ultimate)
        {
            GDict nodes = layout["node"];
            GArray<Variant> box = nodes.Get(kind, nodes["stat"]);
            var size = new Vector2(Num.F(box[0]), Num.F(box[1]));
            if (ultimate) size.y += Num.F(layout["ultimate_extra"]);
            return size;
        }

        void PlaceRing(UpgradeTree tree, List<string> ids, double radius, bool centre)
        {
            if (ids.Count == 0) return;
            List<string> ordered = centre ? LinkOrder(tree, ids) : ByParents(tree, ids);
            double step = Gd.TAU / ordered.Count;
            double start = centre ? -Gd.PI / 2.0 : BestTurn(tree, ordered, step);
            for (int k = 0; k < ordered.Count; k++)
            {
                string id = ordered[k];
                double a = start + step * k;
                angles[id] = a;
                if (!centres.ContainsKey(id)) placed.Add(id);
                centres[id] = new Vector2(Gd.Cos(a), Gd.Sin(a)) * radius;
            }
        }

        // Ring 1: each root, then what it opens, depth first, so linked nodes sit side by side.
        static List<string> LinkOrder(UpgradeTree tree, List<string> ids)
        {
            var o = new List<string>();
            foreach (string id in ids)
                if (InnerParents(tree, id, ids).Count == 0) Visit(tree, id, ids, o);
            foreach (string id in ids)
                if (!o.Contains(id)) o.Add(id);
            return o;
        }

        static void Visit(UpgradeTree tree, string id, List<string> ids, List<string> o)
        {
            if (o.Contains(id)) return;
            o.Add(id);
            foreach (string child in ids)
            {
                List<string> parents = InnerParents(tree, child, ids);
                if (parents.Contains(id) && parents.TrueForAll(p => o.Contains(p))) Visit(tree, child, ids, o);
            }
        }

        static List<string> InnerParents(UpgradeTree tree, string id, List<string> ids)
        {
            var o = new List<string>();
            foreach (string req in Requires(tree, id))
                if (ids.Contains(req)) o.Add(req);
            return o;
        }

        // The mean angle of the placed nodes `id` needs (NaN when none is placed yet).
        double ParentAngle(UpgradeTree tree, string id)
        {
            Vector2 sum = Vector2.ZERO;
            foreach (string req in Requires(tree, id))
            {
                if (!angles.TryGetValue(req, out double a)) continue;
                sum += new Vector2(Gd.Cos(a), Gd.Sin(a));
            }
            return sum.Length() < 0.0001 ? Gd.NAN : sum.Angle();
        }

        // Outer rings: by the mean angle of their parents (no placed parent: data order, last). Sorted with the
        // sim's copy of Godot's sort, so nodes that tie land in the order Godot leaves them.
        List<string> ByParents(UpgradeTree tree, List<string> ids)
        {
            var keyed = new GArray<GDict>();
            for (int k = 0; k < ids.Count; k++)
            {
                double a = ParentAngle(tree, ids[k]);
                keyed.Append(new GDict { { "k", double.IsNaN(a) ? Gd.TAU * 2.0 + k : Gd.Fposmod(a, Gd.TAU) }, { "id", ids[k] } });
            }
            keyed.SortCustom(new Callable(a_ =>
            {
                GDict x = a_[0];
                GDict y = a_[1];
                return Num.F(x["k"]) < Num.F(y["k"]);
            }));
            var o = new List<string>();
            foreach (GDict pair in keyed) o.Add(Gd.Str(pair["id"]));
            return o;
        }

        // The turn of the ring that puts its nodes nearest their parents on average.
        double BestTurn(UpgradeTree tree, List<string> ordered, double step)
        {
            Vector2 sum = Vector2.ZERO;
            for (int k = 0; k < ordered.Count; k++)
            {
                double a = ParentAngle(tree, ordered[k]);
                if (double.IsNaN(a)) continue;
                double off = a - step * k;
                sum += new Vector2(Gd.Cos(off), Gd.Sin(off));
            }
            return sum.Length() < 0.0001 ? -Gd.PI / 2.0 : sum.Angle();
        }

        void Measure()
        {
            bool first = true;
            foreach (string id in placed)
            {
                bounds = first ? Rect(id) : bounds.Merge(Rect(id));
                first = false;
            }
        }
    }
}
