using System.Collections.Generic;
using UnityEngine;

namespace DinoImpact
{
    /// <summary>
    /// Runtime pixel-art placeholder art. Drop a sprite with the same name into
    /// Assets/Resources/Dino/ and it replaces the generated version automatically.
    /// </summary>
    public static class DinoPixelArt
    {
        static readonly Dictionary<string, Sprite> Cache = new Dictionary<string, Sprite>();

        public static Sprite Get(string name)
        {
            if (string.IsNullOrEmpty(name)) name = "missing";
            if (Cache.TryGetValue(name, out Sprite cached)) return cached;

            Sprite loaded = Resources.Load<Sprite>("Dino/" + name);
            Sprite sprite = loaded != null ? Repivot(loaded, name) : Build(name);
            Cache[name] = sprite;
            return sprite;
        }

        /// <summary>
        /// Replacement art may be imported with any pivot. Re-wrap it with the
        /// pivot the game expects so dropped-in sprites line up correctly.
        /// </summary>
        static Sprite Repivot(Sprite raw, string name)
        {
            Vector2 pivot = new Vector2(.5f, .5f);
            if (name.StartsWith("dino_")) pivot = new Vector2(.5f, .14f);
            else if (name == "tree" || name == "fern" || name == "bush" ||
                     name == "rock" || name == "rock_small" || name == "log" ||
                     name == "flower" || name == "pebble")
                pivot = new Vector2(.5f, .3f);
            if (raw.pivot == pivot && raw.border == Vector4.zero) return raw;
            var sprite = Sprite.Create(raw.texture, raw.rect, pivot, raw.pixelsPerUnit, 0, SpriteMeshType.FullRect);
            sprite.name = name;
            return sprite;
        }

        static Sprite Build(string name)
        {
            switch (name)
            {
                case "dino_idle": return Dino(0);
                case "dino_run0": return Dino(1);
                case "dino_run1": return Dino(2);
                case "shadow": return Shadow();
                case "egg": return Egg();
                case "rock": return Rock();
                case "rock_small": return Rock(true);
                case "log": return Log();
                case "bush": return Bush();
                case "tree": return Tree();
                case "fern": return Fern();
                case "flower": return Flower();
                case "pebble": return Pebble();
                case "ground_grass": return GroundTile(false);
                case "ground_path": return GroundTile(true);
                default: return Missing();
            }
        }

        // ------------------------------------------------------------- characters

