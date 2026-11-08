// Generated from sim/content.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Content : RefCounted
    {
        public static implicit operator Content(Variant v) => (Content)v.Obj;

        // Content and balance from data/*.json, loaded once and cached. Static so test runners and
        // sim code can read it without the GameData autoload; GameData only forwards here.
        public static GDict _tuning = new GDict();
        public static GArray<GDict> _upgrades = new GArray<GDict>();
        // every entry, the far beast's look too
        public static GArray<GDict> _species = new GArray<GDict>();
        public static GArray<GDict> _looks = new GArray<GDict>();
        public static string _lookId = "";
        public static GDict _times = new GDict();
        public static string _timeId = "";
        public static GDict _weather = new GDict();
        public static string _weatherId = "";
        public static GDict _merged = new GDict();
        public static GDict _landmarks = new GDict();
        public static GDict _pool = new GDict();
        public static GDict _sports = new GDict();
        public static GArray<GDict> _materials = new GArray<GDict>();
        public static GArray<GDict> _continents = new GArray<GDict>();
        public static GArray<Variant> _stageWords = Gd.Arr();
        public static GDict _bonusLines = new GDict();

        public static GDict Tuning()
        {
            _Load();
            return _tuning;
        }

        public static GDict Section(string key)
        {
            _Load();
            GDict @out = _tuning.Get(key, new GDict());
            return @out;
        }

        public static GArray<GDict> Upgrades()
        {
            _Load();
            return _upgrades;
        }
        // The species a player can be: data/species.json minus "playable": false entries (the insectoid
        // only rampages across the bay, D-438).

        public static GArray<GDict> Species()
        {
            _Load();
            GArray<GDict> @out = new GArray<GDict>();
            foreach (GDict def in _species)
            {
                if (def.Get("playable", true) != false)
                {
                    @out.Append(def);
                }
            }
            return @out;
        }
        // Any species entry by id, an unplayable one too (FarBeast reads the insectoid's colors); an
        // unknown id gives the first playable species.

        public static GDict SpeciesDef(string id)
        {
            _Load();
            foreach (GDict def in _species)
            {
                if (def["id"] == id)
                {
                    return def;
                }
            }
            return Species()[0];
        }
        // Each landmark's baked shape (data/landmarks.json, written by tools/landmarks/bake.py): id ->
        // {w, d, h, kvox, chunks (one string per floor, "1" per structural chunk, x fastest)}.

        public static GDict Landmarks()
        {
            _Load();
            return _landmarks;
        }
        // The campaign's continents (data/continents.json, D-418..D-422), in the globe's sequence (D-420):
        // {id (the save's key), name, stage (a tuning growth.stages index), threat (Threat % a conquest
        // adds), bonuses (the three offered: each {id, scale}), capital (Aurelia, last)}.

        public static GArray<GDict> Continents()
        {
            _Load();
            return _continents;
        }
        // One continent by id, or {} when there is none.

        public static GDict Continent(string id)
        {
            foreach (GDict def in Continents())
            {
                if (def["id"] == id)
                {
                    return def;
                }
            }
            return new GDict();
        }
        // A growth stage (a continent's "stage") in game words: "Young croc", "Behemoth", "Colossus".

        public static string StageWord(long stage)
        {
            _Load();
            return (stage >= 0 && stage < _stageWords.Size() ? Gd.Str(_stageWords[stage]) : "");
        }
        // A bonus stat as a phrase with its percent inside ("Moves %d%% faster"), or "" when the stat
        // has none.

        public static string BonusLine(string stat)
        {
            _Load();
            return Gd.Str(_bonusLines.Get(stat, ""));
        }
        // One conquest bonus by id ({id, scale: stat -> fraction added}), or {} when there is none.

        public static GDict Bonus(string id)
        {
            foreach (GDict def in Continents())
            {
                GArray<Variant> offered = def["bonuses"];
                foreach (GDict pick in offered)
                {
                    if (pick["id"] == id)
                    {
                        return pick;
                    }
                }
            }
            return new GDict();
        }
        // The city's building pool (data/city_buildings.json, D-256): the whole book (districts,
        // placement, "pool" rows by id with their baked shapes; CityPool, ModelVariant).

        public static GDict CityBuildings()
        {
            _Load();
            return _pool;
        }
        // The stadium's matches (D-078, data/sports.json): "pitch" (where on the stadium, pace) and
        // "sports" (markings, posts, kits, ball). Presentation only.

        public static GDict Sports()
        {
            _Load();
            return _sports;
        }
        // Building cell materials (data/materials.json, D-094): {id (the byte a fine grid cell
        // holds, 1..255; 0 is empty), name (its BuildingVoxels palette key), strength, debris}.

        public static GArray<GDict> Materials()
        {
            _Load();
            return _materials;
        }

        public static GArray<GDict> Looks()
        {
            _Load();
            return _looks;
        }
        // The art direction in use (data/looks.json); presentation reads its colours and light.
        // Its time of day (director 2026-10-20: "all of them") is merged over it.

        public static GDict Look()
        {
            _Load();
            if (_merged.IsEmpty())
            {
                GDict @base = _looks[0];
                foreach (GDict def in _looks)
                {
                    if (def["id"] == _lookId)
                    {
                        @base = def;
                    }
                }
                _merged = @base.Duplicate(true);
                GDict over = _times.Get(_timeId, new GDict());
                _merged.Merge(over, true);
            }
            return _merged;
        }

        public static void SetLook(string id)
        {
            _Load();
            _lookId = id;
            _merged = new GDict();
        }
        // The times of day in rotation order (data/looks.json "times"); the first is the look itself.

        public static GArray<Variant> Times()
        {
            _Load();
            return _times["order"];
        }
        // The times a rampage may roll (data/looks.json "times" "play", D-359); a subset of times(), which
        // stays whole so --time= flags in captures, benches and tests keep working. No "play": all of them.

        public static GArray<Variant> PlayTimes()
        {
            _Load();
            return _times.Get("play", _times["order"]);
        }
        // The whole "times" table of data/looks.json (order, labels, each time's look overrides).

        public static GDict TimeTable()
        {
            _Load();
            return _times;
        }

        public static void SetTime(string id)
        {
            _Load();
            if (id == _timeId)
            {
                // keeps any change a capture made to the look in use
                return;
            }
            _timeId = id;
            _merged = new GDict();
        }
        // The weathers in rotation order (data/looks.json "weather").

        public static GArray<Variant> Weathers()
        {
            _Load();
            return _weather["order"];
        }
        // The whole "weather" table of data/looks.json (order, labels).

        public static GDict WeatherTable()
        {
            _Load();
            return _weather;
        }
        // The one current weather of the run in play (D-155): an id of weathers(). Main sets it when a
        // rampage starts (Weather.pick); presentation reads it. Before any run it is the first weather.

        public static string WeatherId()
        {
            _Load();
            return _weatherId;
        }

        public static void SetWeather(string id)
        {
            _Load();
            _weatherId = id;
        }
        // The fixed order: run n plays the nth time of day. Captures and tests use it to land on a known
        // time; the game picks with TimeOfDay (D-145).

        public static string TimeForRun(long runIndex)
        {
            return Gd.Str(Times()[Gd.Posmod(runIndex, Times().Size())]);
        }

        public static GDict LoadJson(string path)
        {
            Variant parsed = JSON.ParseString(FileAccess.GetFileAsString(path));
            if (Gd.Is<GDict>(parsed))
            {
                GDict @out = parsed;
                return @out;
            }
            Gd.PushError(Gd.Format("Content: %s is not a JSON object", path));
            return new GDict();
        }

        public static void _Load()
        {
            if (!_tuning.IsEmpty())
            {
                return;
            }
            _tuning = LoadJson("res://data/tuning.json");
            _upgrades = _List("res://data/upgrades.json", "upgrades");
            _species = _List("res://data/species.json", "species");
            _looks = _List("res://data/looks.json", "looks");
            GDict looksFile = LoadJson("res://data/looks.json");
            _lookId = Gd.Str(looksFile.Get("default", ""));
            _times = looksFile.Get("times", new GDict { { "order", Gd.Arr("") } });
            _timeId = Gd.Str(_times["order"][0]);
            _weather = looksFile.Get("weather", new GDict { { "order", Gd.Arr("") }, { "labels", new GDict() }, { "random_label", "" } });
            _weatherId = Gd.Str(_weather["order"][0]);
            _landmarks = LoadJson("res://data/landmarks.json").Get("landmarks", new GDict());
            _pool = LoadJson("res://data/city_buildings.json");
            _sports = LoadJson("res://data/sports.json");
            _materials = _List("res://data/materials.json", "materials");
            _continents = _List("res://data/continents.json", "continents");
            GDict campaign = LoadJson("res://data/continents.json");
            _stageWords = campaign.Get("stage_words", Gd.Arr());
            _bonusLines = campaign.Get("bonus_lines", new GDict());
            GDict names = _tuning.Get("names", new GDict());
            foreach (Variant content in Gd.Arr(_tuning, _upgrades, _species))
            {
                _Fill(content, names);
            }
            // The city plan reads landmark shapes from its config, so CityGen.map stays a function of cfg.
            GDict city = _tuning.Get("city", new GDict());
            city["landmark_shapes"] = _landmarks;
            city["building_pool"] = _pool;
        }

        public static GArray<GDict> _List(string path, string key)
        {
            GArray<GDict> @out = new GArray<GDict>();
            GArray<Variant> raw = LoadJson(path).Get(key, Gd.Arr());
            foreach (GDict entry in raw)
            {
                @out.Append(entry);
            }
            return @out;
        }
        // Player-facing names live once, in tuning "names" (a later rename is one line there); data text
        // writes {key} where one belongs ("{beam}" is the reptilian's signature beam).

        public static void _Fill(Variant node, GDict names)
        {
            if (Gd.Is<GDict>(node))
            {
                GDict dict = node;
                foreach (Variant key in dict)
                {
                    Variant value = dict[key];
                    if (Gd.Is<string>(value))
                    {
                        dict[key] = _Named(Gd.Str(value), names);
                    }
                    else
                    {
                        _Fill(value, names);
                    }
                }
            }
            else if (Gd.Is<GArray<Variant>>(node))
            {
                GArray<Variant> list = node;
                foreach (long i in Gd.Range(list.Size()))
                {
                    if (Gd.Is<string>(list[i]))
                    {
                        list[i] = _Named(Gd.Str(list[i]), names);
                    }
                    else
                    {
                        _Fill(list[i], names);
                    }
                }
            }
        }

        public static string _Named(string text, GDict names)
        {
            foreach (string key in names)
            {
                text = text.Replace(Gd.Format("{%s}", key), Gd.Str(names[key]));
            }
            return text;
        }

        void _InitFields()
        {
        }
        public Content() { _InitFields(); }
    }
}
