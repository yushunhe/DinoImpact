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
    postHit    = 1.0,   -- 1113 反馈：碰撞判定结束后追加的无敌缓冲
    blinkRate  = .09,   -- sprite flicker period while invulnerable
    -- 撞进树/小树林：不进入停顿，无敌并降速，直到走出树冠
    treeSlow   = .35,   -- 在树上/树林里时的前进速度倍率
    treeHold   = .18,   -- 离开后仍保持减速的时间，防止边界抖动
    treeInvuln = .25,   -- 在树里每帧续的无敌时间
}

-- 1.2.3 archery: max 3 stored arrows, one refills every regen seconds.
C.arrow = {
    max   = 3,
    regen = 2.0,        -- 2 秒补一根（原 1.15 太慷慨）
    speed = 17,
    radius = .35,
    spreadDeg = 16,     -- 驰龙骑乘：一箭变三箭扇形的半角
    -- 射程无限（暂定）：不再有 life 时限，飞出世界存在范围的箭才消失
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

-- 拉屎翼龙：覆盖整个可视战场，但按行列错峰落下，不瞬间铺满。
C.ptero = {
    columns = 11,
    rows = 4,
    width = 38,
    startAhead = 4,
    rowGap = 3.8,
    columnStagger = .12,
    rowStagger = .85,
    shadowLead = .55,
    speed = 8,
    radius = .9,
    poopLife = 2.6,
}

-- 路过蜥脚类：三只巨型脚掌横向覆盖战场，逐脚落下并留出可躲的缝。
C.sauropod = {
    maxSteps = 3,
    stepInterval = .9,
    footRadius = 4.2,
    footOffsetsX = { -11.5, 0, 11.5 },
    lead = 7.5,
    rowGap = 4.5,
    shadowScale = { 2.2, 3.4 },
    footScale = { 8.4, 12 },
}

C.camera = {
    size = 9.6,         -- 1113 反馈：视野放大 ~1.55 倍，给足判断时间
    yOffset = 3.6,
    followRate = 9,
    sizeLerp = 3.5,
    zoomRun = .6,
}

-- 光照（docs/lighting-plan.md 第 0/1 步）：全局时段色调。
-- tint 乘到所有精灵/地面上，lift 加到暗部，bg 是相机背景色。
-- 白天必须保持中性（tint=1, lift=0），让默认画面与改动前一致。
-- 色值为占位，待基线截图后调整。
C.light = {
    enabled = true,       -- false: 强制中性（白天参数），用于 A/B 对比
    zone = "day",         -- 启动时段
    transition = 2.0,     -- 时段切换的过渡秒数（0 = 瞬切）
    -- 局部光源（第 2 步）。maxLights 必须与 Surf/Sprite 里的数组长度一致（8）。
    maxLights = 8,
    pickRange = 30,       -- 只取离玩家这个距离内的蛋/果实（玩家光永远在）
    sources = {
        player = { radius = 6,   color = { 1, .86, .60 },  intensity = .9, flicker = .04 },
        egg    = { radius = 3.5, color = { 1, .95, .75 },  intensity = .8, flicker = .08 },
        fruit  = { radius = 3,   color = { .70, 1, .60 },  intensity = .7, flicker = .10 },
    },
    -- 光晕（第 3 步）：每盏光一个柔光圆盘，直径 = 半径 * scale，不透明度 = 强度 * alpha。
    halo = { alpha = .14, scale = 1.8 },
    -- 暗角（第 3 步）：屏幕边缘压暗的强度，0 关闭。
    vignette = .25,
    -- 接触阴影（第 3 步）：玩家脚下阴影随太阳方向偏移。sunDir 指向光来的方向的反方向。
    sunDir = { -.4, -.6 },   -- 阴影投向的方向（会自动归一化）
    shadowOffset = .35,      -- 偏移量（世界单位）
    timeZones = {
        dawn  = { tint = { 1.00, .86, .72 }, lift = { .10, .08, .14 }, bg = { .16, .14, .18 } },
        day   = { tint = { 1, 1, 1 },        lift = { 0, 0, 0 },       bg = { .09, .15, .08 } },
        dusk  = { tint = { 1.00, .74, .58 }, lift = { .14, .06, .10 }, bg = { .20, .10, .12 } },
        night = { tint = { .52, .60, .86 },  lift = { .08, .10, .18 }, bg = { .04, .05, .10 } },
    },
}

C.world = {
    decorRadius = 2,       -- 植物群落与地貌共用 18 单位的格子
    meadowCover = .82,     -- 有植株簇的草地格比例，其余整格留白
    companionPatch = .72,  -- 地块另一侧再长一小簇
    cullX = 44,        -- sideways existence cull (relative to the player)
    cullBack = 20,     -- behind the player
    cullFore = 55,     -- unused (spawn-ahead limit), kept for clarity
}

-- 地貌（参考 Assets/Art/地貌.jpg）：底图永远是草地，蕨叶地/沼泽地按格子
-- 用确定性哈希盖上去。每格先掷"蕨叶地"，没中再掷"沼泽地"，都没中就是
-- 纯草地——所以大部分地方是草地，蕨叶地是小部分，沼泽地时不时出现。
-- 每块地的尺寸、长宽比、中心偏移都随机；再叠 1~2 块小"卫星地"拼出海星
-- 状边缘，避免一眼看出是矩形。
C.terrain = {
    cell      = 18,      -- 地貌判定格边长（世界单位）
    radius    = 2,       -- 玩家周围生成几圈地貌格
    fern      = { chance = .30, minFrac = .34, maxFrac = .78 },
    swamp     = { chance = .10, minFrac = .26, maxFrac = .58 },
    aspectMin = .72,     -- 地块高/宽
    aspectMax = 1.30,
    jitter    = .14,     -- 中心在格内抖动（格边长的比例）
    satelliteChance = .55,          -- 再拼一块小地块的概率
    satelliteSize   = { .30, .60 }, -- 小地块相对主地块的尺寸
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
-- 密度全面上调约 1~2 倍（行距缩短 + 每行数量/概率提高）
C.spawn = {
    safeStart = 16,
    obstacleGapMin = 12,   -- 除小树林外所有生成频率减半
    obstacleGapMax = 20,
    eggGapMin = 8,
    eggGapMax = 16,
    ahead = 30,            -- how far ahead rows are placed (~5 s of travel)
    anchorLimit = 36,      -- a row's anchor never sits further than this from
                           -- the player sideways (>= tan 48deg * ahead, so the
                           -- steepest heading still lands exactly on-path)
    eggValue = 25,
    killValue = 60,
    mountValue = 120,
    fruitChance = .20,     -- an egg row becomes a guarded fruit instead
                           -- （障碍行本身已减半，这里保持原值=总体减半）
    sleepChance = .34,     -- 换乘点（同上：随障碍行减半）
    enemyChance = .225,    -- per obstacle row, chance of also spawning an enemy event
    brakeEventGap = { 7, 12 },  -- 刹车停住时，干扰龙仍会隔这段时间来找你
}

-- Grove layouts describe overlapping crowns from the near edge into the woods.
-- Each entry is { sideways offset, forward offset, sprite, scale }.
C.groveField = {
    firstAt = 60,
    gapMin = 90,
    gapMax = 150,
    offset = 5,
    radius = 3.55,
    hitOffset = { grove = 3.3, grove_2 = 3.1, grove_3 = 2.05, grove_4 = 2.65 },
    layouts = {
        { {0, 0, "grove_3", .80}, {-2.1, 1.9, "grove_4", .94},
          {.9, 3.6, "grove", 1.13}, {3.9, 5.1, "grove_2", 1.04}, {5.5, 7.8, "grove_4", .86} },
        { {0, 0, "grove_4", .85}, {2.7, 1.7, "grove_3", .88},
          {-1.7, 3.6, "grove_2", 1.06}, {1.6, 5.6, "grove", 1.15}, {-.4, 8.6, "grove_4", .90} },
        { {0, 0, "grove_3", .85}, {2.5, 2.1, "grove", 1.08},
          {-2.3, 2.7, "grove_4", .91}, {-4.2, 5.4, "grove_2", 1.10} },
    },
}

-- 换乘判定（1.2.7 调整版 + 1113 反馈）：睡觉恐龙不伤害玩家、可被射杀；
-- 进入 range 即出绳索提示，按 K 就能换（不看朝向）。
C.mount = {
    range = 5.5,        -- 1113 反馈：判断距离再放大，且有绳索实体特效提示
}

-- Linear sprite scale: 1.5 gives dinosaurs 2.25 times their previous area.
C.dinoScale = 1.5

-- player body / animation
C.player = {
    radius = .55,
    animRate = .11,
}

C.rider = {
    shootPoseTime = .16,
    scale = .88,  -- relative to dinoScale
    seat = .30,
}

C.sprites = {
    shadow = "shadow",
    riderIdle = { [0] = "rider_idle_0", "rider_idle_1", "rider_idle_2", "rider" },
    riderShoot = { [0] = "rider_shoot_0", "rider_shoot_1", "rider_shoot_2", "rider_shoot_3" },
    arrow = "arrow",
    zzz = "zzz",
    rope = "rope_prompt",
    ring = "mount_ring",  -- 睡觉龙脚下的换乘范围圈（反馈1）
}

return C
