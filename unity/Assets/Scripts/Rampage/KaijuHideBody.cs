using System;
using Kaiju.Game;
using UnityEngine;

// scenes/kaiju_hide.gd: the kaiju's iron hide as one rigid physics body (director 2026-11-03), a capsule round him
// (FallContact.Hide, tuning fall_contact) that follows the sim's kaiju every physics step, so city debris hits him,
// shatters and slides off, never passes through. Kinematic: nothing pushes him and he never deforms. Godot's capsule
// stands upright and never turns, as here; its place comes in Godot axes (z mirrored). Presentation only.
public sealed class KaijuHideBody : MonoBehaviour
{
    // The hide now (CityDraw: KaijuHide.Of(FallContact.Hide)).
    public Func<HideCapsule> capsule;
    CapsuleCollider shape;
    Rigidbody body;

    void Awake()
    {
        shape = gameObject.AddComponent<CapsuleCollider>();
        shape.direction = 1;  // Godot's CapsuleShape3D stands along y
        body = gameObject.AddComponent<Rigidbody>();
        body.isKinematic = true;
        body.useGravity = false;
    }

    void FixedUpdate() => Follow(false);

    // _follow: the shape's radius and height (end caps included) and its middle, from the capsule now. `place` puts it
    // there at once (_init); each physics step moves it there, so what it meets is pushed as by Godot's
    // AnimatableBody3D.
    public void Follow(bool place)
    {
        HideCapsule cap = capsule();
        shape.radius = cap.radius;
        shape.height = KaijuHide.Height(cap);
        System.Numerics.Vector3 mid = KaijuHide.Centre(cap);
        var at = new Vector3(mid.X, mid.Y, -mid.Z);
        if (place)
        {
            transform.position = at;
            body.position = at;
        }
        else body.MovePosition(at);
    }
}
