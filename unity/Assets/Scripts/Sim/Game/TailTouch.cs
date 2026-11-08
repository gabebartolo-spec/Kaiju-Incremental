// Generated from sim/tail_touch.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TailTouch : RefCounted
    {
        public static implicit operator TailTouch(Variant v) => (TailTouch)v.Obj;

        // The tail carves every building it touches in ordinary play, not only on the lash (director
        // 2026-10-30: "the tail should carve whatever building it touches in general play too ... it
        // doesnt work most the time and the tail just clips through"). BodyContact lays the tail rigidly
        // along the heading on discs thinner than the drawn tail (its tip discs vanish under the skin) and
        // only chews a building that dwarfs him, while the drawn tail is a spring chain that swings wide
        // on a turn. Here the tail discs (offset at or behind tail_from) are laid along a heading that
        // lags the body's at `follow` /s, widened by `pad`, swept between steps, and break every standing
        // chunk they touch outright, whatever its size. Part of RampageSim, stepped after BodyContact
        // (whose discs and pose it reads); pure, no randomness.
        // Chunks the tail has broken this rampage.
        public long broken = 0;
        // Off: the tail breaks nothing (the on-vs-off fixtures).
        public bool on = true;
        public RampageSim _sim;
        public GDict _cfg = new GDict();
        public BodyVolume _volume;
        // the heading the tail lies along (lags the body's)
        public Vector2 _lay = Vector2.ZERO;
        public Vector2 _lastPos = new Vector2(Gd.INF, Gd.INF);
        public Vector2 _lastLay = Vector2.ZERO;
        // the body discs the tail's were taken from
        public GArray<Variant> _fromDiscs = Gd.Arr();

        public TailTouch(RampageSim sim, GDict contactCfg)
        {
            _InitFields();
            _sim = sim;
            _cfg = contactCfg["tail"];
            _volume = new BodyVolume(sim, contactCfg);
        }
        // Takes the tail discs out of a stage's body discs ([offset, radius, bottom, top], scale 1).

        public void UseDiscs(GArray<Variant> discs)
        {
            double from = Num.F(_cfg["from"]);
            double pad = Num.F(_cfg["pad"]);
            GArray<Variant> tail = Gd.Arr();
            foreach (GArray<Variant> d in discs)
            {
                if (Num.F(d[0]) <= from)
                {
                    tail.Append(Gd.Arr(Num.F(d[0]), Num.F(d[1]) + pad, Num.F(d[2]), Num.F(d[3])));
                }
            }
            _volume.discs = tail;
            _lastPos = new Vector2(Gd.INF, Gd.INF);
        }

        public void Step(double dt)
        {
            var body = _sim.body;
            if ((!body.Active() || (_sim.airborne && !body.dash.On()) || !on))
            {
                // off the ground with the body: it starts afresh after
                _lastPos = new Vector2(Gd.INF, Gd.INF);
                return;
            }
            // a new species or stage
            if (!Gd.IsSame(body._discs, _fromDiscs))
            {
                _fromDiscs = body._discs;
                UseDiscs(_fromDiscs);
            }
            if (_volume.discs.IsEmpty())
            {
                return;
            }
            var heading = body.heading;
            double lift = body.dash.Height();
            if ((_lay == Vector2.ZERO || _lastPos.x == Gd.INF))
            {
                _lay = heading;
            }
            _lay = _lay.Slerp(heading, 1.0 - Gd.Exp(-Num.F(_cfg["follow"]) * dt)).Normalized();
            var from = (_lastPos.x == Gd.INF ? _sim.kaijuPos : _lastPos);
            var fromLay = (_lastPos.x == Gd.INF ? _lay : _lastLay);
            _volume.lift = lift;
            _Break(_volume.Touched(from, fromLay, _sim.kaijuPos, _lay));
            _lastPos = _sim.kaijuPos;
            _lastLay = _lay;
        }
        // Breaks every chunk the sweep touched, outright.

        public void _Break(GDict hits)
        {
            foreach (long index in hits)
            {
                GArray<Vector3i> cells = new GArray<Vector3i>();
                foreach (Vector3i c in Gd.Iter(hits[index]))
                {
                    cells.Append(c);
                }
                broken += _sim.DamageChunks(index, cells, Gd.INF);
            }
        }

        void _InitFields()
        {
        }
    }
}
