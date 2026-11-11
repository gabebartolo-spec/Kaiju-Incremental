// The lab card's words and timing (scenes/specimen_card.gd, D-260): the kaiju died, so the next one out of the lab
// is one number up. Copy in tuning "news" specimen, seconds and gap in tuning "ui" specimen_card.
using System;
using System.Globalization;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public static class CreationCard
    {
        // The separator between the headline's halves.
        public const string DOT = " - ";

        // `text` with "{lost}" and "{next}" as two-digit specimen numbers (the one lost, `specimen`).
        public static string Fill(string text, long specimen)
        {
            string gone = Math.Max(1L, specimen - 1).ToString("00", CultureInfo.InvariantCulture);
            return text.Replace("{lost}", gone).Replace("{next}", specimen.ToString("00", CultureInfo.InvariantCulture));
        }

        static GDict Copy() => Content.Section("news")["specimen"];

        static GDict Cfg() => Content.Section("ui")["specimen_card"];

        // The card's title, e.g. "SPECIMEN K-02".
        public static string Title(long specimen) => Fill(Tr.T(Gd.Str(Copy()["title"])), specimen);

        // The headline as one line, e.g. "K-01 LOST - K-02 RELEASED".
        public static string Headline(long specimen)
        {
            GArray<Variant> halves = Copy()["headline"];
            return Fill(Tr.T(Gd.Str(halves[0])), specimen) + DOT + Fill(Tr.T(Gd.Str(halves[1])), specimen);
        }

        // How long the card is on show (seconds) and the gap between its lines (px at 1080p).
        public static double Seconds() => Num.F(Cfg()["seconds"]);

        public static int Gap() => (int)Num.I(Cfg()["gap"]);

        // The number of the specimen about to rise (the save's "specimen").
        public static long Specimen(GDict save) => Num.I((save ?? new GDict()).Get("specimen", 1L));
    }
}
