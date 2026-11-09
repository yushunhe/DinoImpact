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
  fern.png           fern decoration
  flower.png         small flower decoration
  pebble.png         small ground detail
  ground_grass.png   tiling grass texture
  ground_path.png    tiling dirt-path texture

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
