using UnityEngine;

namespace DinoImpact
{
    // Edge darkening on the main camera (docs/lighting-plan.md 第 3 步).
    // Strength comes from DinoLighting.Vignette, which Lua sets each frame.
    // With strength 0 the image is copied untouched.
    [RequireComponent(typeof(Camera))]
    public class DinoVignette : MonoBehaviour
    {
        Material _mat;
        bool _missingShader;

        void OnRenderImage(RenderTexture src, RenderTexture dst)
        {
            float strength = DinoLighting.Vignette;
            if (strength <= 0f || _missingShader || !EnsureMaterial())
            {
                Graphics.Blit(src, dst);
                return;
            }
            _mat.SetFloat("_Strength", strength);
            Graphics.Blit(src, dst, _mat);
        }

        bool EnsureMaterial()
        {
            if (_mat != null) return true;
            Shader sh = Shader.Find("Surf/Vignette");
            if (sh == null)
            {
                Debug.LogWarning("[DinoVignette] Surf/Vignette missing, vignette disabled.");
                _missingShader = true;
                return false;
            }
            _mat = new Material(sh) { name = "DinoVignette" };
            return true;
        }

        void OnDestroy()
        {
            if (_mat != null) Destroy(_mat);
        }
    }
}
