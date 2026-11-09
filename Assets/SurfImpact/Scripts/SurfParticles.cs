using UnityEngine;

namespace SurfImpact
{
    /// <summary>Runtime particle effects: splashes, impacts, sparkles, rain and snow.</summary>
    public class SurfParticles : MonoBehaviour
    {
        ParticleSystem _splash;
        ParticleSystem _impact;
        ParticleSystem _sparkle;
        ParticleSystem _boost;
        ParticleSystem _rain;
        ParticleSystem _snow;
        Transform _weatherRoot;
        Transform _camera;

        public static SurfParticles Build(Transform camera)
        {
            var go = new GameObject("Particles");
            var fx = go.AddComponent<SurfParticles>();
            fx.Init(camera);
            return fx;
        }

        void Init(Transform camera)
        {
            _camera = camera;
            _splash = MakeBurst("Splash", SurfMaterials.Particle, 1.6f, .28f, .7f);
            _impact = MakeBurst("Impact", SurfMaterials.Particle, 2.2f, .35f, .6f);
            _sparkle = MakeBurst("Sparkle", SurfMaterials.ParticleAdditive, .9f, .18f, -.15f);
            _boost = MakeBurst("Boost", SurfMaterials.ParticleAdditive, 1.1f, .22f, -.1f);

            _weatherRoot = new GameObject("Weather").transform;
            _rain = MakeWeather("Rain", true);
            _snow = MakeWeather("Snow", false);
            _rain.transform.SetParent(_weatherRoot, false);
            _snow.transform.SetParent(_weatherRoot, false);
            SetWeather("none");
        }

        ParticleSystem MakeBurst(string name, Material mat, float bytes, float size, float gravity)
        {
            var go = new GameObject(name);
            go.transform.SetParent(transform, false);
            var ps = go.AddComponent<ParticleSystem>();
            ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            var main = ps.main;
            main.loop = false;
            main.playOnAwake = false;
            main.duration = 1f;
            main.startLifetime = new ParticleSystem.MinMaxCurve(.45f, .9f);
            main.startSpeed = 0f;
            main.startSize = new ParticleSystem.MinMaxCurve(size * .6f, size);
            main.startColor = Color.white;
            main.gravityModifier = gravity;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = 300;
            main.stopAction = ParticleSystemStopAction.None;
            var emission = ps.emission;
            emission.enabled = true;
            emission.rateOverTime = 0f;
            var shape = ps.shape;
            shape.enabled = false;
            var renderer = ps.GetComponent<ParticleSystemRenderer>();
            renderer.material = new Material(mat) { name = "FX_" + name };
            renderer.renderMode = ParticleSystemRenderMode.Billboard;
            renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            return ps;
        }

        ParticleSystem MakeWeather(string name, bool rain)
        {
            var go = new GameObject(name);
            var ps = go.AddComponent<ParticleSystem>();
            ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            var main = ps.main;
            main.loop = true;
            main.playOnAwake = false;
            main.duration = 2f;
            main.startLifetime = rain ? new ParticleSystem.MinMaxCurve(1.0f, 1.5f) : new ParticleSystem.MinMaxCurve(6f, 10f);
            main.startSpeed = rain ? 0f : new ParticleSystem.MinMaxCurve(1.4f, 3.2f);
            main.startSize = rain ? new ParticleSystem.MinMaxCurve(.06f, .11f) : new ParticleSystem.MinMaxCurve(.18f, .34f);
            main.startColor = rain ? new Color(.7f, .86f, 1f, .35f) : new Color(1f, 1f, 1f, .8f);
            main.gravityModifier = rain ? 0f : .06f;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = rain ? 2600 : 1400;
            var emission = ps.emission;
            emission.enabled = true;
            emission.rateOverTime = rain ? 750f : 160f;
            var shape = ps.shape;
            shape.enabled = true;
            shape.shapeType = ParticleSystemShapeType.Box;
            shape.scale = new Vector3(70f, 1f, 70f);
            shape.position = Vector3.zero;
            var renderer = ps.GetComponent<ParticleSystemRenderer>();
            renderer.material = new Material(SurfMaterials.Particle) { name = "FX_" + name };
            renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            if (rain)
            {
                var vel = ps.velocityOverLifetime;
                vel.enabled = true;
                vel.space = ParticleSystemSimulationSpace.World;
                vel.y = new ParticleSystem.MinMaxCurve(-48f, -38f);
                vel.x = new ParticleSystem.MinMaxCurve(-2f, 2f);
                renderer.renderMode = ParticleSystemRenderMode.Stretch;
                renderer.velocityScale = .055f;
                renderer.lengthScale = 2.4f;
            }
            else
            {
                var noise = ps.noise;
                noise.enabled = true;
                noise.strength = .45f;
                noise.frequency = .25f;
                noise.scrollSpeed = .12f;
                renderer.renderMode = ParticleSystemRenderMode.Billboard;
            }
            return ps;
        }

