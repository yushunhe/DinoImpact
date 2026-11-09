using UnityEngine;

namespace SurfImpact
{
    /// <summary>
    /// Single source of truth for the ocean surface. The CPU version is used by
    /// gameplay (bobbing, floating props) and must stay in sync with SurfWater.shader.
    /// </summary>
    public static class WaveMath
    {
        // x,z = direction, k = wave number, w = amplitude
        public static readonly Vector4[] Waves =
        {
            new Vector4( 0.800f,  0.600f, 2f * Mathf.PI / 30f, 0.50f),
            new Vector4(-0.500f,  0.866f, 2f * Mathf.PI / 19f, 0.28f),
            new Vector4( 0.949f, -0.316f, 2f * Mathf.PI / 42f, 0.34f),
        };

        public static readonly float[] Omega = { 1.10f, 1.65f, 0.72f };

        public const float MaxAmplitude = 1.12f;

        public static float Height(float x, float z, float t)
        {
            float h = 0f;
            for (int i = 0; i < Waves.Length; i++)
            {
                Vector4 w = Waves[i];
                h += w.w * Mathf.Sin((w.x * x + w.y * z) * w.z + t * Omega[i]);
            }
            return h;
        }

        public static void Slope(float x, float z, float t, out float dx, out float dz)
        {
            dx = 0f;
            dz = 0f;
            for (int i = 0; i < Waves.Length; i++)
            {
                Vector4 w = Waves[i];
                float c = w.w * w.z * Mathf.Cos((w.x * x + w.y * z) * w.z + t * Omega[i]);
                dx += c * w.x;
                dz += c * w.y;
            }
        }

        public static Vector3 Normal(float x, float z, float t)
        {
            Slope(x, z, t, out float dx, out float dz);
            return new Vector3(-dx, 1f, -dz).normalized;
        }

        public static Quaternion SurfaceRotation(float x, float z, float t, float yaw, float tilt)
        {
            Slope(x, z, t, out float dx, out float dz);
            float pitch = Mathf.Atan(dz) * Mathf.Rad2Deg * tilt;
            float roll = -Mathf.Atan(dx) * Mathf.Rad2Deg * tilt;
            return Quaternion.Euler(pitch, yaw, roll);
        }
    }
}
