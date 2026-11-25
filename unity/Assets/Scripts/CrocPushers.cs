using UnityEngine;

// The slice's pushers: a kinematic sphere on each body sphere that pushes its rigid debris aside. Made on the first
// CollectSpheres (SliceGame), so the rampage, whose debris meets the kaiju's hide instead (KaijuHideBody), has none
// (director, 2026-11-25).
public sealed partial class Croc
{
    Rigidbody[] pushers;

    // To where the body spheres are now, making them first.
    void MovePushers()
    {
        if (pushers == null)
        {
            pushers = new Rigidbody[bodySpheres.Count];
            for (int i = 0; i < pushers.Length; i++)
            {
                var go = new GameObject("pusher");
                var sphere = go.AddComponent<SphereCollider>();
                sphere.radius = bodySpheres[i].r * tuning.pusher_scale;
                Rigidbody rb = go.AddComponent<Rigidbody>();
                rb.isKinematic = true;
                pushers[i] = rb;
            }
        }
        for (int i = 0; i < pushers.Length; i++) pushers[i].MovePosition(prevBody[i]);
    }

    void DropPushers()
    {
        if (pushers == null) return;
        foreach (Rigidbody rb in pushers)
            if (rb != null)
                Object.Destroy(rb.gameObject);
    }
}
