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
    gen = 0,          -- bumped on clear so delayed spawns know they are stale
}

-- ------------------------------------------------------------------ helpers
local function add(list, kind, x, y, radius, data)
    local d = data or {}
    d.kind = kind
    d.x, d.y = x, y
    d.radius = radius
    d.t = d.t or 0
    d.id = Host.entity.new(d.sprite or kind, x, y, 0)
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
    if it.id and Host.entity.exists(it.id) then Host.entity.kill(it.id) end
    if it.shadowId and Host.entity.exists(it.shadowId) then Host.entity.kill(it.shadowId) end
    table.remove(list, i)
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
        if U.chance(.5) then
            -- 闲逛的：单只横向(或斜向)溜达
            local side = U.chance(.5) and 1 or -1
            add(Dino.enemies, kind, P.x + side * 10, y, def.radius, {
                sprite = def.sprite, def = def.def, hp = def.def,
                vx = -side * (r() < .5 and 2.2 or 4),
                vy = U.chance(.4) and -1.2 or 0,
            })
        else
            -- 连绵一排：需要射开缺口穿过
            local n = 5 + math.floor(r() * 3)
            local x0 = P.x - n * .8
            for i = 1, n do
                add(Dino.enemies, kind, x0 + (i - 1) * 1.6, y, def.radius, {
                    sprite = def.sprite, def = def.def, hp = def.def,
                    vx = -2.4, wall = true,
                })
            end
        end

    elseif kind == "trike" then
        local pack = U.chance(.4) and 3 or 1
        for i = 1, pack do
            add(Dino.enemies, kind, P.x + (i - 1) * 1.8 - pack * .9,
                y + 6 + i * 1.5, def.radius, {
                sprite = def.sprite, def = def.def, hp = def.def,
                charge = true, vy = -(3.2 + r()), vx = 0,
            })
        end

    elseif kind == "trex" then
        -- 追逐的暴龙：从身后出现，越追越快
        add(Dino.enemies, kind, P.x, P.y - 8, def.radius, {
            sprite = def.sprite, def = 0, chase = true,
            life = def.dwell, vx = 0,
            scale = 1.6,
        })
        fx.shake(.15, .3)

    elseif kind == "para" then
        -- 带崽的鸭嘴龙：成体杵着，幼体在判定范围内四散
        local x0 = P.x + (r() * 2 - 1) * 3
        for i = 1, 2 do
            add(Dino.enemies, kind, x0 + (i - 1) * 1.6 - .8, y, def.radius, {
                sprite = def.sprite, def = def.def, hp = def.def, still = true,
            })
        end
        local bd = def.babies
        add(Dino.enemies, kind .. "_baby", x0 + 1.1, y + 1.2, bd.radius, {
            sprite = bd.sprite, def = bd.def, hp = bd.def, baby = true,
        })

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
            add(Dino.enemies, kind, P.x + side * 9, y, def.radius, {
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
        -- 路过蜥脚类：影子前摇 -> 大脚落下（踩到即死）
        local dir = U.chance(.5) and 1 or -1
        add(Dino.enemies, kind, P.x - dir * 10, P.y + 2, .1, {
            sprite = def.sprite, walk = true, dir = dir,
            legs = {}, stepT = 0, side = dir,
        })

    elseif kind == "ptero" then
        -- 拉屎翼龙：翼影掠过 -> 大便影子 -> 一串落下
        local line = {}
        local n = 4 + math.floor(r() * 3)
        local x0 = P.x + (r() * 2 - 1) * 3
        for i = 1, n do
            line[i] = { x = x0 + (i - 1) * 1.15, y = P.y + 4 + i * 1.3 }
        end
        add(Dino.enemies, kind, P.x - 8, P.y + 6, .1, {
            sprite = def.sprite, ptero = true, line = line, dropT = .9,
            dir = 1,
        })
    end
end

-- ------------------------------------------------------------------ arrows
function Dino.spawnArrow(x, y, sx, sy)
    local a = Config.arrow
    add(Dino.shots, "arrow", x, y, a.radius, {
        sprite = Config.sprites.arrow, vx = sx * a.speed, vy = sy * a.speed,
        life = a.life, rotZ = -math.atan2(sy, sx) * U.deg + 90,
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
        local dead = s.t > s.life
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
            or math.abs(e.x - P.x) > 24

        if e.walk then
            -- sauropod legs crossing the plain
            e.x = e.x + e.dir * 2.6 * dt
            e.stepT = e.stepT - dt
            if e.stepT <= 0 then
                e.stepT = .85
                local g = Dino.gen
                table.insert(e.legs, { x = e.x, y = e.y - 2 + math.random() * 5,
                                       phase = 0, r = 1.1 + math.random() * .4, gen = g,
                                       -- 影子前摇：先出现脚印状的影子，然后脚落下
                                       sid = Host.entity.new("footprint", e.x,
                                            e.y - 2, .3) })
                Host.entity.setScale(e.legs[#e.legs].sid, 1.4, 2.2, 1)
                if #e.legs > 6 then
                    local old = table.remove(e.legs, 1)
                    if old.sid and Host.entity.exists(old.sid) then Host.entity.kill(old.sid) end
                end
            end
            for _, leg in ipairs(e.legs) do
                leg.phase = leg.phase + dt
                if leg.phase > .45 and not leg.stomped then
                    leg.stomped = true
                    if leg.sid and Host.entity.exists(leg.sid) then
                        Host.entity.setScale(leg.sid, 2.4, 3.4, 1)
                    end
                    fx.shake(.3, .25)
                end
                if leg.phase > .45 and leg.phase < .85 and P.alive
                    and P.flyT <= 0 then
                    local dx, dy = leg.x - P.x, leg.y - P.y
                    if dx * dx + dy * dy < leg.r * leg.r then
                        -- 被踩到：游戏结束
                        P:hurt(true, "Stomped flat by a passing sauropod.")
                    end
                end
                if leg.phase > 1.1 and leg.sid then
                    if Host.entity.exists(leg.sid) then Host.entity.kill(leg.sid) end
                    leg.sid = nil
                    leg.done = true
                end
            end
            gone = gone or math.abs(e.x - P.x) > 14

        elseif e.ptero then
            -- wing shadow sweeps past, then a line of droppings
            e.x = e.x + 6 * dt
            if Host.entity.exists(e.id) then Host.entity.setPos(e.id, e.x, P.y + 7, -.6) end
            e.dropT = e.dropT - dt
            if e.dropT <= 0 then
                e.dropT = 9
                local g = Dino.gen
                for k, spot in ipairs(e.line) do
                    fx.after(.12 * k, function()
                        if Dino.gen ~= g then return end   -- run ended meanwhile
                        local s = { kind = "poop", x = spot.x, y = spot.y,
                                    radius = .45, t = 0, life = 2.6,
                                    id = Host.entity.new("poop", spot.x, spot.y, 0) }
                        table.insert(Dino.their, s)
                        fx.event("splash", spot.x, spot.y, .5)
                    end, "poop" .. k)
                end
            end
            gone = gone or e.x > P.x + 12

        elseif e.chase then
            -- T-Rex: accelerates from behind unless you keep steering;
            -- stops on blocking obstacles, gulps other nuisance dinos.
            e.life = e.life - dt
            local ramp = math.min(1, e.t / Data.enemies.trex.rampTime)
            e.y = e.y + (speed * (.55 + .7 * ramp) + .6) * dt
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
            local targetY = P.y + e.leadOff
            if e.y < targetY then
                e.y = e.y + (speed * 1.45) * dt
            else
                e.y = e.y + speed * dt
                e.x = e.x + U.clamp((P.x - e.x) * 1.6, -3.5, 3.5) * dt
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
                    local ang = math.atan2(P.y - e.y, P.x - e.x) + f * .22
                    add(Dino.their, "feather", e.x, e.y, .4, {
                        sprite = "feather", vx = math.cos(ang) * 6.5,
                        vy = math.sin(ang) * 6.5, life = 1.6,
                    })
                end
                fx.sound("tick", .35)
            end
            if e.shooter and not e.blocker then e.y = e.y - 1 * dt end

        elseif e.baby then
            -- 幼体：进入判定范围后突然快速四散跑开
            if not e.fled and U.dist(e.x, e.y, P.x, P.y) < Data.enemies.para.scatterR then
                e.fled = true
                local ang = math.random() * U.tau
                e.vx, e.vy = math.cos(ang) * 5.5, math.sin(ang) * 5.5
            end
            if e.fled then e.x = e.x + e.vx * dt; e.y = e.y + e.vy * dt end

        elseif e.still then
            -- adults just stand; nothing to update

        elseif e.charge then
            -- 三角龙：纵向（或略微倾斜）冲向玩家
            e.y = e.y + e.vy * dt
            e.x = e.x + U.clamp((P.x - e.x) * .8, -1.6, 1.6) * dt

        else
            if e.vx then e.x = e.x + e.vx * dt end
            if e.vy then e.y = e.y + e.vy * dt end
        end

        if e.walk or e.ptero then
            moveEnt(e)
        elseif not gone then
            moveEnt(e)
        end

        -- contact damage (chase/walk/ptero handled above)
        if P.alive and not gone and not e.chase and not e.walk and not e.ptero
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
    fx.cancel("poop")
    for k = 1, 12 do fx.cancel("poop" .. k) end
end

function Dino.reset()
    Dino.clear()
end

function Dino.countEnemies()
    return #Dino.enemies
end

return Dino
