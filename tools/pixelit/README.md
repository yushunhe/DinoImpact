# Pixel It 本地封装

[Pixel It](https://github.com/giventofly/pixelit) 是一个浏览器端 JS 像素化库。
`pixelit.js` 直接取自上游 `dist/pixelit.js`（MIT，作者 José Moreira，见 `LICENSE`）。

因为上游依赖 `<canvas>`，本目录用无头 Chromium 包了一层命令行工具，
不打开 Unity 也能批量把图片转成像素风。

## 依赖

- Node.js（本项目已验证 v26）
- Chromium：默认调用 `chromium`，也可用 `CHROME=/path/to/chrome` 覆盖

## 用法

```bash
# 基础：像素块大小 8，输出保持输入分辨率
node tools/pixelit/convert.mjs input.png output.png --scale 8

# 转成真正的低分辨率小图（最近邻缩小，适合直接做 Unity 精灵）
node tools/pixelit/convert.mjs input.png output.png --scale 8 --out-width 64

# 套用调色板（JSON：[[r,g,b], ...]），并做最近色吸附
node tools/pixelit/convert.mjs input.png output.png --palette my_palette.json --palette-convert

# 灰度
node tools/pixelit/convert.mjs input.png output.png --grayscale
```

参数：

| 参数 | 说明 |
|--|--|
| `--scale N` | 像素块大小，1..50，默认 8 |
| `--palette FILE` | 调色板 JSON，格式 `[[26,28,44],[93,39,93],...]` |
| `--palette-convert` | 像素化后把每个像素吸附到调色板最近色 |
| `--grayscale` | 像素化后转灰度 |
| `--max-width N` / `--max-height N` | 交给 Pixel It 在像素化前缩放（会先平滑，通常不如 `--out-*` 锐利） |
| `--out-width N` / `--out-height N` | 输出阶段用最近邻缩放到指定尺寸（保持比例，适合做小精灵） |

## 输出尺寸提示

Pixel It 的 `pixelate()` 输出画布与输入图同尺寸，只是画面由大色块组成。
做游戏精灵时通常要两步：

1. 输入图尺寸取「目标尺寸 × scale」（例如目标 64px、scale 8 → 输入约 512px）；
2. 加 `--out-width 64`，用最近邻缩回目标尺寸，得到硬边像素图。

`scale` 在输入任一边超过 900px 时会被 Pixel It 自动减半，选参数时留意。

## 生成过的测试

本目录在 2026-11-13 用下面两张现有素材做了验证：

```bash
node tools/pixelit/convert.mjs \
  'Assets/Art/4DBAFC3B68BAE161512E236CA8AE7F53.png' \
  /tmp/opencode/pixelit_dino_test.png --scale 8

node tools/pixelit/convert.mjs \
  'Assets/Art/8F8C53657EB35ED489FE464A57424287.png' \
  /tmp/opencode/pixelit_plants_test.png --scale 8 --palette-convert
```

儿童画恐龙的 62×50 输出见 `preview/`：

- `preview/dino_sketch_62px.png`：未套调色板
- `preview/dino_sketch_62px_palette.png`：套用绿系恐龙调色板

后者的完整命令：

```bash
node tools/pixelit/convert.mjs \
  'Assets/Art/4DBAFC3B68BAE161512E236CA8AE7F53.png' \
  tools/pixelit/preview/dino_sketch_62px_palette.png \
  --scale 8 --palette tools/pixelit/palettes/dinoimpact.json \
  --palette-convert --out-width 62
```

`palettes/dinoimpact.json` 取自 `DinoPixelArt.cs` 里的恐龙绿/蛋黄色。

## Unity 导入建议

- Texture Type：`Sprite (2D and UI)`
- Filter Mode：`Point (no filter)`
- Compression：`None`
- 关闭 Mip Maps（或按需）
- Pixels Per Unit 与现有素材保持一致
