-- DINO IMPACT - static entity tables from the design doc (1.2.4 ~ 1.2.7).
-- Behaviour parameters live here, timing/tuning lives in dino_config.lua.
local D = {}

-- ---------------------------------------------------------------- obstacles
-- class: block   阻拦型（撞掉 1 心）
--        slow / boost / turn / confuse / jump  效果型（1.2.5 (2)~(6)）
-- low:  "矮，可被跳过" — only meaningful while airborne (jump pad / skills),
--       which ignores everything anyway; kept for future jump input.

D.obstacles = {
    rock_small  = { sprite = "rock_small",  radius = .62, class = "block", low = true  },
    rock        = { sprite = "rock",        radius = .85, class = "block", low = false },
    log_h       = { sprite = "log",         radius = .95, class = "block", low = true  },
    log_v       = { sprite = "log",         radius = .95, class = "block", low = false, rotZ = 90 },
    tree        = { sprite = "tree",        radius = .8,  class = "block", low = false },
    grass_tuft  = { sprite = "grass_tuft",  radius = .7,  class = "slow",  low = true  },
    footprint   = { sprite = "footprint",   radius = .75, class = "slow",  low = true  },
    mud         = { sprite = "mud",         radius = .85, class = "boost", low = true  },
    bush        = { sprite = "bush",        radius = .72, class = "turn",  low = true  },
    mushroom    = { sprite = "mushroom",    radius = .7,  class = "confuse", low = true },
    spring      = { sprite = "spring",      radius = .7,  class = "jump",  low = true  },
}

-- weighted pick for ordinary obstacle rows (1.2.5)
D.obstacleWeights = {
    { "rock_small", 22 }, { "rock", 14 }, { "log_h", 12 }, { "log_v", 8 },
    { "tree", 10 }, { "grass_tuft", 12 }, { "footprint", 8 }, { "mud", 8 },
    { "bush", 10 }, { "mushroom", 7 }, { "spring", 6 },
}

-- ---------------------------------------------------------------- items
D.items = {
    egg           = { sprite = "egg",           radius = .55 },
    fruit_energy  = { sprite = "fruit_energy",  radius = .6 },
    fruit_life    = { sprite = "fruit_life",    radius = .6 },
}

-- ---------------------------------------------------------------- enemies
-- def: arrows needed (0 = cannot be shot).  contact: how it hurts the player.
D.enemies = {
    comps = {
        label = "GALLIMIMUS", sprite = "enemy_comps", radius = .55, def = 1,
        contact = "hit",
        patterns = { "strafe", "wall" },
    },
    trike = {
        label = "TRICERATOPS", sprite = "enemy_trike", radius = .8, def = 2,
        contact = "hit",
        patterns = { "charge", "pack" },
    },
    trex = {
        label = "T-REX", sprite = "enemy_trex", radius = 1.3, def = 0,
        contact = "lethal",
        dwell = 12,        -- gives up after this many seconds
        rampTime = 4,      -- reaches "too fast to ignore" after this
    },
    para = {
        label = "PARASAUROLOPHUS", sprite = "enemy_para", radius = .85, def = 2,
        contact = "hit",
        babies = { sprite = "enemy_para_baby", radius = .45, def = 1 },
        scatterR = 2.6,
    },
    ankylo = {
        label = "ANKYLOSAURUS", sprite = "enemy_ankylo", radius = .85, def = 3,
        contact = "hit",
        lead = { 4, 7 },   -- stays this far ahead of the player once it overtakes
    },
    dein = {
        label = "DEINONYCHUS", sprite = "enemy_dein", radius = .65, def = 1,
        contact = "hit",
        featherDmg = "hit",
    },
    sauropod = {
        label = "SAUROPOD", sprite = "enemy_sauropod", radius = 1.2, def = 0,
        contact = "lethal",
        crosses = true,
    },
    ptero = {
        label = "PTERANODON", sprite = "enemy_ptero", radius = .5, def = 0,
        contact = "hit",   -- the poop hurts, the bird itself flies overhead
        crosses = true,
    },
}

-- one spawn entry per weighted enemy event (1.2.6)
D.enemyWeights = {
    { "comps", 24 }, { "trike", 20 }, { "dein", 16 }, { "ankylo", 12 },
    { "para", 12 }, { "trex", 8 }, { "sauropod", 5 }, { "ptero", 5 },
}

-- ---------------------------------------------------------------- mounts
-- 1.2.7: sleeping dinosaurs you can swap into with J; Space fires the skill.
-- uses: energy-fruit / re-mount resets this counter (para = chick count).
D.mounts = {
    comps = {
        label = "COMPSOGNATHUS", speedMul = 1.00, uses = 1,
        active = "boost",  passive = nil,
        run = { "mount_comps_run0", "mount_comps_run1" },
        idle = "mount_comps_run0", sleep = "mount_comps_sleep",
        boostMul = 2.2, boostDur = 1.0,
    },
    trike = {
        label = "TRICERATOPS", speedMul = .92, uses = 1,
        active = "charge", passive = nil,
        run = { "mount_trike_run0", "mount_trike_run1" },
        idle = "mount_trike_run0", sleep = "mount_trike_sleep",
        chargeDur = 2.2,
    },
    ankylo = {
        label = "ANKYLOSAURUS", speedMul = .88, uses = 1,
        active = "charge", passive = nil,
        run = { "mount_ankylo_run0", "mount_ankylo_run1" },
        idle = "mount_ankylo_run0", sleep = "mount_ankylo_sleep",
        chargeDur = 2.2,
    },
    trex = {
        label = "T-REX HATCHLING", speedMul = 1.00, uses = 10,
        active = "jump", passive = "devour",
        run = { "mount_trex_run0", "mount_trex_run1" },
        idle = "mount_trex_run0", sleep = "mount_trex_sleep",
        jumpDur = .7, devourR = 1.7,
    },
    dein = {
        label = "DEINONYCHUS", speedMul = 1.08, uses = 10,
        active = "jump", passive = "fan",
        run = { "mount_dein_run0", "mount_dein_run1" },
        idle = "mount_dein_run0", sleep = "mount_dein_sleep",
        jumpDur = .7, fanCd = 2.0, fanR = 6,
    },
    para = {
        label = "PARASAUROLOPHUS", speedMul = .95, uses = 2,   -- 2 崽
        active = nil, passive = "shield",
        run = { "mount_para_run0", "mount_para_run1" },
        idle = "mount_para_run0", sleep = "mount_para_sleep",
    },
    pter = {
        label = "PTERANODON", speedMul = 1.05, uses = 1,
        active = "fly", passive = nil,
        run = { "mount_pter_run0", "mount_pter_run1" },
        idle = "mount_pter_run0", sleep = "mount_pter_sleep",
        flyDur = 2.5,
    },
}

D.mountOrder = { "comps", "trike", "ankylo", "trex", "dein", "para", "pter" }

return D
