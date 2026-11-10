-- Player: the design-doc runner (1.2.1/1.2.2/1.2.3/1.2.5 effects).
--
-- Movement is discrete: five heading states (左/微左/中/微右/右). The dinosaur
-- always cruises forward automatically; A/D step the heading one state, W
-- snaps back to 中. A hit costs a heart, stops the run and puts the player in
-- a short invulnerable stun that any A/W/D press resumes (the press also
-- steers, per 1.2.2).
local Config = require("dino_config")
local Dino = require("dino_dinos")
local I = require("input")
local U = require("util")

local H = Config.heading
local R = Config.run
local E = Config.effects
local A = Config.arrow

local function fxSound(name, vol)
    if Host.audio and Host.audio.play then Host.audio.play(name, vol or 1) end
end

local P = {
    x = 0, y = 0,
    heading = 0,
    distance = 0, eggs = 0,
    hp = R.hpMax,
    radius = Config.player.radius,
    alive = true,

    -- status timers
    invulnT = 0, stunned = false,
    slowT = 0, boostT = 0, confuseT = 0,
    airborneT = 0, airMax = 0, flyT = 0, flyMax = 0,
    chargeT = 0, boostSkillT = 0, boostSkillMul = 1, pushT = 0,
    effectCd = 0,

    -- archery (1.2.3)
    arrows = A.max, arrowT = 0,

    -- mount-facing state written by dino_mount
    mountMul = 1,
    spriteSet = { run = { "dino_run0", "dino_run1" }, idle = "dino_idle" },

    id = nil, shadowId = nil, riderId = nil,
    animT = 0, frame = 0, spriteName = nil,
    cam = { x = 0, y = Config.camera.yOffset, size = Config.camera.size },
}

-- ------------------------------------------------------------------ speed
local function cruise()
    local ramp = 1 + R.rampStep * (P.distance / R.rampDist)
    return R.speed0 * math.min(R.rampMax, ramp)
end

local function currentSpeed()
    if P.stunned then return 0 end
    local mul = P.mountMul
    if P.slowT > 0 then mul = mul * E.slowMul end
    if P.boostT > 0 then mul = mul * E.boostMul end
    if P.boostSkillT > 0 then mul = mul * P.boostSkillMul end
    if P.pushT > 0 then mul = mul * E.jumpPush end
    return cruise() * mul
end

local function headingAngle()
    return H.angleDeg[P.heading] or 0
end

function P.speed()
    return currentSpeed()
end

-- Predicted x when the world ahead reaches distance y: project exactly along
-- the current heading, but never anchor a row more than anchorLimit sideways
-- from the player (so it stays inside the existence-cull band and reachable
-- by the time the player gets there). No walls anywhere: this only bounds
-- where content spawns relative to you, not where you can walk.
function P:futureX(y)
    local tan = math.tan(headingAngle() * U.rad)
    local lim = Config.spawn.anchorLimit
    local x = P.x + tan * math.max(0, y - P.y)
    return U.clamp(x, P.x - lim, P.x + lim)
end

-- ------------------------------------------------------------------ camera
local function cameraTarget()
    local run = math.min(1, currentSpeed() / (R.speed0 * R.rampMax))
    return P.x, P.y + Config.camera.yOffset, Config.camera.size - Config.camera.zoomRun * run
end

local function cameraSnap()
    P.cam.x, P.cam.y, P.cam.size = cameraTarget()
    Host.camera.set2d(P.cam.x, P.cam.y, P.cam.size)
end

local function cameraFollow(dt)
    local tx, ty, ts = cameraTarget()
    P.cam.x = U.lerp(P.cam.x, tx, U.expSmooth(Config.camera.followRate, dt))
    P.cam.y = U.lerp(P.cam.y, ty, U.expSmooth(Config.camera.followRate, dt))
    P.cam.size = U.lerp(P.cam.size, ts, U.expSmooth(Config.camera.sizeLerp, dt))
    Host.camera.set2d(P.cam.x, P.cam.y, P.cam.size)
end

function P.syncVisual()
    if P.id then Host.entity.setPos(P.id, P.x, P.y, 0) end
    if P.shadowId then Host.entity.setPos(P.shadowId, P.x, P.y + .04, .2) end
    if P.riderId then Host.entity.setPos(P.riderId, P.x, P.y + .85, -.1) end
    cameraSnap()
end

-- ------------------------------------------------------------------ heading
local function setSprite(name)
    if P.spriteName == name then return end
    P.spriteName = name
    if P.id then Host.entity.setSprite(P.id, name) end
end

local function turn(dir)
    P.heading = U.clamp(P.heading + dir, H.min, H.max)
end

