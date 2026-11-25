using UnityEngine;

// scenes/landmark_burst.gd _cover and _draw_clouds: one soft puff of dust over a bursting landmark section, standing
// still where it was put, swelling from CLOUD_START to CLOUD_START + CLOUD_SWELL of its size and thinning as
// alpha (1 - k²) over its life. The smoke's own quad, lit (self_lit 0), with nothing cleared at the centre
// (centre_keep 1) but thinned near the eye and in front of the kaiju as all smoke is (view_clear: clear 2). Bursts' size curve eases between its points, so the straight swell is laid on
// CLOUD_POINTS of them; its colour runs straight between four stops, so the fade is laid on those.
public sealed partial class CityFx
{
    // landmark_burst.gd DUST, Color(DUST, alpha) on the instance: read by the smoke shader as it stands.
    static readonly Color LANDMARK_DUST = new Color(0.62f, 0.61f, 0.58f);
    const float CLOUD_START = 0.8f, CLOUD_SWELL = 0.7f;
    const int CLOUD_POINTS = 8, CLOUD_STOPS = 4;

    BurstStyle landmarkCloud;
    readonly float[] cloudStopAt = new float[CLOUD_STOPS];
    readonly Color[] cloudStops = new Color[CLOUD_STOPS];

    public void LandmarkCloud(Vector3 at, float size, float life, float alpha)
    {
        if (landmarkCloud == null)
        {
            landmarkCloud = new BurstStyle { unit = 1f, selfLit = 0f, clear = 2f };
            var points = new float[CLOUD_POINTS * 2];
            for (int i = 0; i < CLOUD_POINTS; i++)
            {
                float k = i / (CLOUD_POINTS - 1f);
                points[i * 2] = k;
                points[i * 2 + 1] = CLOUD_START + CLOUD_SWELL * k;
            }
            landmarkCloud.Size(points);
        }
        for (int i = 0; i < CLOUD_STOPS; i++)
        {
            float k = i / (CLOUD_STOPS - 1f);
            cloudStopAt[i] = k;
            cloudStops[i] = new Color(LANDMARK_DUST.r, LANDMARK_DUST.g, LANDMARK_DUST.b, alpha * (1f - k * k));
        }
        landmarkCloud.Colors(cloudStopAt, cloudStops);
        landmarkCloud.smin = landmarkCloud.smax = size;
        bursts.Spawn(landmarkCloud, at, Vector3.zero, 1, life, 0f, Now, Seed());
    }
}
