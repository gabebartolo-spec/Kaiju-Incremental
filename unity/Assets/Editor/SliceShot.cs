using System.IO;
using System.Text;
using UnityEditor;
using UnityEngine;

// Editor-side checks for a windowless editor: what the slice's shaders report, and a still of the running game.
public static class SliceShot
{
    public static string ShaderErrors()
    {
        var text = new StringBuilder();
        foreach (string name in new[] { "Shaders/SliceLit", "Shaders/Agx", "Shaders/Flame" })
        {
            Shader shader = Resources.Load<Shader>(name);
            if (shader == null)
            {
                text.AppendLine($"{name}: not found");
                continue;
            }
            ShaderMessage[] messages = ShaderUtil.GetShaderMessages(shader);
            text.AppendLine($"{name}: {messages.Length} messages, {shader.passCount} passes");
            for (int i = 0; i < Mathf.Min(messages.Length, 12); i++)
                text.AppendLine($"  {messages[i].severity} {messages[i].file}:{messages[i].line} {messages[i].message} {messages[i].messageDetails}");
        }
        return text.ToString();
    }

    // Renders the main camera into a 1080p target and writes a png. Play mode only.
    public static string Still(string path)
    {
        Camera cam = Object.FindFirstObjectByType<Camera>();
        if (cam == null) return "no camera";
        var target = new RenderTexture(1920, 1080, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
        cam.targetTexture = target;
        cam.Render();
        RenderTexture.active = target;
        var image = new Texture2D(1920, 1080, TextureFormat.RGB24, false);
        image.ReadPixels(new Rect(0, 0, 1920, 1080), 0, 0);
        image.Apply();
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        File.WriteAllBytes(path, image.EncodeToPNG());
        cam.targetTexture = null;
        RenderTexture.active = null;
        Object.DestroyImmediate(target);
        Object.DestroyImmediate(image);
        return "wrote " + path;
    }
}
