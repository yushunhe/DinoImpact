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

C.world = {
    decorCell = 4,       -- 密度翻倍：格子缩小，内容量按格计
    decorRadius = 8,     -- 半径同步放大，保持覆盖面不缩水
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
    obstacleGapMin = 6,
    obstacleGapMax = 10,
    eggGapMin = 4,
    eggGapMax = 8,
    ahead = 30,            -- how far ahead rows are placed (~5 s of travel)
    anchorLimit = 36,      -- a row's anchor never sits further than this from
                           -- the player sideways (>= tan 48deg * ahead, so the
                           -- steepest heading still lands exactly on-path)
    eggValue = 25,
    killValue = 60,
    mountValue = 120,
    fruitChance = .20,     -- an egg row becomes a guarded fruit instead
    sleepChance = .34,     -- 换乘点：随行密度同步上调
    enemyChance = .45,     -- per obstacle row, chance of also spawning an enemy event
    brakeEventGap = { 3.5, 6 },  -- 刹车停住时，干扰龙仍会隔这段时间来找你
}

-- 小树林大区域：跑道中的不可通行地标（参考 edgesurf 的礁石群）。
-- 由若干 grove sprite 拼成，每棵 grove 都是阻拦障碍；碰撞圈互相重叠，
-- 整片区域没有可钻的缝，玩家只能从左边或右边绕过去。
C.groveField = {
    firstAt = 60,          -- 第一个区域离起点的距离（世界单位）
    gapMin = 90,           -- 两个区域之间的最小距离
    gapMax = 150,
    cols = 3,
    rows = 2,
    spacingX = 4.6,        -- 相邻 grove 中心间距（碰撞圈必须重叠）
    spacingY = 4.5,
    jitter = .6,
    scaleMin = 1.0,
    scaleMax = 1.2,
    radius = 3.9,          -- 单棵 grove 的碰撞半径（最终还要乘 scale）
    offset = 5,            -- 区域中心相对预测路线的横向偏移
    sprites = { "grove", "grove_2", "grove_3", "grove_4" },
}

-- 换乘判定（1.2.7 调整版 + 1113 反馈）：睡觉恐龙不伤害玩家、可被射杀；
-- 进入 range 即出绳索提示，按 K 就能换（不看朝向）。
C.mount = {
    range = 5.5,        -- 1113 反馈：判断距离再放大，且有绳索实体特效提示
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
    ring = "mount_ring",  -- 睡觉龙脚下的换乘范围圈（反馈1）
}

return C