function P.clear()
    for _, k in ipairs({ "id", "shadowId", "riderId" }) do
        if P[k] then Host.entity.kill(P[k]); P[k] = nil end
    end
    P.spriteName = nil
end

function P.reset()
    P.x, P.y = 0, 0
    P.heading = 0
    P.distance, P.eggs = 0, 0
    P.hp = R.hpMax
    P.alive = true
    P.deathReason = nil
    P.invulnT, P.stunned = 0, false
    P.slowT, P.boostT, P.confuseT = 0, 0, 0
    P.airborneT, P.airMax, P.flyT, P.flyMax, P.chargeT = 0, 0, 0, 0, 0
    P.boostSkillT, P.boostSkillMul, P.pushT = 0, 1, 0
    P.effectCd = 0
    P.arrows, P.arrowT = A.max, 0
    P.mountMul = 1
    P.animT, P.frame = 0, 0
    P.spriteName = nil
    P.onShield = nil

    P.clear()
    P.shadowId = Host.entity.new(Config.sprites.shadow, P.x, P.y + .04, .2)
    Host.entity.setScale(P.shadowId, 1.05, .9, 1)
    P.id = Host.entity.new(P.spriteSet.idle, P.x, P.y, 0)
    Host.entity.setScale(P.id, 1.08, 1.08, 1)
    P.riderId = Host.entity.new(Config.sprites.rider, P.x, P.y + .85, -.1)
    cameraSnap()
    setSprite(P.spriteSet.idle)
end

function P.setMountSprites(set)
    P.spriteSet = set
end

-- A pressed: one step left. D pressed: one step right. W: snap to 中.
-- While stunned the first A/W/D press also resumes movement (1.2.2).
local function steerEdge()
    local l, r = I.left(), I.right()
    if P.confuseT > 0 then l, r = r, l end   -- 蘑菇丛：按键效果对调
    if l then P:inputTurn(-1); return true end
    if r then P:inputTurn(1); return true end
    if I.up() then P:inputCenter(); return true end
    return false
end

function P:inputTurn(dir)
    if P.stunned then P:resume() end
    turn(dir)
end

function P:inputCenter()
    if P.stunned then P:resume() end
    P.heading = 0
end

function P.resume()
    P.stunned = false
end

-- 转向型障碍（1.2.5 (4)）：左/微左 ↔ 右/微右；"中"→随机非中（偏向微转）
function P.forceTurn()
    if P.heading == 0 then
        P.heading = U.pick({ { -1, 5 }, { 1, 5 }, { -2, 1 }, { 2, 1 } })
    else
        P.heading = -P.heading
    end
end

-- ------------------------------------------------------------------ damage
-- Returns "died", "hurt" or "blocked". Lethal sources (T-Rex bite, sauropod
-- stomp) always end the run. Airborne/flying ignores non-lethal hits
-- (1.2.5 (6): 滞空期间无视一切障碍).
function P:hurt(lethal, reason)
    if not P.alive then return "blocked" end
    if not lethal and (P.invulnT > 0 or P.airborneT > 0 or P.flyT > 0) then
        return "blocked"
    end
    -- 鸭嘴龙的崽挡刀（hook installed by dino_mount）
    if not lethal and P.onShield and P.onShield() then return "blocked" end
    P.hp = P.hp - 1
    if P.hp <= 0 or lethal then
        P.hp = 0
        P.alive = false
        P.deathReason = reason or "You hit an obstacle."
        return "died"
    end
    P.invulnT = R.invuln
    P.stunned = true
    return "hurt"
end

-- 伤害无敌持续到本次碰撞判定结束：track 在玩家仍与障碍物重叠时延长它
function P:extendInvuln(t)
    if P.invulnT < t then P.invulnT = t end
end

function P:kill()
    P.hp = 0
    P.alive = false
end

-- ------------------------------------------------------------------ effects
local function canEffect()
    return P.effectCd <= 0 and P.airborneT <= 0 and P.flyT <= 0
end

function P:applyEffect(kind)
    if not canEffect() then return false end
    P.effectCd = E.reuseCd
    if kind == "slow" then P.slowT = E.slowDur
    elseif kind == "boost" then P.boostT = E.boostDur
    elseif kind == "confuse" then P.confuseT = E.confuseDur
    elseif kind == "turn" then P:forceTurn()
    elseif kind == "jump" then P:airborne(E.jumpDur, true)
    end
    return true
end

function P:airborne(dur, push)
    P.airborneT = dur
    P.airMax = dur
    if push then P.pushT = dur end
end

function P:fly(dur)
    P.flyT = dur
    P.flyMax = dur
end

function P:charge(dur)
    P.chargeT = dur
end

