-- DINO IMPACT - static entity tables from the design doc (1.2.4 ~ 1.2.7).
-- Behaviour parameters live here, timing/tuning lives in dino_config.lua.
local D = {}

-- ---------------------------------------------------------------- obstacles
-- class: block   阻拦型（撞掉 1 心）
--        slow / boost / turn / confuse / jump  效果型（1.2.5 (2)~(6)）
-- low:  "矮，可被跳过" — only meaningful while airborne (jump pad / skills),
--       which ignores everything anyway; kept for future jump input.

-- 1113 反馈：占地全面放大（"树撞上去不扣血"= 判定圈小于视觉；效果类
-- 障碍"占地都太小"→ 放大，反正不掉血，鼓励大面积吃到）
D.obstacles = {
    rock_small  = { sprite = "rock_small",  radius = .8,  class = "block", low = true  },
    rock        = { sprite = "rock",        radius = 1.1, class = "block", low = false },
    log_h       = { sprite = "log",         radius = 1.3, class = "block", low = true  },
    log_v       = { sprite = "log",         radius = 1.3, class = "block", low = false, rotZ = 90 },
    tree        = { sprite = "tree",        radius = 1.4, class = "block", low = false },
    grass_tuft  = { sprite = "grass_tuft",  radius = 1.5, class = "slow",  low = true  },
    footprint   = { sprite = "footprint",   radius = 1.6, class = "slow",  low = true  },
    mud         = { sprite = "mud",         radius = 1.7, class = "boost", low = true  },
    bush        = { sprite = "bush",        radius = 1.5, class = "turn",  low = true  },
    mushroom    = { sprite = "mushroom",    radius = 1.5, class = "confuse", low = true },
    spring      = { sprite = "spring",      radius = 1.3, class = "jump",  low = true  },
}

-- weighted pick for ordinary obstacle rows (1.2.5)
D.obstacleWeights = {
    { "rock_small", 22 }, { "rock", 14 }, { "log_h", 12 }, { "log_v", 8 },
    { "tree", 10 }, { "grass_tuft", 12 }, { "footprint", 8 }, { "mud", 8 },
    { "bush", 14 }, { "mushroom", 7 }, { "spring", 6 },
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
        -- 1113 反馈：体型更大、速度放慢、路径偏纵（少跟人），成群同似鸟龙
        label = "TRICERATOPS", sprite = "enemy_trike", radius = 1.15, def = 2,
        contact = "hit",
        patterns = { "charge", "wall" },
    },
    trex = {
        label = "T-REX", sprite = "enemy_trex", radius = 1.3, def = 0,
        contact = "lethal",
        dwell = 12,        -- gives up after this many seconds
        rampTime = 5.5,    -- 1113 反馈：加速过程拉长，配合大视野给反应时间
    },
    para = {
        label = "PARASAUROLOPHUS", sprite = "enemy_para", radius = 1.1, def = 2,
        contact = "hit",
        babies = { sprite = "enemy_para_baby", radius = .5, def = 1 },
        scatterR = 3.4,    -- 1113 反馈：更近才炸开，四散感更强
    },
    ankylo = {
        label = "ANKYLOSAURUS", sprite = "enemy_ankylo", radius = .85, def = 3,
        contact = "hit",
        lead = { 6, 9 },   -- 1113 反馈：超车后保持更远距离，别贴脸
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
    { "para", 16 }, { "trex", 8 }, { "sauropod", 6 }, { "ptero", 8 },
}

-- ---------------------------------------------------------------- mounts
-- 1.2.7 + 1113 反馈：睡觉恐龙可用 K 换乘、可被弓箭射杀（def 同 1.2.6 对应
-- 物种）、会被追逐暴龙一口吞掉。Space 发动技能；uses 由能量果实/换乘重置。
D.mounts = {
    comps = {
        label = "COMPSOGNATHUS", speedMul = 1.00, uses = 1, def = 1,
        active = "boost",  passive = nil,
        run = { "mount_comps_run0", "mount_comps_run1" },
        idle = "mount_comps_run0", sleep = "mount_comps_sleep",
        boostMul = 2.2, boostDur = 2.5,     -- 1113：持续加长（配特效见 player）
    },
    trike = {
        label = "TRICERATOPS", speedMul = .92, uses = 1, def = 2,
        active = "charge", passive = nil,
        run = { "mount_trike_run0", "mount_trike_run1" },
        idle = "mount_trike_run0", sleep = "mount_trike_sleep",
        chargeDur = 3.5,                    -- 1113：持续加长
    },
    ankylo = {
        label = "ANKYLOSAURUS", speedMul = .88, uses = 1, def = 3,
        active = "charge", passive = nil,
        run = { "mount_ankylo_run0", "mount_ankylo_run1" },
        idle = "mount_ankylo_run0", sleep = "mount_ankylo_sleep",
        chargeDur = 3.5,                    -- 1113：持续加长
    },
    trex = {
        label = "T-REX HATCHLING", speedMul = 1.00, uses = 5, def = 3,   -- 1113：10→5
        active = "jump", passive = "devour",
        run = { "mount_trex_run0", "mount_trex_run1" },
        idle = "mount_trex_run0", sleep = "mount_trex_sleep",
        jumpDur = .7, devourR = 1.7,
    },
    dein = {
        label = "DEINONYCHUS", speedMul = 1.08, uses = 5, def = 1,       -- 1113：10→5
        active = "jump", passive = "spread",   -- 1113：被动改为一箭变三箭（耗 1 支）
        run = { "mount_dein_run0", "mount_dein_run1" },
        idle = "mount_dein_run0", sleep = "mount_dein_sleep",
        jumpDur = .7,
    },
    para = {
        label = "PARASAUROLOPHUS", speedMul = .95, uses = 2, def = 2,   -- 2 崽
        active = nil, passive = "shield",
        run = { "mount_para_run0", "mount_para_run1" },
        idle = "mount_para_run0", sleep = "mount_para_sleep",
    },
    pter = {
        label = "PTERANODON", speedMul = 1.05, uses = 1, def = 1,
        active = "fly", passive = nil,
        run = { "mount_pter_run0", "mount_pter_run1" },
        idle = "mount_pter_run0", sleep = "mount_pter_sleep",
        flyDur = 4.5,                         -- 1113：滞空加长
    },
}

D.mountOrder = { "comps", "trike", "ankylo", "trex", "dein", "para", "pter" }

return D
