史前植物像素素材（原创）

造型参考侏罗纪植物图鉴，像素是重新画的，不是临摹、也不是缩小原图。
风格和玩家恐龙一致：扁平色块、一像素描边、硬边、无抗锯齿。

地面接触点在图片底边中心。另一个 AI 接进游戏时：
  Texture Type = Sprite
  Filter Mode = Point
  Compression = None
  Pixels Per Unit = 22（和 dino_*.png 同一像素密度）
  Pivot = Bottom Center (0.5, 0)

建议对应：
  tree.png       -> Resources/Dino/tree.png
  shrub.png      -> Resources/Dino/bush.png
  fern.png       -> Resources/Dino/fern.png
  clubmoss.png   -> Resources/Dino/flower.png   （小装饰，可选）
  其余是新植被，大平原上当装饰撒，不要当障碍，否则树会变成伤害判定。

文件：
  tree.png  80x128  树蕨，卷曲嫩芽和板根。可替换 tree
  palm.png  50x95  扇叶树。新装饰
  cycad.png  68x66  放射叶苏铁。新装饰
  fern.png  44x41  缺刻阔叶蕨丛。可替换 fern
  fern_frond.png  40x53  单片羽状蕨叶。新装饰
  horsetail.png  10x38  轮叶节茎。新装饰
  horsetail_cone.png  10x44  带橙色孢子囊的节茎。新装饰
  crown.png  22x44  黄冠鳞叶植物。新装饰
  crown_small.png  14x28  小号黄冠。新装饰
  clubmoss.png  18x35  紫穗石松。可替换 flower
  clubmoss_small.png  18x28  小号石松。新装饰
  shrub.png  60x52  复叶灌木。可替换 bush

重新生成： python3 tools/art/make_plants.py
