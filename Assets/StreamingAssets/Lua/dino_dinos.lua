-- DINO IMPACT - nuisance dinosaurs (1.2.6), arrows and enemy projectiles.
--
-- Every behaviour from the design doc, kept data-driven through dino_data.
-- The module owns: enemy entities, arrow projectiles, feathers, poop,
-- sauropod footsteps and the T-Rex chase. The track director calls
-- Dino.spawnEvent() to start an event; Game calls Dino.update(dt, P, T).
local Config = require("dino_config")
local Data = require("dino_data")
local U = require("util")
local fx = require("fx")

local E = Config.effects

local Dino = {
    enemies = {},     -- nuisance dinos
    shots = {},       -- player arrows
    their = {},       -- enemy projectiles (feathers, poop, stomps)
    kills = 0,
}

-- ------------------------------------------------------------------ helpers
local function add(list, kind, x, y, radius, data)
    local d = data or {}
    d.kind = kind
    d.x, d.y = x, y
    d.radius = radius
    d.t = d.t or 0
    d.id = Host.entity.new(d.sprite or kind, x, y, 0)
    if list == Dino.enemies then Host.entity.setScale(d.id, Config.dinoScale, Config.dinoScale, 1) end
    if d.rotZ then Host.entity.setRot(d.id, 0, 0, d.rotZ) end
    list[#list + 1] = d
    return d
end

local function moveEnt(it)
    if it.id and Host.entity.exists(it.id) then
        Host.entity.setPos(it.id, it.x, it.y, 0)
    end
end

local function removeAt(list, i)
    local it = list[i]
    -- 睡觉的骑乘龙被射杀/吞掉：通知 track 清掉本体和 zzz
    if it.sleepMount and it.item then it.item.dead = true end
    if it.id and Host.entity.exists(it.id) then Host.entity.kill(it.id) end
    if it.shadowId and Host.entity.exists(it.shadowId) then Host.entity.kill(it.shadowId) end
    if it.bombs then
        for i = 1, #it.bombs do
            local spot = it.bombs[i]
            if spot.sid and Host.entity.exists(spot.sid) then
                Host.entity.kill(spot.sid)
            end
            spot.sid = nil
        end
    end
    if it.legs then
        for i = 1, #it.legs do
            local leg = it.legs[i]
            if leg.sid and Host.entity.exists(leg.sid) then
                Host.entity.kill(leg.sid)
            end
            leg.sid = nil
        end
    end
    table.remove(list, i)
end

-- 1113 反馈：睡着的可驾驭恐龙也能被弓箭射杀、被暴龙一口吞。track 摆放时
-- 注册一条"可射击目标"，共用 track 实体的 id；接触伤害另行排除（不伤人）。
function Dino.addSleepTarget(it, defVal)
    if not defVal or defVal <= 0 then return nil end
    local e = { kind = it.kind, x = it.x, y = it.y, radius = it.radius,
                def = defVal, hp = defVal, still = true, sleepMount = true,
                item = it, id = it.id, t = 0 }
    table.insert(Dino.enemies, e)
    return e
end

-- 成功换乘：目标条目撤下（实体归 track 处理），不计击杀
function Dino.dropSleepMount(item)
    for i = #Dino.enemies, 1, -1 do
        local e = Dino.enemies[i]
        if e.sleepMount and e.item == item then
            e.id = nil
            table.remove(Dino.enemies, i)
            return
        end
    end
end

local function overlaps(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    local rr = a.radius + b.radius
    return dx * dx + dy * dy < rr * rr
end

-- Is there a blocking obstacle at (x,y)? Used by T-Rex / Ankylo / Dein.
local function blockingAt(T, x, y)
    if not T then return false end
    local items = T.items
    for i = 1, #items do
        local it = items[i]
        if not it.dead and it.class == "block" then
            local dx, dy = it.x - x, it.y - y
            if dx * dx + dy * dy < (it.radius + 1) * (it.radius + 1) then
                return true, it
            end
        end
    end
    return false
end

-- ------------------------------------------------------------------ spawns
-- pattern briefs from 1.2.6 — spawnEvent(kind, P, y) puts one happening
-- about `y` metres ahead.
function Dino.spawnEvent(kind, P, y)
    local def = Data.enemies[kind]
    if not def then return end
    local r = math.random

    if kind == "comps" then
        local cx = P:futureX(y)
        if U.chance(.5) then
            -- 闲逛的：单只横向(或斜向)溜达
            local side = U.chance(.5) and 1 or -1
            add(Dino.enemies, kind, cx + side * 10, y, def.radius, {
                sprite = def.sprite, def = def.def, hp = def.def,
                vx = -side * (r() < .5 and 2.2 or 4),
                vy = U.chance(.4) and -1.2 or 0,
            })
        else
            -- 连绵一排（1113：排面要够宽、间距别太密，逼玩家射开缺口穿过）
            local n = 9 + math.floor(r() * 4)
            local x0 = cx - n * .95
            for i = 1, n do
                add(Dino.enemies, kind, x0 + (i - 1) * 1.9, y + (i % 2) * .7,
                    def.radius, {
                    sprite = def.sprite, def = def.def, hp = def.def,
                    vx = -2.4, wall = true,
                })
            end
        end

    elseif kind == "trike" then
        -- 1113 反馈：成群设定同似鸟龙（横排留缺口），单只则纵向冲锋、
        -- 速度放慢、几乎不跟人（与横移的似鸟龙区分开）
        local cx = P:futureX(y)
        if U.chance(.4) then
            local n = 4 + math.floor(r() * 3)
            local x0 = cx - n * 1.05
            for i = 1, n do
                add(Dino.enemies, kind, x0 + (i - 1) * 2.1, y + (i % 2) * 1.2,
                    def.radius, {
                    sprite = def.sprite, def = def.def, hp = def.def,
                    charge = true, vy = -2.4, wall = true,
                })
            end
        else
            local pack = U.chance(.3) and 2 or 1
            for i = 1, pack do
                add(Dino.enemies, kind, cx + (i - 1) * 2.6 - pack * 1.3
                    + (r() * 2 - 1) * 2, y + 7 + i * 2, def.radius, {
                    sprite = def.sprite, def = def.def, hp = def.def,
                    charge = true, vy = -(2.4 + r() * .8),
                })
            end
        end

    elseif kind == "trex" then
        -- 追逐的暴龙：从身后出现；玩家保持方向不变才会越追越快（1.2.6）
        add(Dino.enemies, kind, P.x, P.y - 8, def.radius, {
            sprite = def.sprite, def = 0, chase = true,
            life = def.dwell, vx = 0,
            steerT = 0, lastH = P.heading,
            scale = 1.6,
        })
        fx.shake(.15, .3)

    elseif kind == "para" then
        -- 带崽的鸭嘴龙（1113：把"杵着+炸窝"做出来）：成体居中，
        -- 1~3 个幼体围在成体身边，进圈才突然四散
        local x0 = P:futureX(y) + (r() * 2 - 1) * 3
        for i = 1, 2 do
            add(Dino.enemies, kind, x0 + (i - 1) * 2.0 - 1.0, y, def.radius, {
                sprite = def.sprite, def = def.def, hp = def.def, still = true,
            })
        end
        local bd = def.babies
        local nb = 1 + math.floor(r() * 3)
        for i = 1, nb do
            local ang = (i / nb) * U.tau + r() * .6
            add(Dino.enemies, kind .. "_baby",
                x0 + math.cos(ang) * 1.7, y + math.sin(ang) * 1.5, bd.radius, {
                sprite = bd.sprite, def = bd.def, hp = bd.def, baby = true,
                cx = x0, cy = y,
            })
        end

    elseif kind == "ankylo" then
        local n = 2 + math.floor(r() * 2)
        for i = 1, n do
            add(Dino.enemies, kind, P.x + (i - 1) * 2 - n, P.y - 6, def.radius, {
                sprite = def.sprite, def = def.def, hp = def.def,
                overtaker = true, leadOff = def.lead[1] + i * .8 + r() * 2,
            })
        end

    elseif kind == "dein" then
        if U.chance(.5) then
            -- 横向移动发射羽毛后跑掉
            local side = U.chance(.5) and 1 or -1
            add(Dino.enemies, kind, P:futureX(y) + side * 9, y, def.radius, {
                sprite = def.sprite, def = def.def, hp = def.def,
                vx = -side * 3.2, shooter = true, shootT = .4 + r(),
            })
        else
            -- 正面挡路扭头挑衅，持续发射羽毛
            add(Dino.enemies, kind, P.x + (r() * 2 - 1) * 2, P.y + 5, def.radius, {
                sprite = def.sprite, def = def.def, hp = def.def,
                blocker = true, shootT = 1.2,
            })
        end

    elseif kind == "sauropod" then
        -- 路过蜥脚类（1113 重做）：巨大身影在前方横向穿过、只露腿；
        -- 三只巨脚横向铺满战场，留出窄缝；影子前摇后踩下，踩到即死
        local dir = U.chance(.5) and 1 or -1
        add(Dino.enemies, kind, P.x - dir * 18, P.y + 10, .1, {
            sprite = def.sprite, walk = true, dir = dir,
            legs = {}, stepT = .1, speed = 3.4 + r(),
        })
        fx.shake(.25, .6)

    elseif kind == "ptero" then
        -- 拉屎翼龙：整片战场排好落点，但按行列错峰前摇、落下。
        local c = Config.ptero
        local bombs = {}
        local x0 = P.x - c.width * .5
        local dx = c.width / math.max(1, c.columns - 1)
        local lastAt = 0
        for row = 1, c.rows do
            for col = 1, c.columns do
                local at = .15 + (row - 1) * c.rowStagger
                    + (col - 1) * c.columnStagger
                bombs[#bombs + 1] = {
                    x = x0 + (col - 1) * dx + (r() * 2 - 1) * .35,
                    y = P.y + c.startAhead + (row - 1) * c.rowGap
                        + (r() * 2 - 1) * .25,
                    at = at,
                }
                lastAt = math.max(lastAt, at)
            end
        end
        add(Dino.enemies, kind, P.x - 20, P.y + 9, def.radius, {
            sprite = def.sprite, ptero = true, bombs = bombs, dropClock = 0,
            finishedAt = lastAt + 1.5, speed = c.speed,
        })
        fx.shake(.25, .6)
    end
end

-- ------------------------------------------------------------------ arrows
function Dino.spawnArrow(x, y, sx, sy)
    local a = Config.arrow
    add(Dino.shots, "arrow", x, y, a.radius, {
        sprite = Config.sprites.arrow, vx = sx * a.speed, vy = sy * a.speed,
        -- 箭头是横着画的（默认指向 +x）：逆时针转到速度方向，
        -- 飞行姿态与玩家偏转朝向一致
        rotZ = U.atan2(sy, sx) * U.deg,
    })
end

-- Kill every shootable nuisance within r; returns how many died.
-- Used by mount passives (T-Rex devour / Deinonychus feather fan).
function Dino.killNear(x, y, r, countAsKill)
    local n = 0
    local i = 1
    while i <= #Dino.enemies do
        local e = Dino.enemies[i]
        local dx, dy = e.x - x, e.y - y
        if (e.def or 0) > 0 and dx * dx + dy * dy < (r + e.radius) * (r + e.radius) then
            fx.event("sparkle", e.x, e.y, 1)
            Dino.kills = Dino.kills + (countAsKill ~= false and 1 or 0)
            removeAt(Dino.enemies, i)
            n = n + 1
        else
            i = i + 1
        end
    end
    return n
end

local function hurtEnemy(e)
    e.hp = e.hp - 1
    fx.event("impact", e.x, e.y, .6)
    if e.hp <= 0 then
        Dino.kills = Dino.kills + 1
        fx.sound("coin", .6)
        return true
    end
    return false
end

-- ------------------------------------------------------------------ update
function Dino.update(dt, P, T)
    local cull = P.y - Config.world.cullBack
    local speed = P.speed()

    -- player arrows ---------------------------------------------------
    local i = 1
    while i <= #Dino.shots do
        local s = Dino.shots[i]
        s.t = s.t + dt
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        moveEnt(s)
        -- 射程无限（用户定）：没有飞行时限，飞出世界存在范围才消失
        local dead = math.abs(s.x - P.x) > Config.world.cullX
            or s.y > P.y + 60 or s.y < P.y - Config.world.cullBack
        if not dead then
            for j = #Dino.enemies, 1, -1 do
                local e = Dino.enemies[j]
                if (e.def or 0) > 0 and overlaps(s, e) then
                    if hurtEnemy(e) then removeAt(Dino.enemies, j) end
                    dead = true
                    break
                end
            end
        end
        if dead then removeAt(Dino.shots, i) else i = i + 1 end
    end

    -- enemies ----------------------------------------------------------
    i = 1
    while i <= #Dino.enemies do
        local e = Dino.enemies[i]
        e.t = e.t + dt
        local gone = e.y < cull or e.y > P.y + Config.spawn.ahead + 16
            or math.abs(e.x - P.x) > Config.world.cullX

        if e.walk then
            -- 蜥脚类横穿；脚落在玩家预测路线上（刹车停住也照样被瞄准）
            e.x = e.x + e.speed * e.dir * dt
            e.stepT = e.stepT - dt
            if e.stepT <= 0 then
                local c = Config.sauropod
                e.steps = (e.steps or 0) + 1
                if e.steps <= c.maxSteps then
                    local slot = e.steps
                    local ly = P.y + c.lead + (slot - 1) * c.rowGap
                    local lx = P.x + (c.footOffsetsX[slot] or 0) * e.dir
                    local leg = {
                        x = lx, y = ly, phase = 0, r = c.footRadius,
                        sid = Host.entity.new("footprint", lx, ly, .3),
                    }
                    table.insert(e.legs, leg)
                    Host.entity.setScale(leg.sid, c.shadowScale[1], c.shadowScale[2], 1)
                    e.stepT = c.stepInterval
                else
                    e.stepT = 1e9
                end
            end
            for _, leg in ipairs(e.legs) do
                leg.phase = leg.phase + dt
                if leg.phase > .55 and not leg.stomped then
                    leg.stomped = true
                    if leg.sid and Host.entity.exists(leg.sid) then
                        local c = Config.sauropod
                        Host.entity.setScale(leg.sid, c.footScale[1], c.footScale[2], 1)
                    end
                    fx.shake(.35, .25)
                end
                if leg.stomped and leg.phase < 1.0 and P.alive
                    and P.flyT <= 0 then
                    local dx, dy = leg.x - P.x, leg.y - P.y
                    if dx * dx + dy * dy < leg.r * leg.r then
                        -- 被踩到：游戏结束
                        P:hurt(true, "Stomped flat by a passing sauropod.")
                    end
                end
                if leg.phase > 1.3 and leg.sid then
                    if Host.entity.exists(leg.sid) then Host.entity.kill(leg.sid) end
                    leg.sid = nil
                end
            end
            gone = gone or math.abs(e.x - P.x) > 20

        elseif e.ptero then
            -- 翼影掠过；落点全部预先排程，但影子/粪便逐批出现。
            local c = Config.ptero
            e.x = e.x + e.speed * dt
            e.y = P.y + 9
            if Host.entity.exists(e.id) then
                Host.entity.setPos(e.id, e.x, e.y, -.6)
            end
            e.dropClock = e.dropClock + dt
            for i = 1, #e.bombs do
                local spot = e.bombs[i]
                if not spot.sid and not spot.dropped
                    and e.dropClock >= spot.at - c.shadowLead then
                    spot.sid = Host.entity.new("shadow", spot.x, spot.y, .3)
                    Host.entity.setScale(spot.sid, 2.2, 1.4, 1)
                end
                if not spot.dropped and e.dropClock >= spot.at then
                    if spot.sid and Host.entity.exists(spot.sid) then
                        Host.entity.kill(spot.sid)
                    end
                    spot.sid = nil
                    spot.dropped = true
                    local s = {
                        kind = "poop", x = spot.x, y = spot.y,
                        radius = c.radius, t = 0, life = c.poopLife,
                        id = Host.entity.new("poop", spot.x, spot.y, 0),
                    }
                    local sz = c.radius * 1.6
                    Host.entity.setScale(s.id, sz, sz, 1)
                    table.insert(Dino.their, s)
                    fx.event("splash", spot.x, spot.y, .5)
                end
            end
            gone = e.dropClock >= e.finishedAt

        elseif e.chase then
            -- T-Rex: accelerates from behind unless you keep steering;
            -- stops on blocking obstacles, gulps other nuisance dinos.
            e.life = e.life - dt
            -- "若保持方向不变，速度越来越快"（1.2.6）：ramp 计的是玩家
            -- 停留在同一档朝向上的时长，换档（A/D/W/转向灌木）即重置
            if P.heading ~= e.lastH then
                e.steerT = 0
                e.lastH = P.heading
            end
            e.steerT = e.steerT + dt
            local ramp = math.min(1, e.steerT / Data.enemies.trex.rampTime)
            -- 1113：整体放慢，配合大视野留反应时间
            e.y = e.y + (speed * (.45 + .5 * ramp) + .5) * dt
            e.x = e.x + U.clamp((P.x - e.x) * 2.2, -4, 4) * dt
            if e.life <= 0 then gone = true; fx.sound("crash", .4) end
            -- hits a blocking obstacle: loses interest
            local hitBlock = blockingAt(T, e.x, e.y + 1)
            if hitBlock then
                gone = true
                fx.event("impact", e.x, e.y, 1.2)
                fx.shake(.25, .3)
            end
            -- eats other nuisance dinos on its path
            for j = #Dino.enemies, 1, -1 do
                local o = Dino.enemies[j]
                if o ~= e and not o.walk and not o.ptero and not o.chase then
                    local dx, dy = o.x - e.x, o.y - e.y
                    if dx * dx + dy * dy < 3.2 then
                        fx.event("impact", o.x, o.y, .8)
                        removeAt(Dino.enemies, j)
                    end
                end
            end
            if P.alive and P.flyT <= 0 and e.y > P.y - .6 and
                math.abs(e.x - P.x) < e.radius + P.radius then
                P:hurt(true, "The chasing T-Rex caught you.")   -- 一口吞掉
            end

        elseif e.overtaker then
            -- Ankylosaurus herd: overtake, then sit in front, mirror steering,
            -- dodge blocking obstacles.
            -- 1113：超车与跟随都放慢（原来太快来不及反应）
            -- 追击使用自己的巡航速度，玩家按 S 或受到减速不会拖住它。
            local pursuitSpeed = P.cruiseSpeed()
            local targetY = P.y + e.leadOff
            if e.y < targetY then
                e.y = e.y + (pursuitSpeed * 1.05) * dt
            else
                e.y = e.y + pursuitSpeed * dt
                e.x = e.x + U.clamp((P.x - e.x) * 1.2, -2.2, 2.2) * dt
            end
            local ahead = blockingAt(T, e.x, e.y + 1.4)
            if ahead then
                local away = (e.x >= P.x) and 1 or -1
                e.x = e.x + away * 2.4 * dt
            end

        elseif e.blocker or e.shooter then
            if e.blocker then
                e.y = P.y + 5
                e.x = e.x + U.clamp((P.x - e.x) * 1.4, -3, 3) * dt
                local ahead = blockingAt(T, e.x, e.y + 1.2)
                if ahead then e.x = e.x + ((e.x >= P.x) and 1 or -1) * 2 * dt end
            else
                e.x = e.x + e.vx * dt
            end
            e.shootT = e.shootT - dt
            if e.shootT <= 0 then
                e.shootT = e.blocker and 1.6 or 2.4
                -- 扇形三枚羽毛子弹
                for f = -1, 1 do
                    local ang = U.atan2(P.y - e.y, P.x - e.x) + f * .22
                    add(Dino.their, "feather", e.x, e.y, .4, {
                        sprite = "feather", vx = math.cos(ang) * 6.5,
                        vy = math.sin(ang) * 6.5, life = 1.6,
                    })
                end
                fx.sound("tick", .35)
            end
            if e.shooter and not e.blocker then e.y = e.y - 1 * dt end

        elseif e.baby then
            -- 幼体：玩家进窝才整窝同时炸开，沿"离窝心"方向猛冲（1113 加强）
            if not e.fled and U.dist(e.x, e.y, P.x, P.y) < Data.enemies.para.scatterR then
                e.fled = true
            end
            if e.fled and not e.vx then
                local ax, ay = e.x - (e.cx or e.x), e.y - (e.cy or e.y)
                local ang = U.atan2(ay, ax) + (math.random() * 2 - 1) * .5
                e.vx, e.vy = math.cos(ang) * 7, math.sin(ang) * 7
            end
            if e.fled then e.x = e.x + e.vx * dt; e.y = e.y + e.vy * dt end

        elseif e.still then
            -- adults just stand; nothing to update

        elseif e.charge then
            -- 三角龙：路径偏纵、几乎不跟人（1113：与横移的似鸟龙区分）
            e.y = e.y + e.vy * dt
            e.x = e.x + U.clamp((P.x - e.x) * .3, -.6, .6) * dt

        else
            if e.vx then e.x = e.x + e.vx * dt end
            if e.vy then e.y = e.y + e.vy * dt end
        end

        if e.walk or e.ptero then
            moveEnt(e)
        elseif not gone then
            moveEnt(e)
        end

        -- contact damage (chase/walk/ptero handled above; sleepMount = 睡着的
        -- 骑乘龙，可射杀但本身无害，1113)
        if P.alive and not gone and not e.chase and not e.walk and not e.ptero
            and not e.sleepMount
            and P.airborneT <= 0 and P.flyT <= 0 then
            if overlaps(e, P) then
                if P.chargeT > 0 and (e.def or 0) > 0 then
                    -- 三角龙/甲龙冲锋：撞飞可击杀的恐龙
                    Dino.kills = Dino.kills + 1
                    fx.event("impact", e.x, e.y, 1)
                    removeAt(Dino.enemies, i)
                    goto continue
                elseif P.chargeT > 0 then
                    P:hurt(false)
                else
                    P:hurt(false)
                end
            end
        end

        if gone then removeAt(Dino.enemies, i) else i = i + 1 end
        ::continue::
    end

    -- enemy projectiles ------------------------------------------------
    i = 1
    while i <= #Dino.their do
        local s = Dino.their[i]
        s.t = s.t + dt
        if s.vx then
            s.x = s.x + s.vx * dt
            s.y = s.y + s.vy * dt
        end
        moveEnt(s)
        local dead = s.t > s.life
        if not dead and P.alive and P.airborneT <= 0 and P.flyT <= 0
            and overlaps(s, P) then
            P:hurt(false)
            dead = true
        end
        if dead then removeAt(Dino.their, i) else i = i + 1 end
    end
end

function Dino.clear()
    for i = #Dino.shots, 1, -1 do removeAt(Dino.shots, i) end
    for i = #Dino.their, 1, -1 do removeAt(Dino.their, i) end
    for i = #Dino.enemies, 1, -1 do removeAt(Dino.enemies, i) end
    Dino.kills = 0
end

function Dino.reset()
    Dino.clear()
end

function Dino.countEnemies()
    return #Dino.enemies
end

return Dino