        static Sprite Dino(int frame)
        {
            var c = new Canvas(32, 40);
            Color32 outline = Hex("#19351C");
            Color32 dark = Hex("#326A2B");
            Color32 body = Hex("#4F943A");
            Color32 light = Hex("#79C052");
            Color32 belly = Hex("#B7DF7C");
            Color32 plate = Hex("#F0CF6B");
            Color32 plateDark = Hex("#B78C35");
            Color32 eye = Hex("#F5FFE8");
            Color32 pupil = Hex("#12200F");
            Color32 claw = Hex("#EFE0A2");

            // tail (trails behind, toward the bottom of the screen)
            for (int i = 0; i < 11; i++)
            {
                float t = i / 10f;
                float tx = 14f - t * 12.5f;
                float ty = 11f - t * 8.5f;
                float r = 4.2f * (1f - t) + 1.1f;
                c.Ellipse(tx, ty, r, r, outline);
            }
            for (int i = 0; i < 11; i++)
            {
                float t = i / 10f;
                float tx = 14f - t * 12.5f;
                float ty = 11f - t * 8.5f;
                float r = 3.2f * (1f - t) + .6f;
                c.Ellipse(tx, ty, r, r, body);
            }
            c.Ellipse(5f, 4.5f, 2.2f, 2.2f, light);

            // legs: two frames alternate to fake a run cycle
            int leftLift = frame == 1 ? 2 : 0;
            int rightLift = frame == 2 ? 2 : 0;
            DrawLeg(c, 9, 2 + leftLift, outline, body, light, claw);
            DrawLeg(c, 20, 2 + rightLift, outline, body, light, claw);

            // body
            c.Ellipse(16f, 18f, 10.5f, 11.5f, outline);
            c.Ellipse(16f, 18f, 9.6f, 10.6f, dark);
            c.Ellipse(15.2f, 19f, 7.4f, 8.6f, body);
            c.Ellipse(12.8f, 21.5f, 3.6f, 5.2f, light);
            c.Ellipse(18.5f, 14f, 4.6f, 3.4f, belly);

            // little arms
            c.Ellipse(6.5f, 20f, 3.4f, 2.6f, outline);
            c.Ellipse(6.8f, 20f, 2.7f, 1.9f, body);
            c.Ellipse(25.5f, 20f, 3.4f, 2.6f, outline);
            c.Ellipse(25.2f, 20f, 2.7f, 1.9f, body);
            c.Rect(4, 18, 2, 2, claw);
            c.Rect(26, 18, 2, 2, claw);

            // dorsal plates down the spine
            DrawPlate(c, 16, 23.5f, 4.6f, plate, plateDark, outline);
            DrawPlate(c, 16, 18.5f, 4.0f, plate, plateDark, outline);
            DrawPlate(c, 15, 13.5f, 3.2f, plate, plateDark, outline);

            // neck + head
            c.Ellipse(16f, 27.5f, 5.2f, 6.2f, outline);
            c.Ellipse(16f, 28.2f, 4.4f, 5.3f, body);
            c.Ellipse(16f, 33f, 6.6f, 6.4f, outline);
            c.Ellipse(16f, 33.4f, 5.8f, 5.6f, body);
            c.Ellipse(13.5f, 35f, 2.8f, 2.2f, light);

            // eyes
            c.Ellipse(13.5f, 34.2f, 1.7f, 2.0f, eye);
            c.Ellipse(18.5f, 34.2f, 1.7f, 2.0f, eye);
            c.Ellipse(13.5f, 34.2f, .8f, 1.0f, pupil);
            c.Ellipse(18.5f, 34.2f, .8f, 1.0f, pupil);

            // snout + nostrils + teeth
            c.Ellipse(16f, 37.8f, 4.0f, 1.8f, outline);
            c.Ellipse(16f, 38f, 3.2f, 1.3f, dark);
            c.Rect(13, 37, 1, 1, outline);
            c.Rect(18, 37, 1, 1, outline);
            c.Rect(13, 36, 2, 1, claw);
            c.Rect(17, 36, 2, 1, claw);

            // head frill / tiny horns
            c.Triangle(10.5f, 37f, 7.5f, 39f, 9.5f, 34f, outline);
            c.Triangle(21.5f, 37f, 24.5f, 39f, 22.5f, 34f, outline);
            c.Triangle(10.8f, 37f, 8.5f, 38.4f, 10.2f, 35f, plate);
            c.Triangle(21.2f, 37f, 23.5f, 38.4f, 21.8f, 35f, plate);

            return c.ToSprite(nameof(Dino), 22f, new Vector2(.5f, .14f));
        }

        static void DrawLeg(Canvas c, int x, int y, Color32 outline, Color32 body, Color32 light, Color32 claw)
        {
            c.Rect(x - 1, y - 2, 7, 10, outline);
            c.Rect(x, y - 1, 5, 8, body);
            c.Rect(x, y + 4, 2, 3, light);
            c.Rect(x - 1, y - 3, 7, 2, outline);
            c.Rect(x - 1, y - 2, 3, 1, claw);
            c.Rect(x + 2, y - 2, 3, 1, claw);
        }

        static void DrawPlate(Canvas c, float x, float y, float r, Color32 plate, Color32 dark, Color32 outline)
        {
            c.Triangle(x, y + r, x - r * .8f, y, x + r * .8f, y, outline);
            c.Triangle(x, y - r * .8f, x - r * .8f, y, x + r * .8f, y, outline);
            c.Triangle(x, y + r - 1.2f, x - r * .55f, y, x + r * .55f, y, plate);
            c.Triangle(x, y - r + 1.2f, x - r * .55f, y, x + r * .55f, y, dark);
        }

