using System.Collections.Generic;
using UnityEngine;

namespace SurfImpact
{
    /// <summary>Rides a transform on the analytic wave surface.</summary>
    public class FloatOnWater : MonoBehaviour
    {
        public float heightOffset;
        public bool tilt = true;
        public float tiltAmount = 1f;
        public float yaw;

        void LateUpdate()
        {
            Vector3 p = transform.position;
            float h = WaveMath.Height(p.x, p.z, Time.time);
            p.y = h + heightOffset;
            transform.position = p;
            if (tilt)
            {
                float y = yaw;
                transform.rotation = WaveMath.SurfaceRotation(p.x, p.z, Time.time, y, tiltAmount);
            }
        }
    }

    /// <summary>Spins and bobs the child "visual" of pickups.</summary>
    public class BobSpin : MonoBehaviour
    {
        public float spinSpeed = 120f;
        public float bobAmplitude = .25f;
        public float bobSpeed = 1.6f;
        Vector3 _base;
        float _phase;

        void Awake()
        {
            _base = transform.localPosition;
            _phase = Random.value * 6f;
        }

        void Update()
        {
            transform.localRotation = Quaternion.Euler(0f, Time.time * spinSpeed, 0f);
            Vector3 p = _base;
            p.y = _base.y + Mathf.Sin(Time.time * bobSpeed + _phase) * bobAmplitude;
            transform.localPosition = p;
        }
    }

    /// <summary>Poses the low-poly surfer.</summary>
    public class SurferVisual : MonoBehaviour
    {
        public Transform root;
        public Transform body;
        public Transform armL;
        public Transform armR;
        public Transform board;
        public TrailRenderer trail;
        public GameObject shadow;

        float _lean, _air, _speed = 10f;

        public void SetPose(float turn, float air, float speed)
        {
            _lean = Mathf.Clamp(turn, -1f, 1f);
            _air = Mathf.Clamp01(air);
            _speed = speed;
        }

        public void SetTrail(bool on, Color color, float width, float time)
        {
            if (trail == null) return;
            trail.emitting = on;
            trail.startWidth = width;
            trail.endWidth = .03f;
            trail.time = time;
            var grad = new Gradient();
            grad.SetKeys(
                new[] { new GradientColorKey(color, 0f), new GradientColorKey(Color.Lerp(color, Color.white, .3f), 1f) },
                new[] { new GradientAlphaKey(.6f, 0f), new GradientAlphaKey(0f, 1f) });
            trail.colorGradient = grad;
        }

        void Update()
        {
            float t = Time.time;
            float idle = Mathf.Sin(t * (2.1f + _speed * .06f)) * (0.025f + _speed * .0012f);
            if (body != null)
            {
                body.localRotation = Quaternion.Euler(4f + _air * 10f + idle * 30f, 0f, -_lean * 17f);
                Vector3 bp = body.localPosition;
                bp.y = .14f + idle;
                body.localPosition = bp;
            }
            if (armL != null) armL.localRotation = Quaternion.Euler(-8f + _air * 20f, 0f, 62f + _lean * 22f + idle * 40f);
            if (armR != null) armR.localRotation = Quaternion.Euler(-8f + _air * 20f, 0f, -62f + _lean * 22f - idle * 40f);
            if (board != null) board.localRotation = Quaternion.Euler(0f, 0f, -_lean * 9f);
            UpdateShadow(t);
        }

        void UpdateShadow(float t)
        {
            if (shadow == null || root == null) return;
            Vector3 p = root.position;
            float water = WaveMath.Height(p.x, p.z, t);
            float height = Mathf.Max(0f, p.y - water);
            float scale = Mathf.Clamp(1f - height * .035f, .55f, 1f);
            shadow.transform.position = new Vector3(p.x, water + .07f, p.z);
            shadow.transform.rotation = Quaternion.identity;
            shadow.transform.localScale = new Vector3(2.1f * scale, 1f, 3.6f * scale);
            var r = shadow.GetComponent<MeshRenderer>();
            if (r != null)
            {
                var block = new MaterialPropertyBlock();
                r.GetPropertyBlock(block);
                block.SetColor("_Color", new Color(0f, .05f, .08f, .34f * scale));
                r.SetPropertyBlock(block);
            }
        }
    }

    /// <summary>Animates the kraken's tentacles; aggro comes from Lua.</summary>
    public class KrakenVisual : MonoBehaviour
    {
        public List<Transform> tentacles = new List<Transform>();
        public List<Transform> tentacleTips = new List<Transform>();
        public GameObject shadow;
        public Transform head;
        float _aggro;

        public void SetAggro(float value)
        {
            _aggro = Mathf.Clamp01(value);
        }

        void Update()
        {
            float t = Time.time;
            float speed = 1.3f + _aggro * 2.2f;
            for (int i = 0; i < tentacles.Count; i++)
            {
                var tr = tentacles[i];
                if (tr == null) continue;
                float phase = i * .9f;
                tr.localRotation = Quaternion.Euler(72f + Mathf.Sin(t * speed + phase) * (8f + _aggro * 10f), 0f, 0f);
                var tip = i < tentacleTips.Count ? tentacleTips[i] : null;
                if (tip != null)
                    tip.localRotation = Quaternion.Euler(-28f + Mathf.Sin(t * speed * 1.3f + phase) * 14f, 0f, Mathf.Cos(t * speed + phase) * 8f);
            }
            if (head != null)
                head.localRotation = Quaternion.Euler(0f, 0f, Mathf.Sin(t * 1.7f) * 3f);
            if (shadow != null)
            {
                Vector3 p = transform.position;
                float water = WaveMath.Height(p.x, p.z, t);
                shadow.transform.position = new Vector3(p.x, water + .08f, p.z);
                shadow.transform.rotation = Quaternion.identity;
            }
        }
    }
}
