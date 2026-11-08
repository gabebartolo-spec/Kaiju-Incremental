using System.IO;
using UnityEngine;

// A deterministic 1080p png sequence of the running game from a fixed camera: every frame advances the
// game by exactly 1/fps however long the frame takes to render. For the side-by-sides with Godot.
public sealed class SliceClip : MonoBehaviour
{
    const int WIDTH = 1920, HEIGHT = 1080;

    string dir;
    int frames, frame, skip;
    Vector3 eye, aim;
    Camera cam;
    SliceGame game;
    RenderTexture target;
    Texture2D image;

    public static string Begin(string dir, int frames, int fps, int skip, Vector3 eye, Vector3 aim)
    {
        Directory.CreateDirectory(dir);
        var clip = new GameObject("clip").AddComponent<SliceClip>();
        clip.dir = dir;
        clip.frames = frames;
        clip.skip = skip;
        clip.eye = eye;
        clip.aim = aim;
        clip.game = FindFirstObjectByType<SliceGame>();
        clip.cam = FindFirstObjectByType<Camera>();
        clip.target = new RenderTexture(WIDTH, HEIGHT, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
        clip.image = new Texture2D(WIDTH, HEIGHT, TextureFormat.RGB24, false);
        Time.captureFramerate = fps;
        return $"clip: {frames} frames to {dir}";
    }

    void LateUpdate()
    {
        cam.transform.position = eye;
        cam.transform.LookAt(aim);
        game.SetSmokeFocus();
        if (skip > 0)
        {
            skip--;
            return;
        }
        cam.targetTexture = target;
        cam.Render();
        RenderTexture.active = target;
        image.ReadPixels(new Rect(0, 0, WIDTH, HEIGHT), 0, 0);
        image.Apply();
        RenderTexture.active = null;
        cam.targetTexture = null;
        File.WriteAllBytes(Path.Combine(dir, $"f{frame:D4}.png"), image.EncodeToPNG());
        frame++;
        if (frame < frames) return;
        Time.captureFramerate = 0;
        Debug.Log($"clip: done, {frames} frames in {dir}");
        Destroy(target);
        Destroy(image);
        Destroy(gameObject);
    }
}
