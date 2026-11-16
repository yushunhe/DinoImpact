GEMINI 植被素材

来源：Assets/Art/gemini/*.jpg（带棋盘格或黑底的像素风渲染图）
处理：python tools/art/pixelate_gemini_plants.py
输出：Assets/Resources/Dino/*.png
预览：tools/art/preview/gemini_plants_sheet.png

处理流程：
- 去掉棋盘格/黑底，裁到植物外轮廓
- 按 22 PPU 和 DinoPixelArt.PlantUnits 的世界高度归一
- 预乘 alpha 下采样，18 色量化，清除边缘亮/暗灰残留
- 检测所有不透明白色/近白色点，替换为最近的植物绿色
- 绿色植物额外限制叶片高光亮度，避免在深色草地上读成白点
- 保留 Unity .meta 的 Point、无压缩、Bottom Center 轴心设置

白点检测：
  python tools/art/pixelate_gemini_plants.py --check   # 只检测，不改图
  python tools/art/pixelate_gemini_plants.py --fix     # 只修现有 PNG

源图到 sprite 的映射：
  tree.jpg      -> tree
  palm.jpg      -> palm
  shrub.jpg     -> bush
  cycad.jpg     -> cycad
  cycad 上部叶冠 -> fern / fern_frond
  clubmoss.jpg  -> flower / clubmoss_small
  horsetail.jpg -> horsetail / horsetail_cone
  crown.jpg     -> crown / crown_small
  排列组合      -> grove（小树林，python tools/art/make_grove.py）
