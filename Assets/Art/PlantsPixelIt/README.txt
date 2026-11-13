史前植物参考图切分像素素材

来源：Assets/Art/8F8C53657EB35ED489FE464A57424287.png
生成：python3 tools/art/make_plants_pixelit.py
像素化：tools/pixelit/convert.mjs（Pixel It，scale 50 + 植物调色板）
处理：逐株切分、清除白底与参考图水印、最近色量化、透明背景。

Unity 导入：Texture Type = Sprite，Filter Mode = Point，Compression = None，
Pixels Per Unit = 22，Pivot = Bottom Center (0.5, 0)。
底部为地面接触边；大平原上建议只作装饰，不要给树和灌木加伤害判定。

文件：
  tree.png  156x231
  shrub.png  116x134
  fern.png  82x88
  cycad.png  90x123
  palm.png  46x98
  fern_frond.png  54x69
  horsetail.png  22x76
  horsetail_cone.png  24x124
  crown.png  34x76
  crown_small.png  22x41
  clubmoss.png  23x90
  clubmoss_small.png  24x105

预览：tools/art/preview/plants_pixelit_sheet.png
调色板：tools/pixelit/palettes/plants.json
