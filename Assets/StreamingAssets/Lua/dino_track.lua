-- Obstacles, collectibles, fruits and sleeping mount dinosaurs placed ahead
-- of the player on the endless plain, plus the nuisance-dino event director.
-- Design doc 1.2.4 / 1.2.5 / 1.2.6.
local Config = require("dino_config")
local Data = require("dino_data")
local Dino = require("dino_dinos")
local U = require("util")
local fx = require("fx")

local S = Config.spawn
local GF = Config.groveField

local T = {
    items = {},          -- obstacles / items / sleeping dinos
    fields = {},         -- 小树林大区域的不可通行范围
    nextObstacle = 0,
    nextEgg = 0,
    nextEnemy = 0,
    nextGrove = 0,
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
    if T.isBlocked(x, y) then return nil end
    return addItem("egg", x, y, "egg")
end

function T.addFruit(kind, x, y)
    if T.isBlocked(x, y) then return nil end
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
    -- 换乘范围圈（反馈1）：圈内按 K 就能换，玩家一眼看到可换位置
    local rid = Host.entity.new(Config.sprites.ring, x, y, -.15)
    local rd = Config.mount.range * 2
    Host.entity.setScale(rid, rd, rd, 1)
    local it = {
        type = "mount", kind = mountKey, class = "mount", mount = true,
        x = x, y = y, radius = .95, id = id, zzz = zid, ring = rid, dead = false,
    }
    T.items[#T.items + 1] = it
    -- 1113 反馈：睡觉龙可被弓箭射杀（防值同 1.2.6 物种）、会被暴龙吞掉
    it.target = Dino.addSleepTarget(it, m.def)
    return it
end

-- ------------------------------------------------------------------ spawning

local function removeItemAt(i)
    local it = T.items[i]
    if it.id and Host.entity.exists(it.id) then Host.entity.kill(it.id) end
    if it.zzz and Host.entity.exists(it.zzz) then Host.entity.kill(it.zzz) end
    if it.ring and Host.entity.exists(it.ring) then Host.entity.kill(it.ring) end
    table.remove(T.items, i)
end

-- 小树林大区域：整片区域不可通行。普通生成器在区域范围内不再放蛋/果实/
-- 障碍，玩家只能绕行；区域由多棵 grove 组成，每棵都是阻拦障碍。
function T.isBlocked(x, y)
    for i = 1, #T.fields do
        local f = T.fields[i]
        if math.abs(x - f.x) <= f.hw
            and y >= f.y - 1 and y <= f.y + f.depth + 1 then
            return true
        end
    end
    return false
end

function T.spawnGroveField(cx, y)
    local c = GF
    local rows = #c.rowCounts
    local maxCols = 0
    for r = 1, rows do
        if c.rowCounts[r] > maxCols then maxCols = c.rowCounts[r] end
    end
    -- 横向范围要盖住最外侧 grove 的碰撞圈（中心偏移 + jitter + 半径），
    -- 纵向范围要盖住整片树冠，避免蛋/果实生成在树冠里。
    local halfW = (maxCols - 1) * c.spacingX * .5 + c.jitter
        + c.radius * c.scaleMax + .5
    local depth = (rows - 1) * c.spacingY + 7.2 * c.scaleMax
        + c.columnStagger + c.jitter * .5

    -- 清掉已经生成在区域里的可拾取物和普通障碍，避免蛋/换乘点被埋进
    -- 不可达的树林；睡觉恐龙（换乘点）保留，它本身无害。
    for i = #T.items, 1, -1 do
        local it = T.items[i]
        if not it.field and it.type ~= "mount" and it.x
            and math.abs(it.x - cx) <= halfW + 1
            and it.y >= y - 1 and it.y <= y + depth + 1 then
            removeItemAt(i)
        end
    end

    T.fields[#T.fields + 1] = { x = cx, y = y, hw = halfW, depth = depth }

    -- 后排先画、前排压在上面；每排 1/2/3 棵，整体是尖朝玩家的倒三角。
    for row = rows, 1, -1 do
        local count = c.rowCounts[row]
        for col = 1, count do
            local sc = c.scaleMin + math.random() * (c.scaleMax - c.scaleMin)
            local x = cx + (col - (count + 1) * .5) * c.spacingX
                + (math.random() * 2 - 1) * c.jitter
            -- 每棵独立上下错开，前排不再是一条直线
            local stagger = (math.random() * 2 - 1) * c.columnStagger
            local yy = y + (row - 1) * c.spacingY + stagger
                + (math.random() * 2 - 1) * c.jitter * .5
            local sprite = U.choice(c.sprites)
            local id = Host.entity.new(sprite, x, yy, 0)
            Host.entity.setScale(id, sc, sc, 1)
            T.items[#T.items + 1] = {
                type = "obstacle", kind = sprite, class = "block", low = false,
                x = x, y = yy, radius = c.radius * sc, id = id, dead = false,
                field = true,
            }
        end
    end
    return T.fields[#T.fields]
end

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
        local count = math.random(4, 6)
        local x0 = cx + (math.random() * 2 - 1) * 3.8
        local start = x0 - (count - 1) * 1.15 * .5
        for i = 1, count do
            T.addEgg(start + (i - 1) * 1.15, y)
        end
    elseif mode == "vert" then
        local count = math.random(5, 7)
        for i = 1, count do
            local yy = y + (i - 1) * 1.7
            T.addEgg(P:futureX(yy), yy)
        end
    elseif mode == "blob" then
        cx = cx + (math.random() * 2 - 1) * 1.5
        local rows = { { n = 4, dy = 1.2 }, { n = 5, dy = 0 }, { n = 4, dy = -1.2 } }
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
        T.addEgg(cx, y)   -- 菱形中心再补一枚
    else   -- circle：圆环十枚
        for i = 1, 10 do
            local ang = (i / 10) * U.tau
            T.addEgg(cx + math.cos(ang) * 2.1, y + math.sin(ang) * 1.7)
        end
        T.addEgg(cx, y)
    end
end

local function spawnObstacleRow(P, y)
    local cx = P:futureX(y)
    -- 睡觉的恐龙：换乘点（也当阻拦物处理）
    if U.chance(S.sleepChance) then
        local key = U.choice(Data.mountOrder)
        local sx = cx + (math.random() * 2 - 1) * 3.5
        if not T.isBlocked(sx, y) then T.addSleepDino(key, sx, y) end
        return
    end
    -- 道具果实：单个出现、周围障碍偏多（1.2.4 (2)(3)）
    if U.chance(S.fruitChance) then
        local fruitKey = U.chance(.55) and "fruit_energy" or "fruit_life"
        local fx0 = cx + (math.random() * 2 - 1) * 3.5
        if T.isBlocked(fx0, y) then return end
        T.addFruit(fruitKey, fx0, y)
        for i = 1, 4 do
            local ang = (i / 4) * U.tau + math.random()
            local ox = fx0 + math.cos(ang) * 2.4
            local oy = y + math.sin(ang) * 1.6
            if not T.isBlocked(ox, oy) then
                addObstacle(U.pick(Data.obstacleWeights), ox, oy)
            end
        end
        return
    end
    -- 密度上调：一行 2~4 个（原来 1~3）；阻拦类仍贴脸放，保证撞得实
    local count = math.random(2, U.chance(.45) and 4 or 3)
    for i = 1, count do
        local kind = U.pick(Data.obstacleWeights)
        local spread = Data.obstacles[kind].class == "block" and 6.5 or 10
        local x = cx + (math.random() * 2 - 1) * spread
        local oy = y + (i - 1) * .9
        if not T.isBlocked(x, oy) and not eggNear(x, y) then
            addObstacle(kind, x, oy)
        end
    end
end

function T.clear()
    for i = 1, #T.items do
        local it = T.items[i]
        if Host.entity.exists(it.id) then Host.entity.kill(it.id) end
        if it.zzz and Host.entity.exists(it.zzz) then Host.entity.kill(it.zzz) end
        if it.ring and Host.entity.exists(it.ring) then Host.entity.kill(it.ring) end
    end
    T.items = {}
    T.fields = {}
end

function T.reset(P)
    T.clear()
    T.nextObstacle = P.y + S.safeStart
    T.nextEgg = P.y + 4.5
    T.nextEnemy = P.y + S.safeStart + 14
    T.nextGrove = P.y + GF.firstAt
    T.brakeT = S.brakeEventGap[1]
    for i = 1, 3 do T.addEgg(P.x - 1.2 + (i - 1) * 1.2, P.y + 5.5) end
    -- 开局默认骑乘似鸟龙在 UI 上说明；路上先给一只睡觉的三角龙当教学换乘点
    T.addSleepDino("trike", P.x + 3.2, P.y + S.safeStart + 6)
end

-- ------------------------------------------------------------------ collisions
local function isTreeBlock(it)
    return it.field or it.kind == "tree"
end

local function hitObstacle(it, P)
    if it.mount then return end   -- 睡觉的恐龙：无害，径直路过（换乘走 J）
    if it.class == "block" then
        if P.chargeT > 0 then
            -- 三角龙/甲龙技能：撞飞普通阻拦型障碍。
            -- 树和小树林永远不消失，冲锋也只能穿过去。
            if isTreeBlock(it) then return end
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
        -- 树/小树林：不硬推出去，也不停跑。扣完这一下后保持无敌 + 减速，
        -- 玩家自己（或自动）慢慢走出树冠，离开后恢复速度。
        if isTreeBlock(it) and P.airborneT <= 0 and P.flyT <= 0 then
            P.stunned = false
            P.blockT = Config.run.treeHold
            P:extendInvuln(Config.run.treeInvuln)
            return
        end
        -- 其他阻拦型障碍不消失，但把玩家沿法线推出，避免卡在碰撞体里
        local d = U.dist(P.x, P.y, it.x, it.y)
        local rr = it.radius + P.radius
        if d < rr then
            local k = (rr - d) / math.max(d, .001)
            P.x = P.x + (P.x - it.x) * k
            P.y = P.y + (P.y - it.y) * k
            P:extendInvuln(Config.run.postHit)
        end
    elseif it.class == "turn" then
        it.dead = true
        if P:applyEffect("turn") then
            fx.sound("tick", .5)
            fx.event("sparkle", P.x, P.y, .5)
        end
    elseif it.class == "confuse" then
        it.dead = true
        if P:applyEffect("confuse") then
            fx.sound("tick", .5)
            fx.event("sparkle", P.x, P.y + .8, .9)
        end
    else
        it.dead = true
        P:applyEffect(it.class)   -- slow / boost / jump
    end
end

-- ------------------------------------------------------------------ update
function T.update(dt, P)
    local ahead = P.y + S.ahead
    while T.nextGrove < ahead do
        local cx = P:futureX(T.nextGrove)
            + (math.random() * 2 - 1) * GF.offset
        T.spawnGroveField(cx, T.nextGrove)
        T.nextGrove = T.nextGrove + GF.gapMin
            + math.random() * (GF.gapMax - GF.gapMin)
    end
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
        local ex = P:futureX(T.nextEnemy)
        if U.chance(S.enemyChance) and not T.isBlocked(ex, T.nextEnemy) then
            Dino.spawnEvent(U.pick(Data.enemyWeights), P, T.nextEnemy)
        end
        T.nextEnemy = T.nextEnemy + 11 + math.random() * 9
    end

    -- 1113 反馈：刹车停住不等于安全区，干扰龙照样上门来找（可射可躲）
    local g = S.brakeEventGap
    if P.braking and P.alive then
        T.brakeT = T.brakeT - dt
        if T.brakeT <= 0 then
            T.brakeT = g[1] + math.random() * (g[2] - g[1])
            local by = P.y + 5 + math.random() * 7
            if not T.isBlocked(P:futureX(by), by) then
                Dino.spawnEvent(U.pick(Data.enemyWeights), P, by)
            end
        end
    else
        T.brakeT = g[1] + math.random() * (g[2] - g[1])
    end

    local now = Host.time()
    local cull = P.y - Config.world.cullBack
    for i = #T.fields, 1, -1 do
        local f = T.fields[i]
        if f.y + f.depth < cull then table.remove(T.fields, i) end
    end
    local cullX = Config.world.cullX
    local i = 1
    local deepest, deepestOver = nil, 0
    local treeOverlap = false
    while i <= #T.items do
        local it = T.items[i]
        local remove = it.dead or it.y < cull or it.y > P.y + S.ahead + 30
            or math.abs(it.x - P.x) > cullX
            or not Host.entity.exists(it.id)

        if not remove then
            local overlap = U.dist2(P.x, P.y, it.x, it.y)
                < (P.radius + it.radius) ^ 2
            if overlap and isTreeBlock(it) then treeOverlap = true end
            if it.type == "mount" and it.zzz and Host.entity.exists(it.zzz) then
                Host.entity.setPos(it.zzz, it.x, it.y + 1.1 + math.sin(now * 2 + it.y) * .08, -.4)
            end
            if it.type == "mount" and it.ring and Host.entity.exists(it.ring) then
                local k = Config.mount.range * 2 * (1 + .035 * math.sin(now * 2.2 + it.y))
                Host.entity.setScale(it.ring, k, k, 1)
            end
            if (it.type == "egg" or it.type == "fruit") then
                local dy = it.baseY + math.sin(now * 2.6 + it.phase) * .12
                it.y = dy
                Host.entity.setPos(it.id, it.x, dy, 0)
            end
            if overlap then
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
                elseif it.type == "obstacle" then
                    -- 只结算重叠最深的一个障碍；命中后立即移除，避免卡死
                    local rr = P.radius + it.radius
                    local over = rr * rr
                        - U.dist2(P.x, P.y, it.x, it.y)
                    if over > deepestOver then
                        deepest, deepestOver = it, over
                    end
                end
            end
        end

        if remove then
            Host.entity.kill(it.id)
            if it.zzz and Host.entity.exists(it.zzz) then Host.entity.kill(it.zzz) end
            if it.ring and Host.entity.exists(it.ring) then Host.entity.kill(it.ring) end
            table.remove(T.items, i)
        else
            i = i + 1
        end
    end
    if deepest and P.alive then
        hitObstacle(deepest, P)
        if deepest.dead then
            if Host.entity.exists(deepest.id) then Host.entity.kill(deepest.id) end
            -- 按对象本身删除：循环里可能已经删过其他 item，索引会变
            for k = #T.items, 1, -1 do
                if T.items[k] == deepest then table.remove(T.items, k); break end
            end
        end
    end
    -- 还在树/小树林里：保持无敌 + 减速，直到真正走出去
    if treeOverlap and P.alive and P.airborneT <= 0 and P.flyT <= 0
        and P.chargeT <= 0 then
        P.blockT = Config.run.treeHold
        P.invulnT = math.max(P.invulnT, Config.run.treeInvuln)
    end
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
