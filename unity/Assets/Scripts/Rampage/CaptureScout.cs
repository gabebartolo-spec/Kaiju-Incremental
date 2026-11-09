using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using UnityEngine;
using S = Kaiju.Sim;

// Capture only (-rampage-scout <path>): a dry run with no images. Logs, one JSON line per frame, what a camera
// would see: its pose, which buildings still stand, and the croc's body. ~/.claude/tools/frame_check.py reads it
// to project a subject to the screen and test its line of sight before anything is filmed. Godot axes throughout.
public sealed class CaptureScout
{
    readonly StreamWriter log;
    readonly S.RampageSim sim;
    readonly Croc croc;
    readonly bool[] down;
    readonly List<Vector4> spheres = new List<Vector4>();
    readonly StringBuilder line = new StringBuilder(8192);
    readonly int frames;
    int index;

    public CaptureScout(string path, int frames, S.RampageSim simulation, Croc body, int width, int height)
    {
        this.frames = frames;
        sim = simulation;
        croc = body;
        down = new bool[sim.buildings.Size()];
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path)));
        log = new StreamWriter(path, false, new UTF8Encoding(false));
        line.Append("{\"kind\":\"head\",\"width\":").Append(width).Append(",\"height\":").Append(height).Append(",\"buildings\":[");
        for (int n = 0; n < down.Length; n++)
        {
            S.RampageSim.Building b = sim.buildings[n];
            if (n > 0) line.Append(',');
            line.Append('[');
            Num((float)(double)b.x).Append(',');
            Num((float)(double)b.z).Append(',');
            Num((float)(double)b.w).Append(',');
            Num((float)(double)b.d).Append(',');
            Num((float)(double)b.height).Append(']');
        }
        line.Append("]}");
        log.WriteLine(line);
    }

    StringBuilder Num(float v) => line.Append(v.ToString("F3", CultureInfo.InvariantCulture));

    StringBuilder Vec(Vector3 v)
    {
        line.Append('[');
        Num(v.x).Append(',');
        Num(v.y).Append(',');
        return Num(v.z).Append(']');
    }

    // Unity to Godot axes: z flips.
    static Vector3 Flip(Vector3 v) => new Vector3(v.x, v.y, -v.z);

    // True once the last frame is written.
    public bool Step(Camera cam, CameraBubble bubble)
    {
        line.Clear();
        line.Append("{\"kind\":\"frame\",\"i\":").Append(index).Append(",\"unity\":").Append(Time.frameCount).Append(",\"fov\":");
        Num(cam.fieldOfView).Append(",\"eye\":");
        Vec(Flip(cam.transform.position)).Append(",\"fwd\":");
        Vec(Flip(cam.transform.forward)).Append(",\"up\":");
        Vec(Flip(cam.transform.up)).Append(",\"fell\":[");
        bool any = false;
        for (int n = 0; n < down.Length; n++)
        {
            S.RampageSim.Building b = sim.buildings[n];
            if (down[n] || b.frame == null || b.frame.aliveCount > 0) continue;
            down[n] = true;
            if (any) line.Append(',');
            line.Append(n);
            any = true;
        }
        line.Append("],\"open\":[");
        any = false;
        foreach (int n in bubble.OpenNow)
        {
            if (any) line.Append(',');
            line.Append(n);
            any = true;
        }
        line.Append("],\"body\":[");
        croc.BodySpheres(spheres);
        for (int s = 0; s < spheres.Count; s++)
        {
            if (s > 0) line.Append(',');
            line.Append('[');
            Num(spheres[s].x).Append(',');
            Num(spheres[s].y).Append(',');
            Num(spheres[s].z).Append(',');
            Num(spheres[s].w).Append(']');
        }
        line.Append("]}");
        log.WriteLine(line);
        index++;
        if (index < frames) return false;
        log.Dispose();
        Debug.Log($"rampage: scout done, {frames} frames");
        return true;
    }
}
