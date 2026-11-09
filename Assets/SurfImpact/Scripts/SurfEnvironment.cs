using UnityEngine;

namespace SurfImpact
{
    /// <summary>
    /// Owns the skybox, sun, fog, ambient light and ocean look. Lua drives the
    /// clock and the weather; all the lerping happens here.
    /// </summary>
    public class SurfEnvironment
    {
        public Camera Camera { get; private set; }
        public SurfOcean Ocean { get; private set; }
        public SurfParticles Fx { get; private set; }

        Light _sun;
        Material _sky;
        float _timeOfDay = .16f;
        string _weather = "none";

        struct Palette
        {
            public Color top, horizon, bottom, sun, light, ambient, deep, shallow, foam;
            public float intensity, stars, fog;
        }

        static Color Hex(uint rgb) => new Color(
            ((rgb >> 16) & 255) / 255f,
            ((rgb >> 8) & 255) / 255f,
            (rgb & 255) / 255f, 1f);

        static readonly Palette[] Keys =
        {
            // dawn
            new Palette
            {
                top = Hex(0x3D6D9E), horizon = Hex(0xFFC08A), bottom = Hex(0x1F3350),
                sun = Hex(0xFFD9A0), light = Hex(0xFFC9A0), ambient = Hex(0x7A8FB0),
                deep = Hex(0x0D4A5E), shallow = Hex(0x2FA8A8), foam = Hex(0xFFEEDD),
                intensity = .55f, stars = .18f, fog = .0048f,
            },
            // day
            new Palette
            {
                top = Hex(0x3F97DC), horizon = Hex(0xB8E6F6), bottom = Hex(0x276B98),
                sun = Hex(0xFFF3CF), light = Hex(0xFFF1D0), ambient = Hex(0xA9C8DD),
                deep = Hex(0x075A74), shallow = Hex(0x38C9C2), foam = Hex(0xEAFFFF),
                intensity = 1.05f, stars = 0f, fog = .0032f,
            },
            // dusk
            new Palette
            {
                top = Hex(0x5D4A95), horizon = Hex(0xFF9A6A), bottom = Hex(0x241F45),
                sun = Hex(0xFFB36B), light = Hex(0xFF9A70), ambient = Hex(0x8A7AA8),
                deep = Hex(0x2A3358), shallow = Hex(0xC77A86), foam = Hex(0xFFE0CF),
                intensity = .55f, stars = .3f, fog = .0048f,
            },
            // night
            new Palette
            {
                top = Hex(0x050D1E), horizon = Hex(0x0E2740), bottom = Hex(0x030610),
                sun = Hex(0xB9D4FF), light = Hex(0x8FB6FF), ambient = Hex(0x314A70),
                deep = Hex(0x04182A), shallow = Hex(0x1E5773), foam = Hex(0xBFE3FF),
                intensity = .22f, stars = 1f, fog = .0062f,
            },
        };

        static Palette Lerp(Palette a, Palette b, float t)
        {
            return new Palette
            {
                top = Color.Lerp(a.top, b.top, t),
                horizon = Color.Lerp(a.horizon, b.horizon, t),
                bottom = Color.Lerp(a.bottom, b.bottom, t),
                sun = Color.Lerp(a.sun, b.sun, t),
                light = Color.Lerp(a.light, b.light, t),
                ambient = Color.Lerp(a.ambient, b.ambient, t),
                deep = Color.Lerp(a.deep, b.deep, t),
                shallow = Color.Lerp(a.shallow, b.shallow, t),
                foam = Color.Lerp(a.foam, b.foam, t),
                intensity = Mathf.Lerp(a.intensity, b.intensity, t),
                stars = Mathf.Lerp(a.stars, b.stars, t),
                fog = Mathf.Lerp(a.fog, b.fog, t),
            };
        }

        static Palette Sample(float t)
        {
            t = Mathf.Repeat(t, 1f) * Keys.Length;
            int i = Mathf.FloorToInt(t);
            float f = t - i;
            Palette a = Keys[i % Keys.Length];
            Palette b = Keys[(i + 1) % Keys.Length];
            return Lerp(a, b, f);
        }