function P:boostSkill(dur, mul)
    P.boostSkillT = dur
    P.boostSkillMul = mul or 2.2
end

-- ------------------------------------------------------------------ archery
function P:shoot()
    if P.stunned or not P.alive then return false end
    if P.arrows < 1 then return false end
    P.arrows = P.arrows - 1
    if P.arrows == A.max - 1 then P.arrowT = A.regen end
    local a = headingAngle() * U.rad
    Dino.spawnArrow(P.x, P.y + .4, math.sin(a), math.cos(a))
    return true
end

function P:collectEgg()
    P.eggs = P.eggs + 1
end

function P:heal()
    if P.hp < R.hpMax then P.hp = P.hp + 1 end
end

-- ------------------------------------------------------------------ update
function P.update(dt)
    if not P.alive then return end

    -- steer / shoot edges
    steerEdge()
    if I.shoot() then
        if P:shoot() then fxSound(Config.juice.shootSound, .5) end
    end

    -- timers
    local dec = function(t) return math.max(0, t - dt) end
    P.invulnT = dec(P.invulnT)
    P.slowT = dec(P.slowT)
    P.boostT = dec(P.boostT)
    P.confuseT = dec(P.confuseT)
    P.airborneT = dec(P.airborneT)
    P.flyT = dec(P.flyT)
    P.chargeT = dec(P.chargeT)
    P.boostSkillT = dec(P.boostSkillT)
    P.pushT = dec(P.pushT)
    P.effectCd = dec(P.effectCd)
    if P.stunned then P.invulnT = math.max(P.invulnT, .3) end

    -- arrow regen (max 3 stored)
    if P.arrows < A.max then
        P.arrowT = P.arrowT - dt
        if P.arrowT <= 0 then
            P.arrows = P.arrows + 1
            P.arrowT = A.regen
        end
    else
        P.arrowT = A.regen
    end

    -- auto-forward along the heading state
    local speed = currentSpeed()
    local a = headingAngle() * U.rad
    P.x = P.x + speed * math.sin(a) * dt
    P.y = P.y + speed * math.cos(a) * dt
    if P.y < 0 then P.y = 0 end
    P.distance = P.distance + speed * dt

    -- animation (frozen while stunned)
    if speed > .1 then
        P.animT = P.animT + dt
        local rate = Config.player.animRate
        if P.animT >= rate then
            P.animT = P.animT - rate
            P.frame = (P.frame + 1) % #P.spriteSet.run
            setSprite(P.spriteSet.run[P.frame + 1])
        end
    end

    -- visual state: tilt to the heading, jump arc, invuln blink
    local tilt = -headingAngle()
    local flying = P.flyT > 0
    local air = math.max(P.airborneT, P.flyT)
    local airScale = 1
    if air > 0 then
        if flying then
            airScale = 1.4
        else
            local prog = 1 - P.airborneT / math.max(.001, P.airMax)
            airScale = 1 + .45 * math.sin(math.pi * U.clamp01(prog))
        end
    end
    if P.id then
        Host.entity.setPos(P.id, P.x, P.y + (air > 0 and .5 or 0), -0.2)
        Host.entity.setRot(P.id, 0, 0, tilt)
        Host.entity.setScale(P.id, 1.08 * airScale, 1.08 * airScale, 1)
        Host.entity.setVisible(P.id, P.invulnT <= 0
            or math.floor(Host.time() / R.blinkRate) % 2 == 0)
    end
    if P.riderId then
        Host.entity.setPos(P.riderId, P.x, P.y + .85 + (air > 0 and .5 or 0), -.3)
        Host.entity.setRot(P.riderId, 0, 0, tilt * .5)
        Host.entity.setScale(P.riderId, .8 * airScale, .8 * airScale, 1)
    end
    if P.shadowId then
        Host.entity.setPos(P.shadowId, P.x, P.y + .04, .2)
        local shrink = air > 0 and .6 or 1
        local stretch = 1.0 + math.min(.25, speed * .02)
        Host.entity.setScale(P.shadowId, 1.05 * stretch * shrink, .9 * shrink, 1)
    end

    cameraFollow(dt)
end

-- Title-screen breathing (keeps the default mount sprite alive looking busy).
function P.idleAnim(dt)
    P.animT = P.animT + dt
    if P.animT >= .45 then
        P.animT = 0
        P.frame = (P.frame + 1) % #P.spriteSet.run
        setSprite(P.spriteSet.run[P.frame + 1])
    end
    if P.id then Host.entity.setRot(P.id, 0, 0, 0) end
    P.syncVisual()
end

function P.stop()
    P.stunned = true
    setSprite(P.spriteSet.idle)
end

return P
