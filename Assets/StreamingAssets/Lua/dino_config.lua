-- DINO IMPACT - hand-edited tuning table. Entity tables live in dino_data.lua.
-- All the "你来定" parameters from the design doc are collected here.
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
    heart     = "#E05A47",
}

-- 1.2.1 heading: five discrete states. -2 左, -1 微左, 0 中, 1 微右, 2 右.
-- The angle is where the dinosaur keeps running; W snaps back to 0.
C.heading = {
    min = -2,
    max = 2,
    angleDeg = { [-2] = -48, [-1] = -20, [0] = 0, [1] = 20, [2] = 48 },
}

-- 1.2.2 run / life: auto-forward cruise, 3 hearts, invuln after a hit.
C.run = {
    speed0     = 6.0,   -- base cruise speed (units/s)
    rampDist   = 320,   -- +rampStep every N metres ...
    rampStep   = .09,   -- ... until rampMax
    rampMax    = 1.55,
    hpMax      = 3,
    invuln     = .9,    -- minimum invulnerability after losing a heart
    blinkRate  = .09,   -- sprite flicker period while invulnerable
}

-- 1.2.3 archery: max 3 stored arrows, one refills every regen seconds.
C.arrow = {
    max   = 3,
    regen = 1.15,
    speed = 17,
    life  = .55,
    radius = .35,
}

-- 1.2.5 obstacle effect durations / multipliers (all "你来定" values).
C.effects = {
    slowDur   = 2.0,  slowMul  = .55,   -- 草丛 / 脚印坑
    boostDur  = 1.5,  boostMul = 1.75,  -- 泥潭：脚下打滑猛然加速
    confuseDur = 2.5,                   -- 蘑菇丛：A/D 对调
    jumpDur   = .8,                     -- 弹簧草：滞空时间（期间无视一切障碍）
    jumpPush  = 1.45,                   -- 跳板滞空期间的前进 burst 倍率
    reuseCd   = .9,                     -- 同一次效果不重复触发的冷却
}

C.camera = {
    size = 6.2,
    yOffset = 3.1,
    followRate = 9,
    sizeLerp = 3.5,
    zoomRun = .45,
}

C.world = {
    decorCell = 6,
    decorRadius = 5,
    cullX = 22,
    cullBack = 20,     -- behind the player
    cullFore = 55,     -- unused (spawn-ahead limit), kept for clarity
}

C.juice = {
    hitStop = .14,
    shake = .42,
    shakeTime = .4,
    hurtStop = .1,      -- smaller freeze for losing one heart
    hurtShake = .22,
    eggShake = .05,
    eggSound = "coin",
    hurtSound = "crash",
    shootSound = "tick",
    mountSound = "gate",
    skillSound = "boost",
}

-- spawn director
C.spawn = {
    safeStart = 16,
    obstacleGapMin = 10,
    obstacleGapMax = 17,
    eggGapMin = 7,
    eggGapMax = 13,
    ahead = 46,
    eggValue = 25,
    killValue = 60,
    mountValue = 120,
    fruitChance = .14,     -- an egg row becomes a guarded fruit instead
    sleepChance = .10,     -- an obstacle row becomes a sleeping mount dinosaur
    enemyChance = .30,     -- per obstacle row, chance of also spawning an enemy event
    laneHalf = 13,         -- playable corridor: spawns anchor inside it
}

-- player body / animation
C.player = {
    radius = .55,
    animRate = .11,
}

C.sprites = {
    shadow = "shadow",
    rider = "rider",
    arrow = "arrow",
    zzz = "zzz",
    rope = "rope_prompt",
}

return C