        public void Build(Camera camera)
        {
            Camera = camera;

            var sunGo = new GameObject("Sun");
            _sun = sunGo.AddComponent<Light>();
            _sun.type = LightType.Directional;
            _sun.shadows = LightShadows.None;
            _sun.renderMode = LightRenderMode.ForcePixel;
            RenderSettings.sun = _sun;

            Shader skyShader = Shader.Find("Surf/Skybox");
            if (skyShader == null)
            {
                Debug.LogError("[Surf] Missing shader Surf/Skybox");
                skyShader = Shader.Find("Skybox/Procedural");
            }
            _sky = new Material(skyShader) { name = "SurfSky" };
            RenderSettings.skybox = _sky;
            camera.clearFlags = CameraClearFlags.Skybox;

            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;

            QualitySettings.shadows = ShadowQuality.Disable;
            QualitySettings.antiAliasing = 4;
            QualitySettings.vSyncCount = 0;

            Ocean = SurfOcean.Build();
            Fx = SurfParticles.Build(camera.transform);
            Apply();
        }

        public void SetTimeOfDay(float t)
        {
            _timeOfDay = Mathf.Repeat(t, 1f);
            Apply();
        }

        public float TimeOfDay => _timeOfDay;

        public void SetWeather(string weather)
        {
            _weather = string.IsNullOrEmpty(weather) ? "none" : weather;
            if (Fx != null) Fx.SetWeather(_weather);
            Apply();
        }

        public string Weather => _weather;

        void Apply()
        {
            if (_sun == null || _sky == null) return;

            Palette p = Sample(_timeOfDay);

            // weather grading
            if (_weather == "rain")
            {
                Color gray = Hex(0x7B8C9A);
                p.top = Color.Lerp(p.top, gray, .45f);
                p.horizon = Color.Lerp(p.horizon, gray, .5f);
                p.bottom = Color.Lerp(p.bottom, gray, .4f);
                p.deep = Color.Lerp(p.deep, Hex(0x1B3B4A), .55f);
                p.shallow = Color.Lerp(p.shallow, Hex(0x3D6B78), .55f);
                p.ambient = Color.Lerp(p.ambient, gray, .35f);
                p.intensity *= .45f;
                p.stars *= .15f;
                p.fog += .0025f;
            }
            else if (_weather == "snow")
            {
                Color white = Hex(0xDCE9F2);
                p.top = Color.Lerp(p.top, white, .3f);
                p.horizon = Color.Lerp(p.horizon, white, .45f);
                p.ambient = Color.Lerp(p.ambient, white, .25f);
                p.intensity *= .65f;
                p.stars *= .2f;
                p.fog += .0022f;
            }

            float azimuth = -60f + _timeOfDay * 360f;
            float elevation = .35f + .65f * Mathf.Clamp01(Mathf.Sin(_timeOfDay * Mathf.PI * 2f));
            _sun.transform.rotation = Quaternion.Euler(15f + elevation * 70f, azimuth, 0f);
            _sun.color = p.light;
            _sun.intensity = p.intensity;

            Vector3 sunDir = -(_sun.transform.rotation * Vector3.forward);

            _sky.SetColor("_TopColor", p.top);
            _sky.SetColor("_HorizonColor", p.horizon);
            _sky.SetColor("_BottomColor", p.bottom);
            _sky.SetColor("_SunColor", p.sun);
            _sky.SetVector("_SunDir", sunDir);
            _sky.SetFloat("_StarAmount", p.stars);
            _sky.SetFloat("_SunIntensity", p.intensity);

            RenderSettings.fogColor = p.horizon;
            RenderSettings.fogDensity = p.fog;
            RenderSettings.ambientLight = p.ambient;

            if (Ocean != null)
                Ocean.SetLook(p.deep, p.shallow, p.foam, p.horizon, sunDir, p.sun, p.intensity);
        }
    }
}