        // ---------------------------------------------------------------- pickups

        static Sprite Egg()
        {
            var c = new Canvas(16, 20);
            Color32 outline = Hex("#4C3A18");
            Color32 shell = Hex("#FFE9B0");
            Color32 shade = Hex("#E3C47C");
            Color32 spot = Hex("#8E6B2D");
            Color32 shine = Hex("#FFFBE0");
            c.Ellipse(8f, 10f, 6.6f, 8.4f, outline);
            c.Ellipse(8f, 10f, 5.8f, 7.6f, shell);
            c.Ellipse(9.4f, 8.5f, 4.2f, 5.5f, shade);
            c.Ellipse(8f, 11f, 4.8f, 6.4f, shell);
            c.Ellipse(6.2f, 13.2f, 1.5f, 2.3f, shine);
            c.Ellipse(9.5f, 12.5f, 1.0f, 1.3f, spot);
            c.Ellipse(5.6f, 8.2f, .9f, 1.2f, spot);
            c.Ellipse(10.4f, 6.5f, .8f, 1.0f, spot);
            return c.ToSprite(nameof(Egg), 16f, new Vector2(.5f, .5f));
        }

        // -------------------------------------------------------------- obstacles

        static Sprite Rock(bool small = false)
        {
            var c = new Canvas(small ? 18 : 24, small ? 15 : 20);
            Color32 outline = Hex("#2E3234");
            Color32 dark = Hex("#5B6265");
            Color32 mid = Hex("#7E878A");
            Color32 light = Hex("#AAB3B4");
            float cx = c.W * .5f, cy = c.H * .42f;
            c.Ellipse(cx, cy, c.W * .46f, c.H * .40f, outline);
            c.Ellipse(cx, cy, c.W * .40f, c.H * .34f, dark);
            c.Ellipse(cx - c.W * .08f, cy + c.H * .08f, c.W * .30f, c.H * .24f, mid);
            c.Ellipse(cx + c.W * .16f, cy + c.H * .19f, c.W * .14f, c.H * .09f, light);
            c.Line((int)(cx - 5), (int)(cy - 3), (int)(cx + 2), (int)(cy + 4), 1, outline);
            c.Line((int)(cx + 2), (int)(cy + 4), (int)(cx + 6), (int)(cy + 2), 1, outline);
            return c.ToSprite("rock", 18f, new Vector2(.5f, .3f));
        }

        static Sprite Log()
        {
            var c = new Canvas(32, 16);
            Color32 outline = Hex("#2E1D0D");
            Color32 dark = Hex("#5A3A1E");
            Color32 mid = Hex("#805327");
            Color32 light = Hex("#A8743D");
            Color32 ring = Hex("#3E2812");
            c.Ellipse(16f, 8f, 15f, 7f, outline);
            c.Ellipse(16f, 8f, 14f, 6f, mid);
            c.Rect(3, 3, 26, 9, mid);
            c.Rect(3, 9, 26, 3, light);
            c.Rect(3, 3, 26, 2, dark);
            c.Ellipse(28f, 8f, 5f, 5.8f, outline);
            c.Ellipse(28f, 8f, 4f, 4.8f, dark);
            c.Ellipse(28f, 8f, 2.6f, 3.2f, mid);
            c.Ellipse(28f, 8f, 1.2f, 1.6f, ring);
            c.Line(7, 5, 20, 5, 1, dark);
            c.Line(10, 11, 23, 11, 1, light);
            return c.ToSprite("log", 20f, new Vector2(.5f, .3f));
        }

