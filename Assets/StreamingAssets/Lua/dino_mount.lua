-- DINO IMPACT - riding and dinosaur skills (design doc 1.2.7).
--
-- Sleeping dinosaurs dot the plain (placed by dino_track). They never hurt
-- the player - walking into one just passes it. Entering C.mount.range shows
-- the rope prompt from any direction; J leaps onto it: the new dinosaur bolts
-- forward, the old one is left standing in place until it leaves the view.
-- Space fires the current dinosaur's skill (uses reset by energy fruit or by
-- mounting another dinosaur).
local Config = require("dino_config")
local Data = require("dino_data")
local Dino = require("dino_dinos")
local I = require("input")
local U = require("util")
local fx = require("fx")

local M = {
    current = { key = "comps", uses = 1 },
    mountCount = 0,
    prompt = nil,        -- sleeping dino currently mountable (UI reads this)
    strays = {},         -- abandoned dinosaurs, left in place
    chicks = {},         -- parasaur baby entities (visual only)
    fanT = 0,
}

local function info() return Data.mounts[M.current.key] end

function M.info()
    local d = info()
    return { key = M.current.key, label = d.label, uses = M.current.uses, usesMax = d.uses }
end

local function applyMount(key, P)
    local d = Data.mounts[key]
    M.current = { key = key, uses = d.uses }
    P.mountMul = d.speedMul
    P.setMountSprites({ run = d.run, idle = d.idle })
    if P.id then Host.entity.setSprite(P.id, d.idle) end
    -- 鸭嘴龙：崽替玩家挡刀（1.2.7 护盾），"次数"即崽数
    if d.passive == "shield" then
        P.onShield = function()
            if M.current.uses > 0 then
                M.current.uses = M.current.uses - 1
                fx.event("impact", P.x, P.y, .8)
                fx.sound("crash", .5)
                return true
            end
            return false
        end
    else
        P.onShield = nil
    end
end

function M.reset(P)
    M.mountCount = 0
    M.prompt = nil
    M.fanT = 0
    for i = #M.strays, 1, -1 do
        if Host.entity.exists(M.strays[i]) then Host.entity.kill(M.strays[i]) end
        table.remove(M.strays, i)
    end
    M.syncChicks(P, true)
    applyMount("comps", P)   -- 开局默认骑乘一只似鸟龙
end

-- 能量果实：重置当前骑乘恐龙的技能次数（1.2.4 (2)）
function M.onFruit(kind)
    if kind == "fruit_energy" then
        M.current.uses = info().uses
        fx.sound("boost", .6)
    end
end

-- ------------------------------------------------------------------ skills
function M.useSkill(P)
    local d = info()
    if M.current.uses <= 0 or not d.active then return false end
    M.current.uses = M.current.uses - 1
    fx.sound(Config.juice.skillSound, .8)
    if d.active == "boost" then
        P:boostSkill(d.boostDur, d.boostMul)
        fx.event("boost", P.x, P.y, 1)
    elseif d.active == "charge" then
        P:charge(d.chargeDur)
        fx.shake(.12, .2)
    elseif d.active == "jump" then
        P:airborne(d.jumpDur, true)
        fx.event("splash", P.x, P.y, .7)
    elseif d.active == "fly" then
        P:fly(d.flyDur)
        fx.event("boost", P.x, P.y, 1.2)
    end
    return true
end

local function passives(dt, P)
    local d = info()
    if d.passive == "devour" then
        -- 靠近可被击杀的恐龙时直接一口吞掉
        Dino.killNear(P.x, P.y + .6, d.devourR, true)
    elseif d.passive == "fan" then
        M.fanT = M.fanT - dt
        if M.fanT <= 0 then
            M.fanT = d.fanCd
            -- 伤害等同一支箭，不是秒杀（1.2.7）：高防御敌龙能扛住一轮弹幕
            local n = Dino.damageNear(P.x, P.y + 3, d.fanR, 1, true)
            if n > 0 then fx.sound("tick", .5) end
        end
    end
end

-- ------------------------------------------------------------------ chicks
function M.syncChicks(P, force)
    local d = info()
    local want = (d.passive == "shield") and M.current.uses or 0
    if force then
        for i = #M.chicks, 1, -1 do
            if Host.entity.exists(M.chicks[i]) then Host.entity.kill(M.chicks[i]) end
            table.remove(M.chicks, i)
        end
    end
    while #M.chicks < want do
        M.chicks[#M.chicks + 1] = Host.entity.new("enemy_para_baby", 0, -100, 0)
    end
    while #M.chicks > want do
        local c = table.remove(M.chicks)
        if Host.entity.exists(c) then Host.entity.kill(c) end
    end
    for i = 1, #M.chicks do
        local side = (i % 2 == 1) and -1 or 1
        Host.entity.setPos(M.chicks[i], P.x + side * .9 * math.ceil(i / 2), P.y - .5, .1)
    end
end

-- ------------------------------------------------------------------ update
function M.update(dt, P, T)
    -- rope prompt: pure proximity (设计调整) - within C.mount.range the
    -- nearest sleeping dinosaur is mountable, from any heading, even behind.
    M.prompt = nil
    if P.alive then
        local near = T.findMountsNear(P.x, P.y, Config.mount.range)
        local best, bestD = nil, nil
        for i = 1, #near do
            local it = near[i]
            local d = U.dist2(it.x, it.y, P.x, P.y)
            if not bestD or d < bestD then best, bestD = it, d end
        end
        M.prompt = best
    end

    -- J: mount
    if M.prompt and I.mount() then
        local it = M.prompt
        -- 旧恐龙留在原地，逐渐退出视野
        local dOld = Data.mounts[M.current.key]
        M.strays[#M.strays + 1] = Host.entity.new(dOld.idle, P.x, P.y, 0)
        T.removeMount(it)
        applyMount(it.kind, P)
        M.mountCount = M.mountCount + 1
        M.prompt = nil
        P.invulnT = math.max(P.invulnT, .5)
        fx.sound(Config.juice.mountSound, .8)
        fx.event("boost", P.x, P.y, 1)
    end

    -- Space: skill
    if I.skill() then M.useSkill(P) end

    passives(dt, P)
    M.syncChicks(P, false)

    -- cull abandoned dinosaurs once they are far behind
    local i = 1
    while i <= #M.strays do
        local id = M.strays[i]
        local _, sy = Host.entity.getPos(id)
        if not Host.entity.exists(id) or sy < P.y - Config.world.cullBack then
            if Host.entity.exists(id) then Host.entity.kill(id) end
            table.remove(M.strays, i)
        else
            i = i + 1
        end
    end
end

return M
