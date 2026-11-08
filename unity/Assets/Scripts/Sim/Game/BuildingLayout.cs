// Generated from sim/building_layout.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class BuildingLayout : RefCounted
    {
        public static implicit operator BuildingLayout(Variant v) => (BuildingLayout)v.Obj;

        // One building's fine layout, shared by the sim's destruction grid (BuildingCells) and the
        // view's voxels (BuildingVoxels), so the two can never drift apart: `cells` maps each cell
        // (RES cells per sim unit, local to the footprint) to its key, in the order the parts are laid.
        // Facades have depth: windows sit one cell back in their reveals behind proud sills and
        // lintels; piers, spandrels, mullions and transoms frame them. Four archetypes: office (ribbon
        // windows over spandrel bands, AC plant), brick (punched windows, balconies, a solar water
        // heater or a wooden water tower: RoofTank), glass (flush curtain wall on a structural frame,
        // mast with beacon), stone (pilasters, cornices and string courses, stepped roof). Ground floors
        // are shopfronts under a sign band and an awning; some shops hang a vertical neon sign off a
        // street face. Hollow shell plus a slab per floor.
        // Keys are materials (data/materials.json) except the lit windows the view asks for: with
        // lit_chance 0 (the sim) no "lit" or "shop_lit" key is laid. Layout rolls hash the cell with the
        // building's position: no RNG stream, no clock. The bay patterns are drawn for an 8-cell bay.
        public const long OFFICE = 0;
        public const long BRICK = 1;
        public const long GLASS = 2;
        public const long STONE = 3;
        public const long NEON_COUNT = 4;
        public const double SIGN_CHANCE = 0.3;
        // Sides, as the outward step in cells: -x, +x, -z, +z.
        public static readonly GArray<Vector2i> SIDES = new GArray<Vector2i> { new Vector2i(-1, 0), new Vector2i(1, 0), new Vector2i(0, -1), new Vector2i(0, 1) };
        // Cell -> key, in the order laid (a cell laid twice keeps its first place and the last key).
        public GDict cells = new GDict();
        public RampageSim.Building b;
        public long res;
        public long _w;
        public long _d;
        public long _h;
        public GDict _party = new GDict();
        public double _litChance;
        // party: side (SIDES) -> floors of that side a touching neighbour covers (no sign hangs off
        // that side). lit_chance: the share of windows the view lights (0 in the sim).

        public BuildingLayout(RampageSim.Building pBuilding, long pRes, GDict party, double litChance)
        {
            _InitFields();
            b = pBuilding;
            res = pRes;
            _party = party;
            _litChance = litChance;
            _w = b.w * res;
            _d = b.d * res;
            _h = b.height * res;
            foreach (Vector2i side in SIDES)
            {
                _Face(side);
            }
            _Frame();
            _Slabs();
            _Roof();
            _Sign();
        }
        public BuildingLayout(RampageSim.Building pBuilding, long pRes, GDict party) : this(pBuilding, pRes, party, 0.0) { }
        public BuildingLayout(RampageSim.Building pBuilding, long pRes) : this(pBuilding, pRes, new GDict(), 0.0) { }

        public long Archetype()
        {
            return b.style % 4;
        }

        public void _Put(Vector3i cell, string key)
        {
            cells[cell] = key;
        }

        public void _Box(Vector3i a, Vector3i c, string key)
        {
            foreach (long x in Gd.Range(Gd.Mini(a.x, c.x), Gd.Maxi(a.x, c.x) + 1))
            {
                foreach (long y in Gd.Range(Gd.Mini(a.y, c.y), Gd.Maxi(a.y, c.y) + 1))
                {
                    foreach (long z in Gd.Range(Gd.Mini(a.z, c.z), Gd.Maxi(a.z, c.z) + 1))
                    {
                        cells[new Vector3i(x, y, z)] = key;
                    }
                }
            }
        }
        // Whether v lies in lo..hi, both ends included.

        public static bool _In(long v, long lo, long hi)
        {
            return v >= lo && v <= hi;
        }

        public long _Roll(Vector3i cell, long mod)
        {
            return RollFor(b, cell, mod);
        }
        // The roll for building `of` at `cell`: a hash of the cell and the building's position.

        public static long RollFor(RampageSim.Building of, Vector3i cell, long mod)
        {
            return Gd.Absi(Gd.Hash(new Vector4i(cell.x, cell.y, cell.z, Gd.Roundi(of.x * 13.0 + of.z)))) % mod;
        }
        // The cell `layer` cells in from the face (0 = the wall plane, -1 proud, 1 recessed) at
        // position p along the face and height y.

        public Vector3i _At(Vector2i side, long p, long y, long layer)
        {
            if (side.x < 0)
            {
                return new Vector3i(layer, y, p);
            }
            if (side.x > 0)
            {
                return new Vector3i(_w - 1 - layer, y, p);
            }
            if (side.y < 0)
            {
                return new Vector3i(p, y, layer);
            }
            return new Vector3i(p, y, _d - 1 - layer);
        }
        // One face: the wall plane, recessed glass, and what stands proud of it.

        public void _Face(Vector2i side)
        {
            long length = (side.x != 0 ? _d : _w);
            foreach (long y in Gd.Range(_h))
            {
                foreach (long p in Gd.Range(length))
                {
                    // corner piers are shared by two faces
                    if ((p == 0 || p == length - 1))
                    {
                        _Put(_At(side, p, y, 0), "pillar");
                        continue;
                    }
                    var spec = (y < res ? _Ground(y, p) : _Upper(y, p));
                    if (spec[0] == "recess")
                    {
                        _Put(_At(side, p, y, 1), _LitOr(spec[1], side, p, y));
                    }
                    else
                    {
                        _Put(_At(side, p, y, 0), spec[0]);
                    }
                    if (spec[2] != "")
                    {
                        _Put(_At(side, p, y, -1), spec[2]);
                    }
                    if (spec[3] != "")
                    {
                        _Put(_At(side, p, y, -2), spec[3]);
                    }
                }
            }
        }
        // A window lights as a whole: one roll per window (its bay and floor).

        public string _LitOr(string key, Vector2i side, long p, long y)
        {
            if (_litChance <= 0.0)
            {
                return key;
            }
            var window = new Vector3i(Gd.Floori(Gd.Float(p) / res), Gd.Floori(Gd.Float(y) / res), side.x * 3 + side.y);
            if (_Roll(window, 1000) < _litChance * 1000.0)
            {
                return (key == "shop" ? "shop_lit" : "lit");
            }
            return key;
        }
        // Ground floor, as [plane, recessed key, proud, further proud]: shop windows between piers,
        // a sign band, an awning reaching out over the pavement.

        public GArray<string> _Ground(long y, long p)
        {
            if (y == res - 1)
            {
                return new GArray<string> { "trim", "", "awning", "awning" };
            }
            if (y == res - 2)
            {
                return new GArray<string> { "band", "", "band", "" };
            }
            if ((p % res == 0 || y == 0))
            {
                // a pier, or the stall riser under the glass
                return new GArray<string> { "pillar", "", "", "" };
            }
            return new GArray<string> { "recess", "shop", "", "" };
        }
        // Upper floors by archetype, as [plane, recessed key, proud, further proud].
        // r: row within the floor (0 = the slab line), q: column within the bay.

        public GArray<string> _Upper(long y, long p)
        {
            long r = y % res;
            long q = p % res;
            var topRow = y >= _h - 2;
            var matched1 = Archetype();
            if (matched1 == OFFICE)
            {
                return _Office(r, q, topRow);
            }
            else if (matched1 == BRICK)
            {
                return _Brick(r, q, Gd.Floori(Gd.Float(y) / res));
            }
            else if (matched1 == GLASS)
            {
                if ((q == 0 || r == 0))
                {
                    return new GArray<string> { "mullion", "", "", "" };
                }
                if (r == 4)
                {
                    // transom
                    return new GArray<string> { "frame", "", "", "" };
                }
                return new GArray<string> { (_LitPanel(p, y) ? "lit" : "glass"), "", "", "" };
            }
            return _Stone(r, q, (topRow || (r == 0 && Gd.Floori(Gd.Float(y) / res) % 5 == 0)), topRow);
        }
        // Ribbon windows over spandrels, slim mullions, a transom.

        public GArray<string> _Office(long r, long q, bool topRow)
        {
            if (r <= 1)
            {
                return new GArray<string> { (r == 1 ? "spandrel" : "trim"), "", "", "" };
            }
            if (topRow)
            {
                return new GArray<string> { "trim", "", "trim", "" };
            }
            if (q == 0)
            {
                return new GArray<string> { "pillar", "", "", "" };
            }
            if (r == 7)
            {
                return new GArray<string> { "frame", "", "", "" };
            }
            return new GArray<string> { "recess", ((q == 4 || r == 5) ? "mullion" : "window"), "", "" };
        }
        // Punched windows with sills and lintels; a balcony with a railing every other floor.

        public GArray<string> _Brick(long r, long q, long floorN)
        {
            var balcony = floorN % 2 == 0 && _In(q, 1, 6);
            var punched = _In(q, 2, 5);
            if (punched && _In(r, 2, 6))
            {
                return new GArray<string> { "recess", (r == 4 ? "mullion" : "window"), "", "" };
            }
            if (r == 7 && punched)
            {
                // lintel
                return new GArray<string> { "frame", "", "frame", "" };
            }
            if (r == 1 && _In(q, 1, 6))
            {
                return new GArray<string> { "wall", "", (balcony ? "rail" : "sill"), (balcony ? "rail" : "") };
            }
            if (r == 0 && balcony)
            {
                return new GArray<string> { "wall", "", "slab", "slab" };
            }
            return new GArray<string> { "wall", "", "", "" };
        }
        // Pilasters, deep windows with sills and keystones, string courses and a cornice.

        public GArray<string> _Stone(long r, long q, bool course, bool topRow)
        {
            if (course)
            {
                return new GArray<string> { "trim", "", "trim", (topRow ? "trim" : "") };
            }
            if (q == 0)
            {
                return new GArray<string> { "pillar", "", "pillar", "" };
            }
            if (_In(q, 2, 5) && _In(r, 2, 6))
            {
                return new GArray<string> { "recess", "window", "", "" };
            }
            if (r == 1 && _In(q, 2, 5))
            {
                return new GArray<string> { "wall", "", "sill", "" };
            }
            if (r == 7 && _In(q, 3, 4))
            {
                // keystone
                return new GArray<string> { "trim", "", "trim", "" };
            }
            return new GArray<string> { "wall", "", "", "" };
        }
        // Curtain walls light per panel (two bays wide, half a floor tall).

        public bool _LitPanel(long p, long y)
        {
            if (_litChance <= 0.0)
            {
                return false;
            }
            var panel = new Vector3i(Gd.Floori(Gd.Float(p) / (res * 2)), Gd.Floori(Gd.Float(y) / (res / 2.0)), 77);
            return _Roll(panel, 1000) < _litChance * 1000.0;
        }
        // A glass building's structural frame (GlassFrame).

        public void _Frame()
        {
            if (Archetype() != GLASS)
            {
                return;
            }
            GDict frame = GlassFrame.Cells(_w, _d, _h, res);
            foreach (Vector3i cell in frame)
            {
                _Put(cell, Gd.Str(frame[cell]));
            }
        }
        // A slab per floor inside the shell, and the roof deck.

        public void _Slabs()
        {
            foreach (long floorY in Gd.Range(0, _h, res))
            {
                foreach (long x in Gd.Range(1, _w - 1))
                {
                    foreach (long z in Gd.Range(1, _d - 1))
                    {
                        if (!(cells.Has(new Vector3i(x, floorY, z))))
                        {
                            _Put(new Vector3i(x, floorY, z), "slab");
                        }
                    }
                }
            }
            foreach (long x in Gd.Range(1, _w - 1))
            {
                foreach (long z in Gd.Range(1, _d - 1))
                {
                    _Put(new Vector3i(x, _h - 1, z), "roof");
                }
            }
        }

        public void _Roof()
        {
            long top = _h;
            _Parapet(top);
            _StairHut(top);
            var matched2 = Archetype();
            if (matched2 == OFFICE)
            {
                _AcUnits(top);
            }
            else if (matched2 == BRICK)
            {
                new RoofTank(cells, _w, _d).Lay(b, top);
            }
            else if (matched2 == GLASS)
            {
                _Mast(top);
            }
            else
            {
                _SteppedRoof(top);
            }
            _Vents(top);
        }
        // The parapet round the roof's edge, two cells high.

        public void _Parapet(long top)
        {
            foreach (long x in Gd.Range(_w))
            {
                foreach (long z in Gd.Range(_d))
                {
                    if ((x == 0 || z == 0 || x == _w - 1 || z == _d - 1))
                    {
                        _Box(new Vector3i(x, top, z), new Vector3i(x, top + 1, z), "trim");
                    }
                }
            }
        }
        // A stone building's stepped roof: three tiers, each four cells in from the last.

        public void _SteppedRoof(long top)
        {
            foreach (long step in Gd.Range(3))
            {
                foreach (long x in Gd.Range(2 + step * 4, _w - 2 - step * 4))
                {
                    foreach (long z in Gd.Range(2 + step * 4, _d - 2 - step * 4))
                    {
                        _Box(new Vector3i(x, top + step * 2, z), new Vector3i(x, top + step * 2 + 1, z), "trim");
                    }
                }
            }
        }
        // Vent stacks, one to three by depth.

        public void _Vents(long top)
        {
            foreach (long v in Gd.Range(Gd.Clampi(b.d, 1, 3)))
            {
                var at = new Vector3i(2 + _Roll(new Vector3i(v, 5, 1), Gd.Maxi(1, _w - 4)), top, 2 + _Roll(new Vector3i(v, 5, 2), Gd.Maxi(1, _d - 4)));
                _Box(at, at + new Vector3i(0, 3, 0), "vent");
            }
        }
        // Air-conditioning units with fan grilles, ducts between them.

        public void _AcUnits(long top)
        {
            foreach (long i in Gd.Range(Gd.Clampi(b.w, 1, 4)))
            {
                var at = new Vector3i(4 + _Roll(new Vector3i(i, 1, 0), Gd.Maxi(1, _w - 12)), top, 4 + _Roll(new Vector3i(i, 2, 0), Gd.Maxi(1, _d - 12)));
                _Box(at, at + new Vector3i(4, 3, 3), "gear");
                _Box(at + new Vector3i(1, 4, 1), at + new Vector3i(3, 4, 2), "vent");
                _Box(at + new Vector3i(5, 1, 1), at + new Vector3i(8, 1, 1), "pipe");
            }
        }
        // A mast with a red beacon on the tall towers.

        public void _Mast(long top)
        {
            if (b.tier < 2)
            {
                return;
            }
            var mast = new Vector3i((_w >> (int)(1)), top, (_d >> (int)(1)));
            long mastH = 16 + b.tier * 8;
            _Box(mast, mast + new Vector3i(0, mastH, 0), "gear");
            _Box(mast + new Vector3i(-2, 0, -2), mast + new Vector3i(2, 4, 2), "gear");
            foreach (long ring in Gd.Range(8, mastH, 8))
            {
                _Box(mast + new Vector3i(-1, ring, -1), mast + new Vector3i(1, ring, 1), "pipe");
            }
            _Put(mast + new Vector3i(0, mastH + 1, 0), "beacon");
        }
        // The stair and lift housing at a corner of the roof, with a door.

        public void _StairHut(long top)
        {
            if ((_w < 20 || _d < 20))
            {
                return;
            }
            var at = new Vector3i(3, top, 3);
            _Box(at, at + new Vector3i(7, 6, 6), "wall");
            _Box(at + new Vector3i(2, 0, 7), at + new Vector3i(4, 4, 7), "frame");
        }
        // A vertical neon sign hung off a street face near a corner: a dark frame round glowing
        // bands, three cells wide, two deep, from above the awning up to five floors.

        public void _Sign()
        {
            if ((b.height < 3 || Archetype() == GLASS || _Roll(new Vector3i(7, 7, 7), 1000) >= SIGN_CHANCE * 1000))
            {
                return;
            }
            var open = _OpenSides();
            if (open.IsEmpty())
            {
                return;
            }
            var side = open[_Roll(new Vector3i(3, 1, 4), open.Size())];
            long colour = _Roll(new Vector3i(5, 9, 2), NEON_COUNT);
            long length = (side.x != 0 ? _d : _w);
            long along = (_Roll(new Vector3i(1, 2, 3), 2) == 0 ? 4 : length - 8);
            foreach (long y in Gd.Range(res + 2, _SignTop()))
            {
                _SignRow(side, along, y, colour);
            }
        }
        // The sides that have no neighbour at all: signs hang only off those.

        public GArray<Vector2i> _OpenSides()
        {
            GArray<Vector2i> open = new GArray<Vector2i>();
            foreach (Vector2i side in SIDES)
            {
                if (!_party.Has(side))
                {
                    open.Append(side);
                }
            }
            return open;
        }
        // The floor above the sign's last row: up to five floors from the ground.

        public long _SignTop()
        {
            return Gd.Mini(_h - 6, res * 5);
        }
        // One floor of the sign (`along` the face, in neon `colour`).

        public void _SignRow(Vector2i side, long along, long y, long colour)
        {
            foreach (long a in Gd.Range(4))
            {
                foreach (long @out in Gd.Range(-3, -1))
                {
                    var edge = (a == 0 || a == 3 || y == res + 2 || y == _SignTop() - 1);
                    long band = Gd.Floori((y - res) / 3.0) % 4;
                    var key = (((edge || band == 3) ? "sign_frame" : Gd.Format("neon%d", ((colour + band) % NEON_COUNT))));
                    _Put(_At(side, along + a, y, @out), key);
                }
            }
            // An office face has nothing proud for the sign to touch: a bracket at each frame
            // edge, on every spandrel row, holds it to the wall.
            if (Archetype() == OFFICE && y % res == 1)
            {
                foreach (long a in Gd.Arr(0, 3))
                {
                    _Put(_At(side, along + a, y, -1), "sign_frame");
                }
            }
        }

        void _InitFields()
        {
        }
    }
}
