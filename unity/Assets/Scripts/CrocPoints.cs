using System.Collections.Generic;
using UnityEngine;

// Croc's points on the body, for the views that aim at it or leave from it: a bone now, the rooftop rounds'
// targets, the body as spheres for a framing check, the ridge the charge runs along, and the throat the bolt leaves.
public sealed partial class Croc
{
    const float AXIS_FLOOR_SQ = 1e-4f; // a bone too short to have an axis

    // Godot axes: where a bone is drawn now.
    public Vector3 BoneAt(string name)
    {
        return WorldMatrix().MultiplyPoint3x4(global[System.Array.IndexOf(names, name)].GetColumn(3));
    }

    public string RootBone => names[0];

    // Rooftop rounds (scenes/rooftop_aim.gd): a bone's index or -1, the rest cubes it carries, and where one is now (Godot axes).
    public int StrikeBone(string name) => System.Array.IndexOf(names, name);

    public void StrikeCubes(int bone, List<Vector3> into)
    {
        for (int i = 0; i < cubeAt.Length; i++)
            if (cubeBone[i] == bone) into.Add(cubeAt[i]);
    }

    public Vector3 StrikePoint(int bone, Vector3 rest) => WorldMatrix().MultiplyPoint3x4(pose[bone].MultiplyPoint3x4(rest));

    Vector4[] restSpheres;

    // Godot axes, capture only: the body as one sphere per bone (xyz centre, w radius), from the cubes each bone
    // carries, so a framing check can tell when the croc stands between a camera and its own mouth.
    public void BodySpheres(List<Vector4> into)
    {
        if (restSpheres == null)
        {
            restSpheres = new Vector4[pose.Length];
            for (int b = 0; b < pose.Length; b++)
            {
                Vector3 sum = Vector3.zero;
                int count = 0;
                for (int i = 0; i < cubeAt.Length; i++)
                    if (cubeBone[i] == b) { sum += cubeAt[i]; count++; }
                if (count == 0) continue;
                Vector3 mid = sum / count;
                var far = new List<float>(count);
                for (int i = 0; i < cubeAt.Length; i++)
                    if (cubeBone[i] == b) far.Add((cubeAt[i] - mid).magnitude);
                far.Sort();
                restSpheres[b] = new Vector4(mid.x, mid.y, mid.z, far[(count * 3) / 4]);
            }
        }
        into.Clear();
        Matrix4x4 world = WorldMatrix();
        float scale = world.lossyScale.y;
        for (int b = 0; b < restSpheres.Length; b++)
        {
            if (restSpheres[b].w <= 0f) continue;
            Vector3 at = world.MultiplyPoint3x4(pose[b].MultiplyPoint3x4(restSpheres[b]));
            into.Add(new Vector4(at.x, at.y, at.z, restSpheres[b].w * scale));
        }
    }

    // The ridge from tail tip to head (scenes/spine_charge.gd _find_ridge): on each bone, the highest cell
    // of its middle stretch at rest, lifted clear of the hide. This rig's bones carry no direction, so the
    // stretch runs from the bone's head to its farthest cell.
    public void FindRidge(IList<string> bones, float low, float high, float liftVoxels)
    {
        var at = new List<int>();
        var tops = new List<Vector3>();
        float voxel = cubeMat.GetFloat("_CubeSize");
        foreach (string bone in bones)
        {
            int b = System.Array.IndexOf(names, bone);
            if (b < 0) continue;
            Vector3 head = RestHead(b), axis = FarCell(b) - head;
            bool found = false;
            Vector3 best = Vector3.zero;
            for (int i = 0; i < cubeAt.Length; i++)
            {
                if (cubeBone[i] != b) continue;
                float along = Vector3.Dot(cubeAt[i] - head, axis) / Mathf.Max(axis.sqrMagnitude, AXIS_FLOOR_SQ);
                if (along < low || along > high || (found && cubeAt[i].y <= best.y)) continue;
                best = cubeAt[i];
                found = true;
            }
            if (!found) continue;
            at.Add(b);
            tops.Add(best + Vector3.up * (liftVoxels * voxel));
        }
        ridgeBones = at.ToArray();
        ridgeRest = tops.ToArray();
        if (jawIndex >= 0) jawTip = FarCell(jawIndex);
        if (upperIndex >= 0) upperTip = FarCell(upperIndex);
    }

    public int RidgeSize => ridgeBones.Length;

    // Godot axes: ridge point `i` (tail tip 0 .. head) now.
    public Vector3 RidgeAt(int i) => WorldMatrix().MultiplyPoint3x4(pose[ridgeBones[i]].MultiplyPoint3x4(ridgeRest[i]));

    Vector3 RestHead(int bone) => bind[bone].inverse.GetColumn(3);

    Vector3 FarCell(int bone)
    {
        Vector3 head = RestHead(bone), far = head;
        float most = -1f;
        for (int i = 0; i < cubeAt.Length; i++)
        {
            if (cubeBone[i] != bone) continue;
            float d = (cubeAt[i] - head).sqrMagnitude;
            if (d > most) { most = d; far = cubeAt[i]; }
        }
        return far;
    }

    // Godot axes: where the bolt leaves (scenes/breath_beam.gd throat_of): out from the hinge a share of
    // the way to the jaws' tips, and a share of the way from the lower to the upper.
    public Vector3 ThroatAt(float along, float up)
    {
        Matrix4x4 world = WorldMatrix();
        Vector3 hinge = world.MultiplyPoint3x4(global[jawIndex].GetColumn(3));
        Vector3 low = Vector3.Lerp(hinge, world.MultiplyPoint3x4(pose[jawIndex].MultiplyPoint3x4(jawTip)), along);
        Vector3 high = Vector3.Lerp(hinge, world.MultiplyPoint3x4(pose[upperIndex].MultiplyPoint3x4(upperTip)), along);
        return Vector3.Lerp(low, high, up);
    }
}
