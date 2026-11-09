using UnityEngine;

namespace SurfImpact
{
    /// <summary>Shared materials and runtime texture helpers.</summary>
    public static class SurfMaterials
    {
        public static Material Flat;
        public static Material Unlit;
        public static Material Additive;
        public static Material Trail;
        public static Material BlobShadow;
        public static Material Particle;
        public static Material ParticleAdditive;

        public static Texture2D SoftCircle { get; private set; }

        static bool _ready;

        public static void Init()
        {
            if (_ready) return;
            _ready = true;

            Shader flat = Find("Surf/Flat");
            Shader unlit = Find("Surf/Unlit");
            Shader additive = Find("Surf/Additive");
            Shader particle = Find("Surf/Particle");

            SoftCircle = MakeSoftCircle(64);

            Flat = new Material(flat) { name = "SurfFlat" };
            Flat.SetColor("_Color", Color.white);
            Flat.SetFloat("_Ambient", .5f);
            Flat.SetFloat("_SunBoost", .85f);
            Flat.SetColor("_RimColor", new Color(1f, 1f, 1f, .16f));

            Unlit = new Material(unlit) { name = "SurfUnlit" };
            Unlit.SetColor("_Color", Color.white);
            Unlit.SetTexture("_MainTex", SoftCircle);

            Additive = new Material(additive) { name = "SurfAdditive" };
            Additive.SetColor("_Color", Color.white);
            Additive.SetTexture("_MainTex", Texture2D.whiteTexture);

            Trail = new Material(additive) { name = "SurfTrail" };
            Trail.SetColor("_Color", Color.white);
            Trail.SetTexture("_MainTex", Texture2D.whiteTexture);
            Trail.SetFloat("_Softness", 0f);

            BlobShadow = new Material(unlit) { name = "SurfBlobShadow" };
            BlobShadow.SetColor("_Color", new Color(0f, .05f, .08f, .34f));
            BlobShadow.SetTexture("_MainTex", SoftCircle);
            BlobShadow.renderQueue = 3000;

            Particle = new Material(particle) { name = "SurfParticle" };
            Particle.SetColor("_Color", Color.white);
            Particle.SetTexture("_MainTex", SoftCircle);
            Particle.SetFloat("_SrcBlend", 5f);
            Particle.SetFloat("_DstBlend", 10f);

            ParticleAdditive = new Material(particle) { name = "SurfParticleAdditive" };
            ParticleAdditive.SetColor("_Color", Color.white);
            ParticleAdditive.SetTexture("_MainTex", SoftCircle);
            ParticleAdditive.SetFloat("_SrcBlend", 5f);
            ParticleAdditive.SetFloat("_DstBlend", 1f);
            ParticleAdditive.renderQueue = 3010;
        }

        static Shader Find(string name)
        {
            Shader s = Shader.Find(name);
            if (s == null)
            {
                Debug.LogError("[Surf] Missing shader: " + name + " - falling back to Standard");
                s = Shader.Find("Standard");
            }
            return s;
        }

        public static Texture2D MakeSoftCircle(int size)
        {
            var tex = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                name = "SurfSoftCircle",
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear,
            };
            var px = new Color32[size * size];
            float half = size * .5f;
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float dx = (x + .5f - half) / half;
                    float dy = (y + .5f - half) / half;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    float a = Mathf.Clamp01(1f - d);
                    a = a * a * (3f - 2f * a);
                    a *= 0.92f;
                    px[y * size + x] = new Color32(255, 255, 255, (byte)(a * 255f));
                }
            }
            tex.SetPixels32(px);
            tex.Apply(false, false);
            return tex;
        }

        public static void Tint(GameObject go, Color color, float emission = 0f)
        {
            var renderers = go.GetComponentsInChildren<MeshRenderer>(true);
            var block = new MaterialPropertyBlock();
            Color em = emission <= 0f ? Color.black : new Color(color.r * emission, color.g * emission, color.b * emission, 1f);
            for (int i = 0; i < renderers.Length; i++)
            {
                var r = renderers[i];
                r.GetPropertyBlock(block);
                block.SetColor("_Color", color);
                block.SetColor("_EmissionColor", em);
                r.SetPropertyBlock(block);
            }
        }

        public static void SetColor(MeshRenderer r, Color color, Color emission)
        {
            var block = new MaterialPropertyBlock();
            r.GetPropertyBlock(block);
            block.SetColor("_Color", color);
            block.SetColor("_EmissionColor", emission);
            r.SetPropertyBlock(block);
        }

        public static Color Parse(string hex, Color fallback)
        {
            if (string.IsNullOrEmpty(hex)) return fallback;
            if (!hex.StartsWith("#")) hex = "#" + hex;
            return ColorUtility.TryParseHtmlString(hex, out Color c) ? c : fallback;
        }
    }
}