        static Sprite Bush()
        {
            var c = new Canvas(24, 20);
            Color32 outline = Hex("#1C3B1C");
            Color32 dark = Hex("#2F6428");
            Color32 mid = Hex("#4A8A38");
            Color32 light = Hex("#6FB052");
            Color32 berry = Hex("#D9584A");
            c.Ellipse(12f, 8f, 11f, 7f, outline);
            c.Ellipse(7f, 10f, 6f, 6f, outline);
            c.Ellipse(17f, 11f, 6.5f, 6f, outline);
            c.Ellipse(12f, 5f, 7f, 4f, dark);
            c.Ellipse(11f, 9f, 9f, 5.5f, mid);
            c.Ellipse(7f, 11f, 4.6f, 4.4f, light);
            c.Ellipse(16.5f, 12f, 4.2f, 4f, mid);
            c.Ellipse(5f, 8f, 1.4f, 1.4f, berry);
            c.Ellipse(18f, 7f, 1.3f, 1.3f, berry);
            c.Ellipse(12f, 13f, 1.2f, 1.2f, berry);
            return c.ToSprite("bush", 18f, new Vector2(.5f, .3f));
        }

        static Sprite Tree()
        {
            var c = new Canvas(48, 48);
            Color32 outline = Hex("#173318");
            Color32 dark = Hex("#2C5A27");
            Color32 mid = Hex("#477F32");
            Color32 light = Hex("#6DA84A");
            Color32 trim = Hex("#8CC762");
            Color32 trunk = Hex("#5B3B1E");

            // trunk peeking out under the canopy
            c.Rect(21, 3, 7, 14, outline);
            c.Rect(22, 3, 5, 13, trunk);

            // canopy: outlined blob, then lighter layers
            c.Ellipse(24f, 28f, 23f, 20f, outline);
            c.Ellipse(24f, 28f, 21f, 18f, dark);
            c.Ellipse(17f, 31f, 12f, 12f, mid);
            c.Ellipse(31f, 32f, 12f, 12f, mid);
            c.Ellipse(24f, 22f, 14f, 9f, mid);
            c.Ellipse(15f, 32f, 7f, 7f, light);
            c.Ellipse(28f, 35f, 8f, 7f, light);
            c.Ellipse(35f, 29f, 5f, 5f, trim);
            c.Ellipse(13f, 25f, 4f, 4f, trim);
            c.Ellipse(24f, 16f, 5f, 4f, dark);
            return c.ToSprite("tree", 24f, new Vector2(.5f, .3f));
        }

        static Sprite Fern()
        {
            var c = new Canvas(24, 20);
            Color32 outline = Hex("#1D3E1E");
            Color32 dark = Hex("#2F652A");
            Color32 mid = Hex("#4E8C39");
            Color32 light = Hex("#76B352");
            c.Line(12, 1, 12, 12, 2, outline);
            c.Line(12, 2, 12, 12, 1, mid);
            for (int i = 0; i < 4; i++)
            {
                int y = 4 + i * 3;
                c.Line(12, y, 3 - i, y + 6 - i, 1, outline);
                c.Line(12, y, 21 + i, y + 6 - i, 1, outline);
                c.Line(12, y, 4 - i, y + 5 - i, 1, i % 2 == 0 ? mid : dark);
                c.Line(12, y, 20 + i, y + 5 - i, 1, i % 2 == 0 ? mid : dark);
            }
            c.Ellipse(12f, 13f, 2.2f, 2.4f, light);
            c.Ellipse(4f, 12f, 1.5f, 1.5f, light);
            c.Ellipse(20f, 12f, 1.5f, 1.5f, light);
            return c.ToSprite("fern", 18f, new Vector2(.5f, .15f));
        }

