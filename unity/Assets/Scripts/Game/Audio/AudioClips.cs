using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Networking;
using S = Kaiju.Sim;

// The sound files, loaded while the game runs: the .ogg files sit under the res root (StreamingAssets/res in the
// player, the repo in the editor) and are read in the background, so no frame waits for one.
public static class AudioClips
{
    static readonly Dictionary<string, AudioClip> clips = new Dictionary<string, AudioClip>();
    static readonly HashSet<string> loading = new HashSet<string>();
    static readonly HashSet<string> missing = new HashSet<string>();

    public static int Loaded => clips.Count;
    public static int MissingCount => missing.Count;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset()
    {
        clips.Clear();
        loading.Clear();
        missing.Clear();
    }

    public static string PathOf(string file) => Path.GetFullPath(Path.Combine(S.FileAccess.Root, file));

    public static bool OnDisk(string file) => File.Exists(PathOf(file));

    public static bool Missing(string file) => missing.Contains(file);

    // Loaded or known missing: nothing more will come of waiting.
    public static bool Settled(string file) => clips.ContainsKey(file) || missing.Contains(file);

    // The clip when it is loaded; otherwise null, and the load begins. `music` keeps a long file compressed
    // in memory, so loading it does not unpack minutes of sound in one go.
    public static AudioClip Get(string file, bool music = false)
    {
        if (clips.TryGetValue(file, out AudioClip clip)) return clip;
        if (missing.Contains(file) || loading.Contains(file)) return null;
        if (!OnDisk(file))
        {
            Miss(file, "no such file");
            return null;
        }
        loading.Add(file);
        AudioHost.Ensure().StartCoroutine(Load(file, music));
        return null;
    }

    public static float Length(string file, float fallback)
    {
        return clips.TryGetValue(file, out AudioClip clip) ? clip.length : fallback;
    }

    static IEnumerator Load(string file, bool music)
    {
        string url = new Uri(PathOf(file)).AbsoluteUri;
        using (UnityWebRequest request = UnityWebRequestMultimedia.GetAudioClip(url, AudioType.OGGVORBIS))
        {
            var handler = (DownloadHandlerAudioClip)request.downloadHandler;
            handler.compressed = music;
            yield return request.SendWebRequest();
            loading.Remove(file);
            AudioClip clip = request.result == UnityWebRequest.Result.Success ? DownloadHandlerAudioClip.GetContent(request) : null;
            if (clip == null)
            {
                Miss(file, request.error ?? "not a sound");
                yield break;
            }
            clip.name = file;
            clips[file] = clip;
        }
    }

    // A file that is not there is said once; its sounds are then silent.
    static void Miss(string file, string why)
    {
        if (missing.Add(file)) Debug.LogWarning("audio: missing " + file + " (" + why + ")");
    }
}
