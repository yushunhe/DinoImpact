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
  rider.png         rider at rest with a full quiver
  rider_idle_*.png  rider at rest with 0–2 arrows
  rider_shoot_*.png rider releasing the bow with 0–3 arrows in the quiver
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
  terrain_fern_0.png ... terrain_fern_3.png    four fern beds on transparent ground
  terrain_swamp_0.png ... terrain_swamp_3.png  four marsh pools with painted shorelines
  ground_fern.png    fallback tile for missing fern bed variants
  ground_swamp.png   fallback tile for missing marsh pool variants
  ground_path.png    tiling dirt-path texture

Regenerate the grassland with `python3 tools/art/make_grassland.py` (NumPy and
Pillow). The 1024 px texture repeats every 64 world units. Import it with
16 pixels per unit, Point filtering and Repeat wrapping on both axes.

Regenerate the aligned 40×48 px rider sprites with `python3 tools/art/make_rider.py`
(Pillow). It cuts both poses from `tools/art/rider-poses.png`, the pixel-art
adaptation of the artist's rider, and adds the visible arrows for each count.
Import at 32 pixels per unit with Point filtering and a saddle pivot at (0.5, 0.34).

Current vegetation set
----------------------
Rebuild the current plant sprites, fern beds, and grove compositions with
`python3 tools/art/make_vegetation.py` (Pillow). The transparent source atlases
are under `tools/art/`, named canopy-atlas.png, understory-atlas.png, and
fern-atlas.png. The tree fern uses its own tree-fern.png in the same folder.
The export uses one foliage palette, with separate accent
colors for bark, cones and clubmoss. Upright sprites retain their existing
world heights and bottom-center pivots.

Preview: tools/art/preview/gemini_plants_sheet.png

Check for white speckles with `python3 tools/art/pixelate_gemini_plants.py --check`.

The 小树林 grove sprites (grove.png plus grove_2.png ~ grove_4.png) are
composed from the same plants. The four silhouettes are a tall canopy with
an understory, a pair of overlapping trees, a low fan-palm edge and a
fern-covered young stand. Rebuild the sprites and their contact sheet with:

  python tools/art/make_grove.py

Sprite sheet: tools/art/preview/grove_preview.png
In-game landmark: tools/art/preview/grove_field_preview.png

C.groveField.layouts arranges the crowns into connected, asymmetric woods.
On the surrounding plain, dino_world.lua groups plants by habitat along the
edges of fern beds and swamp patches and leaves gaps between meadow clusters.

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
