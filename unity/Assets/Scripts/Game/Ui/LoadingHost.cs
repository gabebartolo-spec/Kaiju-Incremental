// The loading screen's own object: it outlives the scene reload a rampage starts with, and counts the frames
// that must be drawn before the load is asked for and before the screen goes (Loading.cs).
using System;
using UnityEngine;

public sealed class LoadingHost : MonoBehaviour
{
    // What starts the load, and the frame it is called on; null when nothing waits.
    public Action go;
    public int goAt;
    // The frame the screen goes on; -1 while the load is still ahead.
    public int hideAt = -1;

    void Update()
    {
        if (go != null && Time.frameCount >= goAt)
        {
            Action start = go;
            go = null;
            try
            {
                start();
            }
            catch (Exception e)
            {
                // A load that could not start must not leave the screen up over the game.
                Debug.LogException(e);
                Loading.Hide();
                return;
            }
        }
        if (hideAt >= 0 && Time.frameCount >= hideAt) Loading.Hide();
    }
}
