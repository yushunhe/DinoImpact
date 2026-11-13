-- Obstacles, collectibles, fruits and sleeping mount dinosaurs placed ahead
-- of the player on the endless plain, plus the nuisance-dino event director.
-- Design doc 1.2.4 / 1.2.5 / 1.2.6.
local Config = require("dino_config")
local Data = require("dino_data")
local Dino = require("dino_dinos")
local U = require("util")
local fx = require("fx")

local S = Config.spawn

local T = {
    items = {},          -- obstacles / items / sleeping dinos
    nextObstacle = 0,
    nextEgg = 0,
    nextEnemy = 0,
    brakeT = 0,          -- 刹车时干扰龙的上门计时（1113）
}

-- ------------------------------------------------------------------ add
local function addObstacle(kind, x, y)
    local def = Data.obstacles[kind]
    if not def then return nil end
    local id = Host.entity.new(def.sprite, x, y, 0)
    if def.rotZ then Host.entity.setRot(id, 0, 0, def.rotZ) end
    local it = {
        type = "obstacle", kind = kind, class = def.class, low = def.low,
        x = x, y = y, radius = def.radius, id = id, dead = false,
    }
    T.items[#T.items + 1] = it
    return it
end

local function addItem(sprKey, x, y, itemType)
    local def = Data.items[sprKey]
    local id = Host.entity.new(def.sprite, x, y, 0)
    local it = {
        type = itemType, kind = sprKey, class = sprKey,
        x = x, y = y, baseY = y, radius = def.radius, id = id,
        phase = math.random() * 6.28, dead = false,
    }
    T.items[#T.items + 1] = it
    return it
end

function T.addEgg(x, y)
    return addItem("egg", x, y, "egg")
end

function T.addFruit(kind, x, y)
    return addItem(kind, x, y, "fruit")
end

function T.addObstacle(kind, x, y)
    return addObstacle(kind, x, y)
end

-- sleeping mount dinosaur (1.2.7): walks right past it - it never hurts the
-- player (design change: 可换乘的恐龙不造成伤害); J within C.mount.range swaps.
function T.addSleepDino(mountKey, x, y)
    local m = Data.mounts[mountKey]
    local id = Host.entity.new(m.sleep, x, y, 0)
    local zid = Host.entity.new(Config.sprites.zzz, x, y + 1.1, -.4)
    local it = {
        type = "mount", kind = mountKey, class = "mount", mount = true,
        x = x, y = y, radius = .95, id = id, zzz = zid, dead = false,
    }
    T.items[#T.items + 1] = it
    -- 1113 反馈：睡觉龙可被弓箭射杀（防值同 1.2.6 物种）、会被暴龙吞掉
    it.target = Dino.addSleepTarget(it, m.def)
    return it
end

-- ------------------------------------------------------------------ spawning
local function eggNear(x, y)
    for i = 1, #T.items do
        local it = T.items[i]
        if it.type == "egg" and not it.dead then
            if U.dist2(it.x, it.y, x, y) < 7.5 then return true end
        end
    end
    return false
end

-- 1113 反馈：线形原来只有横向，补上"纵线"（顺着预测路线排，直跑连吃）；
-- 多边形补 圆形/菱形 两种阵列（3-4-3 团保留）
local function spawnEggRow(P, y)
    local cx = P:futureX(y)
    local mode = U.pick({ { "line", 26 }, { "vert", 24 }, { "blob", 20 },
                          { "diamond", 16 }, { "circle", 14 } })
    if mode == "line" then
        local count = math.random(3, 5)
        local x0 = cx + (math.random() * 2 - 1) * 3.8
        local start = x0 - (count - 1) * 1.15 * .5
        for i = 1, count do
            T.addEgg(start + (i - 1) * 1.15, y)
        end
    elseif mode == "vert" then
        local count = math.random(4, 6)
        for i = 1, count do
            local yy = y + (i - 1) * 1.7
            T.addEgg(P:futureX(yy), yy)
        end
    elseif mode == "blob" then
        cx = cx + (math.random() * 2 - 1) * 1.5
        local rows = { { n = 3, dy = 1.2 }, { n = 4, dy = 0 }, { n = 3, dy = -1.2 } }
        for r = 1, #rows do
            local row = rows[r]
            for i = 1, row.n do
                T.addEgg(cx + (i - 1) * 1.15 - (row.n - 1) * .575, y + row.dy)
            end
        end
    elseif mode == "diamond" then
        local s = 1.35
        local pts = { { 0, 2 }, { -1, 1 }, { -2, 0 }, { -1, -1 },
                      { 0, -2 }, { 1, -1 }, { 2, 0 }, { 1, 1 } }
        for _, p in ipairs(pts) do
            T.addEgg(cx + p[1] * s, y + p[2] * s * .85)
        end
    else   -- circle：圆环八枚
        for i = 1, 8 do
            local ang = (i / 8) * U.tau
            T.addEgg(cx + math.cos(ang) * 2.1, y + math.sin(ang) * 1.7)
        end
    end
end

local function spawnObstacleRow(P, y)
    local cx = P:futureX(y)
    -- 睡觉的恐龙：换乘点（也当阻拦物处理）
    if U.chance(S.sleepChance) then
        local key = U.choice(Data.mountOrder)
        T.addSleepDino(key, cx + (math.random() * 2 - 1) * 3.5, y)
        return
    end
    -- 道具果实：单个出现、周围障碍偏多（1.2.4 (2)(3)）
    if U.chance(S.fruitChance) then
        local fruitKey = U.chance(.55) and "fruit_energy" or "fruit_life"
        local fx0 = cx + (math.random() * 2 - 1) * 3.5
        addItem(fruitKey, fx0, y, "fruit")
        for i = 1, 3 do
            local ang = (i / 3) * U.tau + math.random()
            addObstacle(U.pick(Data.obstacleWeights),
                fx0 + math.cos(ang) * 2.4, y + math.sin(ang) * 1.6)
        end
        return
    end
    -- 1113 反馈：效果类障碍不掉血、占地放大后要"大胆分布广泛"，
    -- 一行最多 3 个；阻拦类仍贴脸放，保证撞得实
    local count = math.random(1, U.chance(.45) and 3 or 2)
    for i = 1, count do
        local kind = U.pick(Data.obstacleWeights)
        local spread = Data.obstacles[kind].class == "block" and 6.5 or 10
        local x = cx + (math.random() * 2 - 1) * spread
        if not eggNear(x, y) then
            addObstacle(kind, x, y + (i - 1) * .9)
        end
    end
end

function T.clear()
    for i = 1, #T.items do
        local it = T.items[i]
        if Host.entity.exists(it.id) then Host.entity.kill(it.id) end
        if it.zzz and Host.entity.exists(it.zzz) then Host.entity.kill(it.zzz) end
    end
    T.items = {}
end

function T.reset(P)
    T.clear()
    T.nextObstacle = P.y + S.safeStart
    T.nextEgg = P.y + 4.5
    T.nextEnemy = P.y + S.safeStart + 14
    T.brakeT = S.brakeEventGap[1]
    for i = 1, 3 do T.addEgg(P.x - 1.2 + (i - 1) * 1.2, P.y + 5.5) end
    -- 开局默认骑乘似鸟龙在 UI 上说明；路上先给一只睡觉的三角龙当教学换乘点
    T.addSleepDino("trike", P.x + 3.2, P.y + S.safeStart + 6)
end

-- ------------------------------------------------------------------ collisions
local function hitObstacle(it, P)
    if it.mount then return end   -- 睡觉的恐龙：无害，径直路过（换乘走 J）
    if it.class == "block" then
        if P.chargeT > 0 then
            -- 三角龙/甲龙技能：撞飞阻拦型障碍
            it.dead = true
            fx.event("impact", it.x, it.y, 1)
            fx.sound(Config.juice.hurtSound, .4)
            return
        end
        local res = P:hurt(false)
        if res == "died" then return end
        if res == "hurt" then
            fx.sound(Config.juice.hurtSound, .8)
            fx.event("impact", it.x, it.y, 1)
            fx.shake(Config.juice.hurtShake, .25)
        end
        -- 无敌/受击期间仍与碰撞体保持接触：把玩家沿法线推出，
        -- 并把无敌延长到"本次碰撞判定结束"
        local d = U.dist(P.x, P.y, it.x, it.y)
        local rr = it.radius + P.radius
        if d < rr then
            local k = (rr - d) / math.max(d, .001)
            P.x = P.x + (P.x - it.x) * k
            P.y = P.y + (P.y - it.y) * k
            -- 1113 反馈：密集处连续掉血 → 保持接触期间把无敌顶到 postHit，
            -- 脱离碰撞判定后还剩 ~1 秒缓冲
            P:extendInvuln(Config.run.postHit)
        end
    elseif it.class == "turn" then
        if P:applyEffect("turn") then
            fx.sound("tick", .5)
            fx.event("sparkle", P.x, P.y, .5)
        end
    elseif it.class == "confuse" then
        if P:applyEffect("confuse") then
            fx.sound("tick", .5)
            fx.event("sparkle", P.x, P.y + .8, .9)
        end
    else
        P:applyEffect(it.class)   -- slow / boost / jump
    end
end

-- ------------------------------------------------------------------ update
function T.update(dt, P)
    local ahead = P.y + S.ahead
    while T.nextObstacle < ahead do
        spawnObstacleRow(P, T.nextObstacle)
        T.nextObstacle = T.nextObstacle + S.obstacleGapMin
            + math.random() * (S.obstacleGapMax - S.obstacleGapMin)
    end
    while T.nextEgg < ahead do
        spawnEggRow(P, T.nextEgg)
        T.nextEgg = T.nextEgg + S.eggGapMin + math.random() * (S.eggGapMax - S.eggGapMin)
    end
    -- 干扰恐龙事件（1.2.6）
    while T.nextEnemy < ahead do
        if U.chance(S.enemyChance) then
            Dino.spawnEvent(U.pick(Data.enemyWeights), P, T.nextEnemy)
        end
        T.nextEnemy = T.nextEnemy + 16 + math.random() * 14
    end

    -- 1113 反馈：刹车停住不等于安全区，干扰龙照样上门来找（可射可躲）
    local g = S.brakeEventGap
    if P.braking and P.alive then
        T.brakeT = T.brakeT - dt
        if T.brakeT <= 0 then
            T.brakeT = g[1] + math.random() * (g[2] - g[1])
            Dino.spawnEvent(U.pick(Data.enemyWeights), P, P.y + 6 + math.random() * 10)
        end
    else
        T.brakeT = g[1] + math.random() * (g[2] - g[1])
    end

    local now = Host.time()
    local cull = P.y - Config.world.cullBack
    local cullX = Config.world.cullX
    local i = 1
    local deepest, deepestOver = nil, 0
    while i <= #T.items do
        local it = T.items[i]
        local remove = it.dead or it.y < cull or it.y > P.y + S.ahead + 30
            or math.abs(it.x - P.x) > cullX
            or not Host.entity.exists(it.id)

        if not remove then
            if it.type == "mount" and it.zzz and Host.entity.exists(it.zzz) then
                Host.entity.setPos(it.zzz, it.x, it.y + 1.1 + math.sin(now * 2 + it.y) * .08, -.4)
            end
            if (it.type == "egg" or it.type == "fruit") then
                local dy = it.baseY + math.sin(now * 2.6 + it.phase) * .12
                it.y = dy
                Host.entity.setPos(it.id, it.x, dy, 0)
            end
            if U.dist2(P.x, P.y, it.x, it.y) < (P.radius + it.radius) ^ 2 then
                if it.type == "egg" then
                    it.dead = true
                    remove = true
                    P:collectEgg()
                    fx.sound(Config.juice.eggSound, .8)
                    fx.event("sparkle", it.x, it.baseY, .8)
                    fx.shake(Config.juice.eggShake, .15)
                elseif it.type == "fruit" then
                    it.dead = true
                    remove = true
                    if it.kind == "fruit_life" then
                        P:heal()
                        fx.sound("coin", .9)
                        fx.event("sparkle", it.x, it.y, 1.1)
                    else
                        fx.sound("boost", .8)
                        fx.event("boost", it.x, it.y, 1)
                    end
                    if T.onPickup then T.onPickup(it.kind) end
                else
                    -- 只结算"重叠最深"的一个障碍：多块放大后的石头同时挤住
                    -- 玩家时，逐条推出的法线会互相抵消、把人永久卡死
                    local rr = P.radius + it.radius
                    local over = rr * rr
                        - U.dist2(P.x, P.y, it.x, it.y)
                    if over > deepestOver then deepest, deepestOver = it, over end
                end
            end
        end

        if remove then
            Host.entity.kill(it.id)
            if it.zzz and Host.entity.exists(it.zzz) then Host.entity.kill(it.zzz) end
            table.remove(T.items, i)
        else
            i = i + 1
        end
    end
    if deepest and P.alive then hitObstacle(deepest, P) end
    Dino.update(dt, P, T)
end

function T.findMountsNear(x, y, r)
    local out = {}
    for i = 1, #T.items do
        local it = T.items[i]
        if it.type == "mount" and not it.dead and U.dist2(it.x, it.y, x, y) < r * r then
            out[#out + 1] = it
        end
    end
    return out
end

function T.removeMount(it)
    it.dead = true
end

return T
