using SurfImpact;
using UnityEngine;

namespace DinoImpact
{
    // Global light state (docs/lighting-plan.md 第 1-3 步).
    // The values are decided in Lua (dino_light.lua); this class only pushes
    // them into shader globals, halo sprites and the vignette. Call Init before
    // any sprite is drawn, or the globals stay zero and everything renders black.
    public static class DinoLighting
    {
        // Must match the array length in Surf/Sprite.shader.
        public const int MaxLights = 8;

        static readonly int TintId = Shader.PropertyToID("_DinoTint");
        static readonly int LiftId = Shader.PropertyToID("_DinoLift");
        static readonly int LightPRId = Shader.PropertyToID("_DinoLightPR");   // xy = world pos, z = radius
        static readonly int LightCIId = Shader.PropertyToID("_DinoLightCI");   // rgb = colour, a = intensity
        static readonly int LightCountId = Shader.PropertyToID("_DinoLightCount");

        // Reused every frame to avoid per-frame allocations.
        static readonly Vector4[] _lightPR = new Vector4[MaxLights];
        static readonly Vector4[] _lightCI = new Vector4[MaxLights];

        static Shader _spriteShader;
        static Material _spriteMaterial;
        static SpriteRenderer[] _halos;
        static Sprite _haloSprite;

        // Read by DinoVignette every frame.
        public static float Vignette { get; private set; }

        // Surf/Sprite is in Always Included Shaders (ProjectSettings/GraphicsSettings.asset).
        // Sprites/Default is only a last resort so a missing shader never blanks the screen.
        public static Shader SpriteShader
        {
            get
            {
                if (_spriteShader == null)
                {
                    _spriteShader = Shader.Find("Surf/Sprite");
                    if (_spriteShader == null)
                    {
                        Debug.LogWarning("[DinoLighting] Surf/Sprite missing, tint disabled.");
                        _spriteShader = Shader.Find("Sprites/Default");
                    }
                }
                return _spriteShader;
            }
        }

        // Shared by every SpriteRenderer; the tint is global so one material suffices.
        public static Material SpriteMaterial => _spriteMaterial;

        public static void Init()
        {
            if (_spriteMaterial != null) return;
            _spriteMaterial = new Material(SpriteShader) { name = "DinoSprite" };
            Apply(Color.white, Color.black, 0f);
            CommitLights(0, 0f, 0f);
        }

        // Ground and terrain patches need their own tiling/offset, so they get
        // their own material on the same shader.
        public static Material NewSpriteMaterial(string name)
        {
            return new Material(SpriteShader) { name = name };
        }

        public static void Apply(Color tint, Color lift, float vignette)
        {
            Shader.SetGlobalColor(TintId, tint);
            Shader.SetGlobalColor(LiftId, lift);
            Vignette = vignette;
        }

        // Fill slot i of the light buffer; call CommitLights once per frame after all slots.
        public static void SetLight(int i, float x, float y, float radius, Color colour, float intensity)
        {
            _lightPR[i] = new Vector4(x, y, radius, 0f);
            _lightCI[i] = new Vector4(colour.r, colour.g, colour.b, intensity);
        }

        // Pushes the light buffer to the shader and moves the halo sprites.
        // haloAlpha scales each light's intensity into halo opacity;
        // haloScale is the halo diameter as a multiple of the light radius.
        public static void CommitLights(int count, float haloAlpha, float haloScale)
        {
            count = Mathf.Clamp(count, 0, MaxLights);
            Shader.SetGlobalVectorArray(LightPRId, _lightPR);
            Shader.SetGlobalVectorArray(LightCIId, _lightCI);
            Shader.SetGlobalFloat(LightCountId, count);
            UpdateHalos(count, haloAlpha, haloScale);
        }

        // ------------------------------------------------------------ halos

        // Soft additive discs at each light position. They sit above the sprites
        // but below the HUD (the HUD is a separate canvas).
        static void UpdateHalos(int count, float haloAlpha, float haloScale)
        {
            EnsureHalos();
            if (_halos == null) return;
            for (int k = 0; k < MaxLights; k++)
            {
                SpriteRenderer sr = _halos[k];
                if (sr == null) continue;
                if (k >= count || haloAlpha <= 0f)
                {
                    sr.enabled = false;
                    continue;
                }
                Vector4 pr = _lightPR[k];
                Vector4 ci = _lightCI[k];
                sr.enabled = true;
                sr.transform.position = new Vector3(pr.x, pr.y, -0.5f);
                float d = pr.z * haloScale;
                sr.transform.localScale = new Vector3(d, d, 1f);
                sr.color = new Color(ci.x, ci.y, ci.z, Mathf.Clamp01(ci.w * haloAlpha));
            }
        }

        static void EnsureHalos()
        {
            if (_halos != null) return;
            Texture2D tex = SurfMaterials.SoftCircle;
            if (tex == null) return;   // SurfMaterials.Init has not run yet
            _haloSprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height),
                new Vector2(.5f, .5f), tex.width);   // 1 unit across at scale 1
            _halos = new SpriteRenderer[MaxLights];
            for (int k = 0; k < MaxLights; k++)
            {
                var go = new GameObject("DinoLightHalo_" + k);
                var sr = go.AddComponent<SpriteRenderer>();
                sr.sprite = _haloSprite;
                sr.sharedMaterial = SurfMaterials.Additive;
                sr.sortingOrder = 10000;
                sr.enabled = false;
                _halos[k] = sr;
            }
        }
    }
}