        static Sprite Flower()
        {
            var c = new Canvas(10, 10);
            Color32 outline = Hex("#3E2E14");
            Color32 petal = Hex("#F2D05B");
            Color32 heart = Hex("#D96A3C");
            c.Ellipse(5f, 5f, 3f, 3f, outline);
            c.Ellipse(5f, 7f, 2f, 2f, petal);
            c.Ellipse(5f, 3f, 2f, 2f, petal);
            c.Ellipse(3f, 5f, 2f, 2f, petal);
            c.Ellipse(7f, 5f, 2f, 2f, petal);
            c.Ellipse(5f, 5f, 1.2f, 1.2f, heart);
            return c.ToSprite("flower", 12f, new Vector2(.5f, .3f));
        }

        static Sprite Pebble()
        {
            var c = new Canvas(10, 8);
            Color32 outline = Hex("#4A4537");
            Color32 mid = Hex("#827B68");
            Color32 light = Hex("#B1A78F");
            c.Ellipse(5f, 3.5f, 4f, 3f, outline);
            c.Ellipse(5f, 4f, 3.2f, 2.4f, mid);
            c.Ellipse(4f, 5f, 1.4f, 1f, light);
            return c.ToSprite("pebble", 16f, new Vector2(.5f, .4f));
        }

        static Sprite Shadow()
        {
            var c = new Canvas(28, 14);
            Color32 inner = new Color32(12, 28, 12, 105);
            Color32 outer = new Color32(12, 28, 12, 42);
            c.Ellipse(14f, 7f, 13f, 6.2f, outer);
            c.Ellipse(14f, 7f, 11f, 4.8f, inner);
            return c.ToSprite("shadow", 18f, new Vector2(.5f, .5f));
        }

        // ------------------------------------------------------------------ ground

        static Sprite GroundTile(bool path)
        {
            var c = new Canvas(32, 32);
            Color32 baseCol = path ? Hex("#6B5530") : Hex("#3B692C");
            Color32 dark = path ? Hex("#5B4728") : Hex("#315B26");
            Color32 mid = path ? Hex("#7A6238") : Hex("#457732");
            Color32 light = path ? Hex("#8D7444") : Hex("#5A8C3D");

            for (int y = 0; y < 32; y++)
                for (int x = 0; x < 32; x++)
                    c.Set(x, y, baseCol);

            uint seed = path ? 0x9E3779B9u : 0x85EBCA6Bu;
            for (int i = 0; i < 90; i++)
            {
                seed = seed * 1664525u + 1013904223u;
                int x = (int)(seed % 32u);
                seed = seed * 1664525u + 1013904223u;
                int y = (int)(seed % 32u);
                c.Set(x, y, (i % 3 == 0) ? light : dark);
            }

            if (!path)
            {
                for (int i = 0; i < 7; i++)
                {
                    seed = seed * 1664525u + 1013904223u;
                    int x = 2 + (int)(seed % 28u);
                    seed = seed * 1664525u + 1013904223u;
                    int y = 2 + (int)(seed % 28u);
                    c.Rect(x, y, 1, 3, mid);
                    c.Rect(x - 1, y + 1, 1, 1, light);
                    c.Rect(x + 1, y + 2, 1, 1, light);
                }
            }
            else
            {
                for (int i = 0; i < 5; i++)
                {
                    seed = seed * 1664525u + 1013904223u;
                    int x = 3 + (int)(seed % 24u);
                    seed = seed * 1664525u + 1013904223u;
                    int y = 3 + (int)(seed % 24u);
                    c.Ellipse(x, y, 1.8f, 1.3f, path ? Hex("#4E3E23") : Hex("#2B4F22"));
                    c.Ellipse(x - .5f, y + .5f, .9f, .6f, light);
                }
            }

            Sprite s = c.ToSprite(path ? "ground_path" : "ground_grass", 16f, new Vector2(.5f, .5f));
            s.texture.wrapMode = TextureWrapMode.Repeat;
            return s;
        }

        static Sprite Missing()
        {
            var c = new Canvas(16, 16);
            Color32 a = Hex("#FF00FF");
            Color32 b = Hex("#101010");
            for (int y = 0; y < 16; y++)
                for (int x = 0; x < 16; x++)
                    c.Set(x, y, ((x / 4 + y / 4) % 2 == 0) ? a : b);
            return c.ToSprite("missing", 16f, new Vector2(.5f, .5f));
        }

