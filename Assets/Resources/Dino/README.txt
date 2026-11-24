DINO IMPACT - replacement art folder

Put your own PNG sprites here using these exact names. Any file that exists
replaces the generated placeholder at runtime; missing files keep the
placeholder.

  dino_idle.png      player idle frame A, facing up / away from the camera
  dino_idle2.png     player idle frame B (breathing bob)
  dino_run0.png      run frame 0 (left foot forward)
  dino_run1.png      run frame 1 (pass)
  dino_run2.png      run frame 2 (right foot forward)
  dino_run3.png      run frame 3 (pass)
  shadow.png         soft ground shadow under the player
  egg.png            collectible egg
  rock.png           large obstacle
  rock_small.png     small obstacle
  log.png            fallen log obstacle
  bush.png           bush obstacle
  tree.png           large tree decoration
  grove.png          小树林: a dense grove composed from the plant sprites
                     (grove_2.png ~ grove_4.png are further variants)
  fern.png           fern decoration
  flower.png         small flower decoration
  pebble.png         small ground detail
  ground_grass.png   seamless moss, short meadow grass, windswept grass and dry grass
  ground_fern.png    tiling fern-ground texture (terrain patches)
  ground_swamp.png   tiling swamp texture (terrain patches)
  ground_path.png    tiling dirt-path texture

Regenerate the grassland with `python3 tools/art/make_grassland.py` (NumPy and
Pillow). The 1024 px texture repeats every 64 world units. Import it with
16 pixels per unit, Point filtering and Repeat wrapping on both axes.

Current vegetation set
----------------------
The 12 plant sprites (tree, palm, bush, cycad, fern, fern_frond, flower,
clubmoss_small, horsetail, horsetail_cone, crown, crown_small) are generated
from Assets/Art/gemini/*.jpg by (white points are recoloured and over-bright
green foliage is capped so it does not read as white dots in game):

  python tools/art/pixelate_gemini_plants.py

Preview: tools/art/preview/gemini_plants_sheet.png

Check or repair white points without rebuilding every sprite:

  python tools/art/pixelate_gemini_plants.py --check
  python tools/art/pixelate_gemini_plants.py --fix

The 小树林 grove sprites (grove.png plus grove_2.png ~ grove_4.png) are
composed from those 12 sprites in the reference layout: a tall central tree, a
second smaller tree, the yellow palm, cycad rosettes and low ground plants,
with pixel grass clumps along the bottom. The variants are deterministic, so
world placement can pick one at random for variety.

  python tools/art/make_grove.py

Preview: tools/art/preview/grove_preview.png

The impassable landmark field (C.groveField in dino_config.lua) arranges a
3x2 grid of these groves into one large blocked area. Preview of the assembled
field: tools/art/preview/grove_field_preview.png

The dino_* files in this folder are generated white-feathered Ornithomimus
frames with a hide-clad rider and quiver (46x56, Pixels Per Unit 22, pivot at
the feet). Regenerate them with:

  python3 tools/art/make_ornithomimus.py

Import settings: Texture Type = Sprite (2D and UI), Filter Mode = Point (no
filter), Compression = None, Pixels Per Unit around 16-24. The player faces up
and the game re-pivots the player sprite to its feet, so a centered sprite is
fine.

After adding art, open Assets/StreamingAssets/Lua/dino_config.lua if you want
to use different sprite names or sizes.
