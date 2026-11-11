// The title screen's rules without the engine (scenes/title_screen.gd, scenes/slot_list.gd,
// scenes/title_colossus.gd): the numbers, what a slot's plate says, which plate can be picked, the questions,
// where the focus starts, the news lines, how a row's width is shared, and where the title art sits on screen.
// Game/Screens/TitleScreen.cs and Game/Ui/TitleBackdrop.cs draw what this decides.
using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // What picking a slot does (slot_list.gd Mode).
    public enum SlotMode { Continue, New }

    public static class TitleMenu
    {
        // ---- title_screen.gd ------------------------------------------------------------------------------
        public const string LOGO = "KAIJU EVOLUTION";
        public const string EXIT_TEXT = "RUN FOR YOUR LIFE!?";
        public const float BUTTON_HEIGHT = 110f;
        public const float ROW_INSET = 6f;
        public const float CONTINUE_SHARE = 3f;
        public const float GEAR_SIZE = 76f;
        public const float GEAR_CORNER = 32f;
        public const float EXIT_LIFT = 20f;
        public const float ALONE_SHARE = 0.42f;
        public const float ALONE_HEIGHT = 80f;
        public const int LOGO_SIZE = 86;
        public const float LOGO_GAP = 10f;
        public const float COLUMN_WIDTH = 800f;
        public const float COLUMN_TOP = 0.21f;
        public const int GLOW_TEXELS = 512;
        // The gear's picture inside its plate: px in from the left, top, right and bottom.
        public const float GEAR_LEFT = 8f, GEAR_TOP = 6f, GEAR_RIGHT = 12f, GEAR_BOTTOM = 14f;
        // A sky glow is this much taller than wide in screen shares (16:9, so it reads round).
        public const float GLOW_ASPECT = 1.78f;

        // ---- slot_list.gd ---------------------------------------------------------------------------------
        public const string PICK_CONTINUE = "Pick a kaiju to wake.";
        public const string PICK_NEW = "Pick a slot for the new kaiju.";
        public const string EMPTY = "EMPTY";
        public const string LOCKED = "NOT IN THIS VERSION";
        public const string UNREADABLE = "UNREADABLE";
        public const float ROW_HEIGHT = 96f;
        public const float BACK_HEIGHT = 72f;
        public const float ROW_GAP = 12f;
        public const float SLOT_SHARE = 3f;
        public const int NOTE_SIZE = 30;

        // The text on a slot's plate (slot_list.gd plate_text).
        public static string PlateText(SlotInfo info)
        {
            string head = Tr.F("SLOT %d", info.Slot);
            if (!info.Taken) return head + "\n" + Tr.T(EMPTY);
            if (!info.Readable) return head + "\n" + Tr.T(UNREADABLE);
            string line = info.Continues ? info.Summary : Tr.T(LOCKED);
            return head + " - " + info.Specimen + "\n" + line.ToUpperInvariant();
        }

        // True when the plate cannot be picked: Continue needs a save this build can resume.
        public static bool PlateOff(SlotMode mode, SlotInfo info)
        {
            return mode == SlotMode.Continue && !(info.Taken && info.Continues);
        }

        // True when picking the plate asks first: a new kaiju over a slot that holds one.
        public static bool NeedsConfirm(SlotMode mode, SlotInfo info)
        {
            return mode == SlotMode.New && info.Taken;
        }

        // What a question calls the kaiju in the slot (slot_list.gd _who).
        public static string Who(SlotInfo info)
        {
            if (!info.Readable) return Tr.T("unreadable save");
            string species = Tr.T(info.Species ?? "");
            return species != "" ? species + " (" + info.Specimen + ")" : info.Specimen;
        }

        public static string StartOverQuestion(SlotInfo info)
        {
            return Tr.F("Start over in slot %d? Your %s and every evolution are lost.", info.Slot, Who(info));
        }

        public static string DeleteQuestion(SlotInfo info)
        {
            return Tr.F("Delete slot %d? Your %s and every evolution are lost.", info.Slot, Who(info));
        }

        // The note above the slots.
        public static string PickNote(SlotMode mode)
        {
            return Tr.T(mode == SlotMode.Continue ? PICK_CONTINUE : PICK_NEW);
        }

        // True with no save in any slot: New Kaiju starts in slot 1 at once (title_screen.gd _on_new).
        public static bool AllEmpty(IList<SlotInfo> slots)
        {
            foreach (SlotInfo info in slots) if (info.Taken) return false;
            return true;
        }

        // The slot whose plate takes the focus when the list opens: the first that can be picked, or
        // `focusSlot` when that one can; 0 means BACK (slot_list.gd _show_list).
        public static int FocusSlot(SlotMode mode, IList<SlotInfo> slots, int focusSlot)
        {
            int focus = 0;
            foreach (SlotInfo info in slots)
            {
                if (PlateOff(mode, info)) continue;
                if (focus == 0 || info.Slot == focusSlot) focus = info.Slot;
            }
            return focus;
        }

        // What Continue resumes: the newest slot's summary, "" with none (main.gd _summary(load_game(latest))).
        public static string SummaryOf(IList<SlotInfo> slots, int latest)
        {
            foreach (SlotInfo info in slots) if (info.Slot == latest) return info.Summary ?? "";
            return "";
        }

        public static string ContinueLabel(string summary)
        {
            return Tr.F("CONTINUE GAME\n%s", summary.ToUpperInvariant());
        }

        // The species the news names (title_screen.gd _latest_species).
        public static string LatestSpecies(IList<SlotInfo> slots, int latest, string summary)
        {
            foreach (SlotInfo info in slots)
            {
                if (info.Slot == latest && !string.IsNullOrEmpty(info.Species)) return Tr.T(info.Species);
            }
            int comma = summary.IndexOf(',');
            return comma < 0 ? summary : summary.Substring(0, comma);
        }

        // The crawl's headlines: tuning news.title, with "<SPECIES> STILL AT LARGE" first when there is a
        // kaiju to continue (title_screen.gd _add_broadcast_frame).
        public static List<string> NewsLines(IList<SlotInfo> slots, int latest, string summary)
        {
            S.GDict news = S.Content.Section("news");
            List<string> lines = new List<string>();
            S.GArray<S.Variant> title = news["title"];
            foreach (S.Variant line in title) lines.Add(Tr.T(S.Gd.Str(line)));
            if (summary != "")
            {
                string who = LatestSpecies(slots, latest, summary).ToUpperInvariant();
                lines.Insert(0, Tr.T(S.Gd.Str(news["at_large"])).Replace("{species}", who));
            }
            return lines;
        }

        // A row's width shared as Godot's box container does: `total` less the gaps goes to the children by
        // `ratios`; one whose share is under its least width takes that and the rest share what is left.
        public static float[] Shares(float total, float gap, float[] ratios, float[] mins)
        {
            int n = ratios.Length;
            float[] widths = new float[n];
            bool[] held = new bool[n];
            float free = total - gap * (n - 1);
            while (true)
            {
                float left = free, sum = 0f;
                for (int i = 0; i < n; i++)
                {
                    if (held[i]) left -= widths[i];
                    else sum += ratios[i];
                }
                if (sum <= 0f) break;
                bool again = false;
                for (int i = 0; i < n; i++)
                {
                    if (held[i]) continue;
                    float share = left * ratios[i] / sum;
                    if (share < mins[i])
                    {
                        widths[i] = mins[i];
                        held[i] = true;
                        again = true;
                        break;
                    }
                    widths[i] = share;
                }
                if (!again) break;
            }
            return widths;
        }

        // The lone New Kaiju button's least width in a row `rowWidth` wide.
        public static float AloneWidth(float rowWidth)
        {
            return rowWidth * ALONE_SHARE;
        }

        // ---- the art's place on screen ----------------------------------------------------------------------

        // A sky glow's box as screen shares with y up (left, bottom, right, top), from tuning's centre and
        // radius with y down (title_screen.gd _add_sky).
        public static float[] GlowBox(double gx, double gy, double r)
        {
            return new[]
            {
                (float)(gx - r), (float)(1.0 - (gy + r * GLOW_ASPECT)), (float)(gx + r), (float)(1.0 - (gy - r * GLOW_ASPECT)),
            };
        }

        // Where a world point lands on screen for Godot's Camera3D at `eye` looking at `look` (vertical fov,
        // height kept): u and v are screen shares from the left and the bottom; depth is metres ahead.
        public static void Project(double[] eye, double[] look, double fovDeg, double aspect, double[] p, out double u, out double v, out double depth)
        {
            double fx = look[0] - eye[0], fy = look[1] - eye[1], fz = look[2] - eye[2];
            double fl = Math.Sqrt(fx * fx + fy * fy + fz * fz);
            fx /= fl; fy /= fl; fz /= fl;
            // right = forward x up(0,1,0); up = right x forward.
            double rx = -fz, rz = fx;
            double rl = Math.Sqrt(rx * rx + rz * rz);
            rx /= rl; rz /= rl;
            double ux = -rz * fy, uy = rz * fx - rx * fz, uz = rx * fy;
            double dx = p[0] - eye[0], dy = p[1] - eye[1], dz = p[2] - eye[2];
            depth = dx * fx + dy * fy + dz * fz;
            double half = Math.Tan(fovDeg * Math.PI / 360.0);
            double x = dx * rx + dz * rz, y = dx * ux + dy * uy + dz * uz;
            u = 0.5 + 0.5 * x / (depth * half * aspect);
            v = 0.5 + 0.5 * y / (depth * half);
        }

        // The colossus card's feet at rest (title_colossus.gd _place with no steps taken).
        public static double[] ColossusFeet(S.GDict cfg)
        {
            S.GArray<S.Variant> start = cfg["start"];
            return new[] { S.Num.F(start[0]), S.Num.F(cfg["ground_y"]), S.Num.F(start[1]) };
        }

        // The card's width in metres for a picture `texWidth` by `texHeight` (title_colossus.gd _card_sprite).
        public static double ColossusWidth(S.GDict cfg, int texWidth, int texHeight)
        {
            return S.Num.F(cfg["height"]) * texWidth / texHeight;
        }

        // The card's box on screen (left, bottom, right, top as screen shares, y up): its bottom-left and
        // top-right corners through the title camera. The camera looks up a little, so the true shape leans
        // a hair; the box is its corners.
        public static float[] ColossusBox(S.GDict title, double aspect, int texWidth, int texHeight)
        {
            S.GDict cfg = title["colossus"];
            double[] feet = ColossusFeet(cfg);
            double width = ColossusWidth(cfg, texWidth, texHeight), height = S.Num.F(cfg["height"]);
            Camera(title, out double[] eye, out double[] look, out double fov);
            Project(eye, look, fov, aspect, new[] { feet[0] - width * 0.5, feet[1], feet[2] }, out double u0, out double v0, out _);
            Project(eye, look, fov, aspect, new[] { feet[0] + width * 0.5, feet[1] + height, feet[2] }, out double u1, out double v1, out _);
            return new[] { (float)u0, (float)v0, (float)u1, (float)v1 };
        }

        // The eye's glow on screen: centre (u, v) and its size as a share of the screen's height
        // (title_colossus.gd _eye_sprite: a billboard `size` metres across at the picture's eye).
        public static float[] ColossusEye(S.GDict title, double aspect, int texWidth, int texHeight)
        {
            S.GDict cfg = title["colossus"];
            S.GDict eyeCfg = cfg["eye"];
            S.GArray<S.Variant> uv = eyeCfg["uv"];
            double[] feet = ColossusFeet(cfg);
            double width = ColossusWidth(cfg, texWidth, texHeight), height = S.Num.F(cfg["height"]);
            double[] at =
            {
                feet[0] + (S.Num.F(uv[0]) - 0.5) * width, feet[1] + (1.0 - S.Num.F(uv[1])) * height, feet[2] + S.Num.F(eyeCfg["forward"]),
            };
            Camera(title, out double[] eye, out double[] look, out double fov);
            Project(eye, look, fov, aspect, at, out double u, out double v, out double depth);
            double share = S.Num.F(eyeCfg["size"]) / (2.0 * depth * Math.Tan(fov * Math.PI / 360.0));
            return new[] { (float)u, (float)v, (float)share };
        }

        // The eye's alpha `t` seconds in, with the colossus at rest (title_colossus.gd _show(0)).
        public static float EyeAlpha(S.GDict eyeCfg, double t)
        {
            double pulse = 0.5 + 0.5 * Math.Sin(t * Math.PI * 2.0 * S.Num.F(eyeCfg["pulse_hz"]));
            double share = S.Num.F(eyeCfg["pulse"]);
            return (float)(S.Num.F(eyeCfg["idle"]) * (1.0 - share + share * 2.0 * pulse));
        }

        static void Camera(S.GDict title, out double[] eye, out double[] look, out double fov)
        {
            S.GDict cam = title["camera"];
            S.GArray<S.Variant> position = cam["position"], target = cam["look"];
            eye = new[] { S.Num.F(position[0]), S.Num.F(position[1]), S.Num.F(position[2]) };
            look = new[] { S.Num.F(target[0]), S.Num.F(target[1]), S.Num.F(target[2]) };
            fov = S.Num.F(cam["fov"]);
        }
    }
}
