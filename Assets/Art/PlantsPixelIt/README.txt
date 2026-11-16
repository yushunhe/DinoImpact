史前植物像素素材（上一版；当前游戏植被由 Assets/Art/gemini 生成）

来源：Assets/Art/8F8C53657EB35ED489FE464A57424287.png
重新切分：python tools/art/make_plants_pixelit.py
生成游戏纹理：python tools/art/pixelate_plants.py
预览：tools/art/preview/plants_pixelit_sheet.png

图像处理：
- 移除抠图外围两圈的浅米色/浅粉色边缘
- 预乘 alpha 后下采样，避免透明背景把白色混回叶缘
- 14 色量化，保持 Point 像素风
- 自动检查外围亮边，当前全部为 rim=0

Unity 导入：
- Texture Type = Sprite
- Filter Mode = Point
- Compression = None
- Pixels Per Unit = 22
- Pivot = Bottom Center (0.5, 0)

运行时世界高度（DinoPixelArt.PlantUnits）：
  tree            6.5
  palm            3.2
  shrub / bush    2.0
  cycad           2.4
  fern            1.8
  fern_frond      1.3
  horsetail       1.8
  horsetail_cone  1.4
  crown           1.3
  crown_small     0.9
  clubmoss/flower 1.2
  clubmoss_small  0.9