        // ------------------------------------------------------------------ helpers

        static Color32 Hex(string hex)
        {
            ColorUtility.TryParseHtmlString(hex, out Color c);
            return c;
        }

        class Canvas
        {
            public readonly int W;
            public readonly int H;
            readonly Color32[] _px;

            public Canvas(int w, int h)
            {
                W = w;
                H = h;
                _px = new Color32[w * h];
                for (int i = 0; i < _px.Length; i++) _px[i] = new Color32(0, 0, 0, 0);
            }

            public void Set(int x, int y, Color32 c)
            {
                if (x < 0 || y < 0 || x >= W || y >= H) return;
                _px[y * W + x] = c;
            }

            public void Rect(int x, int y, int w, int h, Color32 c)
            {
                for (int yy = y; yy < y + h; yy++)
                    for (int xx = x; xx < x + w; xx++)
                        Set(xx, yy, c);
            }

            public void Ellipse(float cx, float cy, float rx, float ry, Color32 c)
            {
                if (rx <= 0 || ry <= 0) return;
                for (int y = Mathf.FloorToInt(cy - ry); y <= Mathf.CeilToInt(cy + ry); y++)
                {
                    for (int x = Mathf.FloorToInt(cx - rx); x <= Mathf.CeilToInt(cx + rx); x++)
                    {
                        float dx = (x + .5f - cx) / rx;
                        float dy = (y + .5f - cy) / ry;
                        if (dx * dx + dy * dy <= 1f) Set(x, y, c);
                    }
                }
            }

            public void Line(int x0, int y0, int x1, int y1, int thick, Color32 c)
            {
                int dx = Mathf.Abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
                int dy = -Mathf.Abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
                int err = dx + dy;
                while (true)
                {
                    for (int oy = 0; oy < thick; oy++)
                        for (int ox = 0; ox < thick; ox++)
                            Set(x0 + ox - thick / 2, y0 + oy - thick / 2, c);
                    if (x0 == x1 && y0 == y1) break;
                    int e2 = err * 2;
                    if (e2 >= dy) { err += dy; x0 += sx; }
                    if (e2 <= dx) { err += dx; y0 += sy; }
                }
            }

            public void Triangle(float ax, float ay, float bx, float by, float cx, float cy, Color32 col)
            {
                int minX = Mathf.FloorToInt(Mathf.Min(ax, Mathf.Min(bx, cx)));
                int maxX = Mathf.CeilToInt(Mathf.Max(ax, Mathf.Max(bx, cx)));
                int minY = Mathf.FloorToInt(Mathf.Min(ay, Mathf.Min(by, cy)));
                int maxY = Mathf.CeilToInt(Mathf.Max(ay, Mathf.Max(by, cy)));
                float d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
                if (Mathf.Abs(d) < .0001f) return;
                for (int y = minY; y <= maxY; y++)
                {
                    for (int x = minX; x <= maxX; x++)
                    {
                        float px = x + .5f, py = y + .5f;
                        float a = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / d;
                        float b = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / d;
                        float c = 1f - a - b;
                        if (a >= -.05f && b >= -.05f && c >= -.05f) Set(x, y, col);
                    }
                }
            }

            public Sprite ToSprite(string name, float ppu, Vector2 pivot)
            {
                var tex = new Texture2D(W, H, TextureFormat.RGBA32, false)
                {
                    name = "px_" + name,
                    filterMode = FilterMode.Point,
                    wrapMode = TextureWrapMode.Clamp,
                };
                tex.SetPixels32(_px);
                tex.Apply(false, false);
                var sprite = Sprite.Create(tex, new Rect(0, 0, W, H), pivot, ppu, 0, SpriteMeshType.FullRect);
                sprite.name = name;
                return sprite;
            }
        }
    }
}