        public void SetWeather(string weather)
        {
            bool rain = weather == "rain";
            bool snow = weather == "snow";
            if (_rain != null)
            {
                if (rain) _rain.Play(); else _rain.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            }
            if (_snow != null)
            {
                if (snow) _snow.Play(); else _snow.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            }
        }

        void LateUpdate()
        {
            if (_camera == null || _weatherRoot == null) return;
            Vector3 p = _camera.position;
            Vector3 f = _camera.forward;
            _weatherRoot.position = new Vector3(p.x + f.x * 18f, p.y + 22f, p.z + f.z * 18f);
        }

        void EmitBurst(ParticleSystem ps, int count, Vector3 pos, float size, Color color,
                       float speedMin, float speedMax, float upBias, float spread)
        {
            if (ps == null) return;
            var ep = new ParticleSystem.EmitParams();
            for (int i = 0; i < count; i++)
            {
                Vector3 dir = new Vector3(Random.Range(-spread, spread), Random.Range(.25f, 1f) * upBias, Random.Range(-spread, spread)).normalized;
                ep.position = pos + Random.insideUnitSphere * .35f;
                ep.velocity = dir * Random.Range(speedMin, speedMax);
                ep.startSize = Random.Range(size * .4f, size);
                ep.startLifetime = Random.Range(.35f, .85f);
                ep.startColor = color * Random.Range(.8f, 1f);
                ep.rotation = Random.Range(0f, 360f);
                ep.angularVelocity = Random.Range(-180f, 180f);
                ps.Emit(ep, 1);
            }
        }

        public void Splash(Vector3 pos, float scale = 1f)
        {
            EmitBurst(_splash, (int)(14 * scale) + 6, pos, .32f * scale,
                new Color(.82f, 1f, 1f, .85f), 3.5f, 8.5f, 1.4f, .55f);
        }

        public void Impact(Vector3 pos, float scale = 1f)
        {
            EmitBurst(_impact, (int)(18 * scale) + 8, pos, .4f * scale,
                new Color(1f, .95f, .9f, .9f), 4f, 10f, 1.5f, .8f);
            EmitBurst(_impact, (int)(7 * scale) + 3, pos, .3f * scale,
                new Color(1f, .45f, .35f, .9f), 2f, 5f, 1f, .8f);
        }

        public void Sparkle(Vector3 pos, float scale = 1f)
        {
            EmitBurst(_sparkle, (int)(10 * scale) + 4, pos, .22f * scale,
                new Color(1f, .82f, .25f, 1f), 1.5f, 4.2f, 1.1f, .9f);
        }

        public void Boost(Vector3 pos, float scale = 1f)
        {
            EmitBurst(_boost, (int)(12 * scale) + 5, pos, .3f * scale,
                new Color(.35f, 1f, .9f, 1f), 2f, 5.5f, 1f, 1.1f);
        }

        public void Event(string kind, Vector3 pos, float scale = 1f)
        {
            switch (kind)
            {
                case "splash": Splash(pos, scale); break;
                case "impact": Impact(pos, scale); break;
                case "sparkle": Sparkle(pos, scale); break;
                case "boost": Boost(pos, scale); break;
                default: Splash(pos, scale); break;
            }
        }
    }
}
