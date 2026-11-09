-- DINO IMPACT - small, edited-by-hand tuning table.
local C = {}

C.title = "DINO IMPACT"
C.subtitle = "JURASSIC RUN"

C.colors = {
    ink       = "#091008",
    panel     = "#101C0FEE",
    button    = "#1E321CF0",
    buttonHi  = "#F2C14E",
    accent    = "#F2C14E",
    accent2   = "#9BD65A",
    white     = "#F7F1D8",
    muted     = "#B9AE8C",
    red       = "#E05A47",
    gold      = "#F2C14E",
    darkText  = "#1A2412",
    grass     = "#3B692C",
}

C.player = {
    forwardAccel = 17,
    forwardMax = 6.4,
    brake = 24,
    drag = 9,
    lateralAccel = 34,
    lateralMax = 5.2,
    lateralDrag = 12,
    radius = .55,
    animRate = .11,
    -- no xLimit: the world is endless to the left and right.
}

C.camera = {
    size = 6.2,
    yOffset = 3.1,
    followRate = 9,     -- position smoothing (higher = snappier)
    sizeLerp = 3.5,     -- how fast the zoom catches up
    zoomRun = .45,      -- slight extra zoom-in at full sprint
}

C.world = {
    -- Scenery is generated in deterministic cells (see dino_world.lua), so any
    -- part of the endless plain has the same average density.
    decorCell = 6,      -- cell size in world units
    decorRadius = 5,    -- cells generated around the player (30 units each way)
    cullX = 20,         -- drop track entities further than this from the player's x
}

C.juice = {
    hitStop = .14,      -- gameplay freezes this long on a crash
    shake = .42,        -- crash screen-shake amount
    shakeTime = .4,
    eggShake = .05,
    eggSound = "coin",
}

C.spawn = {
    safeStart = 13,
    obstacleGapMin = 11,
    obstacleGapMax = 18,
    eggGapMin = 7,
    eggGapMax = 13,
    ahead = 40,
    eggValue = 25,
}

C.sprites = {
    playerIdle = "dino_idle",
    playerIdle2 = "dino_idle2",
    playerRun0 = "dino_run0",
    playerRun1 = "dino_run1",
    playerRun2 = "dino_run2",
    playerRun3 = "dino_run3",
    shadow = "shadow",
    egg = "egg",
}

return C
