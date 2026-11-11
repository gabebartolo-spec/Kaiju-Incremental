// The player's own folder (Godot's user://): saves and settings live here. Plain C#, so the tests point Root at a
// temp folder and the Unity host at Application.persistentDataPath (a fresh folder: Godot saves are not adopted).
using System;
using System.IO;
using System.Text;

namespace Kaiju.Game
{
    public static class UserDir
    {
        // Set once by the host before any read or write.
        public static string Root = "";

        // What a half-written file is called until it replaces the real one.
        const string TempSuffix = ".tmp";

        public static string Path(string name) => System.IO.Path.Combine(Root, name);

        public static bool Exists(string name) => File.Exists(Path(name));

        // "" when the file is missing or cannot be read.
        public static string ReadText(string name)
        {
            try
            {
                return File.Exists(Path(name)) ? File.ReadAllText(Path(name), Encoding.UTF8) : "";
            }
            catch (Exception e) when (e is IOException || e is UnauthorizedAccessException)
            {
                return "";
            }
        }

        // Written whole to a temp file first and then swapped in, so a crash mid-write never leaves half a save.
        // False when it could not be written; the old file is then still there.
        public static bool WriteText(string name, string text)
        {
            string path = Path(name);
            string temp = path + TempSuffix;
            try
            {
                Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path));
                using (FileStream stream = new FileStream(temp, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    byte[] bytes = new UTF8Encoding(false).GetBytes(text);
                    stream.Write(bytes, 0, bytes.Length);
                    stream.Flush(true);
                }
                if (File.Exists(path))
                {
                    File.Replace(temp, path, null);
                }
                else
                {
                    File.Move(temp, path);
                }
                return true;
            }
            catch (Exception e) when (e is IOException || e is UnauthorizedAccessException)
            {
                try { if (File.Exists(temp)) File.Delete(temp); }
                catch (Exception e2) when (e2 is IOException || e2 is UnauthorizedAccessException) { }
                return false;
            }
        }

        public static void Delete(string name)
        {
            try
            {
                if (File.Exists(Path(name))) File.Delete(Path(name));
            }
            catch (Exception e) when (e is IOException || e is UnauthorizedAccessException)
            {
            }
        }

        // When the file was last written (UTC ticks); -1 when it is missing.
        public static long ModifiedTicks(string name) =>
            File.Exists(Path(name)) ? File.GetLastWriteTimeUtc(Path(name)).Ticks : -1;
    }
}
