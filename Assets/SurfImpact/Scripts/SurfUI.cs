using System;
using System.Collections.Generic;
using MoonSharp.Interpreter;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace SurfImpact
{
    /// <summary>
    /// Thin uGUI layer. Lua owns all layout decisions and menu flow; this class
    /// just creates named widgets and lets Lua move text/bars/visibility around.
    /// Positions are normalised (0..1, top-left origin), sizes are 1080p pixels.
    /// </summary>
    public class SurfUI : MonoBehaviour
    {
        class Entry
        {
            public GameObject go;
            public RectTransform rt;
            public Text text;
            public Image image;
            public Image fill;
            public RectTransform fillRt;
            public Button button;
            public DynValue callback;
            public float baseWidth;
            public float baseHeight;
            public string kind;
        }

        readonly Dictionary<string, Entry> _entries = new Dictionary<string, Entry>();
        Script _script;
        Font _font;
        Transform _content;
        Canvas _canvas;
        Image _fade;
        Image _vignette;
        Sprite _rounded;
        public Action<string> OnButtonClick;

        static Sprite _roundedCache;
        static Sprite _vignetteCache;

        public static SurfUI Build(Script script)
        {
            var go = new GameObject("UI");
            var ui = go.AddComponent<SurfUI>();
            ui.Init(script);
            return ui;
        }

        void Init(Script script)
        {
            _script = script;
            _font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if (_font == null) _font = Resources.GetBuiltinResource<Font>("Arial.ttf");

            var canvasGo = new GameObject("Canvas", typeof(RectTransform));
            canvasGo.transform.SetParent(transform, false);
            _canvas = canvasGo.AddComponent<Canvas>();
            _canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            _canvas.sortingOrder = 10;
            var scaler = canvasGo.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1920, 1080);
            scaler.matchWidthOrHeight = .5f;
            canvasGo.AddComponent<GraphicRaycaster>();

            if (FindObjectOfType<EventSystem>() == null)
            {
                var es = new GameObject("EventSystem");
                es.AddComponent<EventSystem>();
                es.AddComponent<StandaloneInputModule>();
            }

            var content = new GameObject("Content", typeof(RectTransform));
            content.transform.SetParent(canvasGo.transform, false);
            var crt = content.GetComponent<RectTransform>();
            crt.anchorMin = Vector2.zero;
            crt.anchorMax = Vector2.one;
            crt.offsetMin = crt.offsetMax = Vector2.zero;
            _content = content.transform;

            if (_roundedCache == null)
                _roundedCache = MakeRoundedSprite(96, 30);
            if (_vignetteCache == null)
                _vignetteCache = MakeVignetteSprite(256);
            _rounded = _roundedCache;

            var vigGo = new GameObject("Vignette", typeof(RectTransform), typeof(Image));
            vigGo.transform.SetParent(canvasGo.transform, false);
            var vrt = vigGo.GetComponent<RectTransform>();
            vrt.anchorMin = Vector2.zero; vrt.anchorMax = Vector2.one;
            vrt.offsetMin = vrt.offsetMax = Vector2.zero;
            _vignette = vigGo.GetComponent<Image>();
            _vignette.sprite = _vignetteCache;
            _vignette.color = new Color(1f, 1f, 1f, .75f);
            _vignette.raycastTarget = false;

            // fade lives on its own canvas so it is always on top
            var fadeCanvasGo = new GameObject("FadeCanvas", typeof(RectTransform));
            fadeCanvasGo.transform.SetParent(transform, false);
            var fc = fadeCanvasGo.AddComponent<Canvas>();
            fc.renderMode = RenderMode.ScreenSpaceOverlay;
            fc.sortingOrder = 100;
            var fadeGo = new GameObject("Fade", typeof(RectTransform), typeof(Image));
            fadeGo.transform.SetParent(fadeCanvasGo.transform, false);
            var frt = fadeGo.GetComponent<RectTransform>();
            frt.anchorMin = Vector2.zero; frt.anchorMax = Vector2.one;
            frt.offsetMin = frt.offsetMax = Vector2.zero;
            _fade = fadeGo.GetComponent<Image>();
            _fade.raycastTarget = false;
            _fade.color = new Color(0f, 0f, 0f, 0f);
        }

        // ------------------------------------------------------------ public API

        public void Label(string name, string text, float x, float y, int size, Color color, string align)
        {
            DestroyEntry(name);
            var go = new GameObject("label_" + name, typeof(RectTransform));
            go.transform.SetParent(_content, false);
            var rt = go.GetComponent<RectTransform>();
            rt.anchorMin = rt.anchorMax = new Vector2(x, 1f - y);
            TextAnchor anchor = TextAnchor.MiddleCenter;
            Vector2 pivot = new Vector2(.5f, .5f);
            if (align == "left") { anchor = TextAnchor.MiddleLeft; pivot = new Vector2(0f, .5f); }
            else if (align == "right") { anchor = TextAnchor.MiddleRight; pivot = new Vector2(1f, .5f); }
            rt.pivot = pivot;
            rt.anchoredPosition = Vector2.zero;
            rt.sizeDelta = new Vector2(1400f, size * 1.5f);

            var label = go.AddComponent<Text>();
            label.font = _font;
            label.text = text;
            label.fontSize = size;
            label.fontStyle = FontStyle.Bold;
            label.alignment = anchor;
            label.color = color;
            label.horizontalOverflow = HorizontalWrapMode.Overflow;
            label.verticalOverflow = VerticalWrapMode.Overflow;
            label.raycastTarget = false;
            label.supportRichText = true;
            var shadow = go.AddComponent<Shadow>();
            shadow.effectColor = new Color(0f, .05f, .1f, .5f);
            shadow.effectDistance = new Vector2(2f, -2f);

            _entries[name] = new Entry { go = go, rt = rt, text = label, kind = "label" };
        }

        public void Panel(string name, float x, float y, float w, float h, Color color)
        {
            DestroyEntry(name);
            var go = new GameObject("panel_" + name, typeof(RectTransform), typeof(Image));
            go.transform.SetParent(_content, false);
            var rt = go.GetComponent<RectTransform>();
            rt.anchorMin = rt.anchorMax = new Vector2(x, 1f - y);
            rt.pivot = new Vector2(.5f, .5f);
            rt.sizeDelta = new Vector2(w, h);
            var img = go.GetComponent<Image>();
            img.sprite = _rounded;
            img.type = Image.Type.Sliced;
            img.color = color;
            var outline = go.AddComponent<Outline>();
            outline.effectColor = new Color(0f, 0f, 0f, .35f);
            outline.effectDistance = new Vector2(2f, -2f);
            _entries[name] = new Entry { go = go, rt = rt, image = img, kind = "panel" };
        }

        public void Button(string name, string text, float x, float y, float w, float h, DynValue callback)
        {
            DestroyEntry(name);
            var go = new GameObject("button_" + name, typeof(RectTransform), typeof(Image), typeof(Button));
            go.transform.SetParent(_content, false);
            var rt = go.GetComponent<RectTransform>();
            rt.anchorMin = rt.anchorMax = new Vector2(x, 1f - y);
            rt.pivot = new Vector2(.5f, .5f);
            rt.sizeDelta = new Vector2(w, h);

            var img = go.GetComponent<Image>();
            img.sprite = _rounded;
            img.type = Image.Type.Sliced;
            img.color = Hex(0x0E2634, .94f);

            var outline = go.AddComponent<Outline>();
            outline.effectColor = new Color(0f, 0f, 0f, .4f);
            outline.effectDistance = new Vector2(2f, -2f);

            var btn = go.GetComponent<Button>();
            btn.targetGraphic = img;
            btn.transition = Selectable.Transition.ColorTint;
            var colors = btn.colors;
            colors.normalColor = Color.white;
            colors.highlightedColor = new Color(.9f, .98f, 1f, 1f);
            colors.pressedColor = new Color(.75f, .85f, .9f, 1f);
            colors.selectedColor = Color.white;
            colors.disabledColor = new Color(.5f, .5f, .5f, .5f);
            btn.colors = colors;
            Entry entry = null;
            btn.onClick.AddListener(() =>
            {
                OnButtonClick?.Invoke(name);
                if (entry != null && entry.callback != null && _script != null)
                {
                    try { _script.Call(entry.callback); }
                    catch (Exception e) { Debug.LogError("[Surf] UI callback error: " + e); }
                }
            });

            var textGo = new GameObject("text", typeof(RectTransform));
            textGo.transform.SetParent(go.transform, false);
            var trt = textGo.GetComponent<RectTransform>();
            trt.anchorMin = Vector2.zero; trt.anchorMax = Vector2.one;
            trt.offsetMin = new Vector2(12, 4); trt.offsetMax = new Vector2(-12, -4);
            var label = textGo.AddComponent<Text>();
            label.font = _font;
            label.text = text;
            label.fontSize = 30;
            label.fontStyle = FontStyle.Bold;
            label.alignment = TextAnchor.MiddleCenter;
            label.color = new Color(.85f, .95f, 1f);
            label.raycastTarget = false;
            label.horizontalOverflow = HorizontalWrapMode.Overflow;
            label.verticalOverflow = VerticalWrapMode.Overflow;

            entry = new Entry
            {
                go = go, rt = rt, image = img, text = label, button = btn,
                callback = callback, baseWidth = w, baseHeight = h, kind = "button",
            };
            _entries[name] = entry;
        }

        public void Bar(string name, float x, float y, float w, float h, Color bg, Color fill)
        {
            DestroyEntry(name);
            var go = new GameObject("bar_" + name, typeof(RectTransform), typeof(Image));
            go.transform.SetParent(_content, false);
            var rt = go.GetComponent<RectTransform>();
            rt.anchorMin = rt.anchorMax = new Vector2(x, 1f - y);
            rt.pivot = new Vector2(.5f, .5f);
            rt.sizeDelta = new Vector2(w, h);
            var img = go.GetComponent<Image>();
            img.sprite = _rounded;
            img.type = Image.Type.Sliced;
            img.color = bg;

            var fillGo = new GameObject("fill", typeof(RectTransform), typeof(Image));
            fillGo.transform.SetParent(go.transform, false);
            var frt = fillGo.GetComponent<RectTransform>();
            frt.anchorMin = new Vector2(0f, 0f);
            frt.anchorMax = new Vector2(0f, 1f);
            frt.pivot = new Vector2(0f, .5f);
            frt.offsetMin = new Vector2(2, 2);
            frt.offsetMax = new Vector2(2 + w - 4, -2);
            var fimg = fillGo.GetComponent<Image>();
            fimg.sprite = _rounded;
            fimg.type = Image.Type.Sliced;
            fimg.color = fill;
            fimg.raycastTarget = false;

            _entries[name] = new Entry
            {
                go = go, rt = rt, image = img, fill = fimg, fillRt = frt,
                baseWidth = w - 4, baseHeight = h, kind = "bar",
            };
        }

        public void SetText(string name, string text)
        {
            if (_entries.TryGetValue(name, out Entry e) && e.text != null && e.text.text != text)
                e.text.text = text;
        }

        public void SetColor(string name, Color color)
        {
            if (_entries.TryGetValue(name, out Entry e))
            {
                if (e.text != null) e.text.color = color;
                else if (e.image != null) e.image.color = color;
            }
        }

        public void SetSize(string name, int size)
        {
            if (_entries.TryGetValue(name, out Entry e) && e.text != null)
            {
                e.text.fontSize = size;
                if (e.rt != null) e.rt.sizeDelta = new Vector2(1400f, size * 1.5f);
            }
        }

        /// <summary>Moves a widget (normalised 0..1, top-left origin).</summary>
        public void SetPos(string name, float x, float y)
        {
            if (_entries.TryGetValue(name, out Entry e) && e.rt != null)
                e.rt.anchorMin = e.rt.anchorMax = new Vector2(x, 1f - y);
        }

        /// <summary>Scales a widget around its pivot (used for pops and pulses).</summary>
        public void SetScale(string name, float sx, float sy)
        {
            if (_entries.TryGetValue(name, out Entry e) && e.rt != null)
                e.rt.localScale = new Vector3(sx, sy, 1f);
        }

        public void Show(string name, bool visible)
        {
            if (_entries.TryGetValue(name, out Entry e)) e.go.SetActive(visible);
        }

        public void SetButtonColors(string name, Color bg, Color textColor)
        {
            if (_entries.TryGetValue(name, out Entry e))
            {
                if (e.image != null) e.image.color = bg;
                if (e.text != null) e.text.color = textColor;
            }
        }

        public void SetButtonSelected(string name, bool selected)
        {
            SetButtonColors(name,
                selected ? Hex(0xFFC24B, .96f) : Hex(0x0E2634, .94f),
                selected ? Hex(0x10222B) : new Color(.85f, .95f, 1f));
        }

        public void SetBar(string name, float fillAmount)
        {
            if (!_entries.TryGetValue(name, out Entry e) || e.fillRt == null) return;
            float w = Mathf.Max(0f, e.baseWidth * Mathf.Clamp01(fillAmount));
            e.fillRt.sizeDelta = new Vector2(w, -4f);
        }

        public void SetFade(float alpha, Color color)
        {
            if (_fade == null) return;
            _fade.color = new Color(color.r, color.g, color.b, Mathf.Clamp01(alpha));
            _fade.enabled = alpha > .001f;
        }

        public void ShowVignette(bool visible)
        {
            if (_vignette != null) _vignette.enabled = visible;
        }

        public void Destroy(string name)
        {
            DestroyEntry(name);
        }

        public void Clear()
        {
            foreach (var e in _entries.Values)
                if (e.go != null) Destroy(e.go);
            _entries.Clear();
        }

        void DestroyEntry(string name)
        {
            if (_entries.TryGetValue(name, out Entry e))
            {
                if (e.go != null) Destroy(e.go);
                _entries.Remove(name);
            }
        }

        public bool Exists(string name) => _entries.ContainsKey(name);

        // ---------------------------------------------------------------- sprites

        static Sprite MakeRoundedSprite(int size, int radius)
        {
            var tex = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                name = "SurfRounded",
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear,
            };
            var px = new Color32[size * size];
            float r = radius;
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float a = 1f;
                    float cx = x < r ? r : (x > size - 1 - r ? size - 1 - r : x);
                    float cy = y < r ? r : (y > size - 1 - r ? size - 1 - r : y);
                    bool corner = (x < r || x > size - 1 - r) && (y < r || y > size - 1 - r);
                    if (corner)
                    {
                        float d = Mathf.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
                        a = Mathf.Clamp01(r - d);
                    }
                    px[y * size + x] = new Color32(255, 255, 255, (byte)(a * 255f));
                }
            }
            tex.SetPixels32(px);
            tex.Apply(false, false);
            // 9-slice border must be smaller than half the texture
            int border = Mathf.Min(radius, size / 3);
            var sprite = Sprite.Create(tex, new Rect(0, 0, size, size), new Vector2(.5f, .5f), 100f, 0,
                SpriteMeshType.FullRect, new Vector4(border, border, border, border));
            sprite.name = "SurfRoundedSprite";
            return sprite;
        }

        static Sprite MakeVignetteSprite(int size)
        {
            var tex = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                name = "SurfVignette",
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear,
            };
            var px = new Color32[size * size];
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float dx = (x + .5f) / size * 2f - 1f;
                    float dy = (y + .5f) / size * 2f - 1f;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    float a = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((d - .45f) / .75f)) * .62f;
                    px[y * size + x] = new Color32(0, 0, 0, (byte)(a * 255f));
                }
            }
            tex.SetPixels32(px);
            tex.Apply(false, false);
            var sprite = Sprite.Create(tex, new Rect(0, 0, size, size), new Vector2(.5f, .5f), 100f);
            sprite.name = "SurfVignetteSprite";
            return sprite;
        }

        public static Color Hex(uint rgb, float a = 1f) => new Color(
            ((rgb >> 16) & 255) / 255f,
            ((rgb >> 8) & 255) / 255f,
            (rgb & 255) / 255f, a);
    }
}
