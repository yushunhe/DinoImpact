-- The surfer. Arcade physics, no rigidbodies: heading + speed on an analytic sea.
local Config = require("config")
local U = require("util")
local I = require("input")
local W = require("world")

local P = {
    x = 0, z = 0, y = 0,
    heading = 0,
    speed = 0,
    vy = 0,
    grounded = true,
    airTime = 0,
    spin = 0,
    spinTotal = 0,
    distance = 0,
    lives = 3,
    tokens = 0,
    coinScore = 0,
    trickScore = 0,
    gateScore = 0,
    boostScore = 0,
    boostCharges = 0,
    boostTime = 0,
    invuln = 0,
    stun = 0,
    wipeouts = 0,
    alive = true,
    steer = 0,
    shake = 0,
    mode = "classic",
    events = {},
}

local function emit(kind, text, color, duration)
    P.events[#P.events + 1] = { kind = kind, text = text, color = color, duration = duration or 1.4 }
end

function P.reset(mode)
    local p = Config.player
    local m = Config.modes[mode] or Config.modes.classic
    P.mode = mode
    P.x, P.z = 0, 0
    P.heading = 0
    P.speed = p.baseSpeed
    P.vy = 0
    P.grounded = true
    P.airTime = 0
    P.spin = 0
    P.spinTotal = 0
    P.distance = 0
    P.lives = m.lives or p.maxLives
    P.tokens = 0
    P.coinScore = 0
    P.trickScore = 0
    P.gateScore = 0
    P.boostScore = 0
    P.boostCharges = 0
    P.boostTime = 0
    P.invuln = 1.0
    P.stun = 0
    P.wipeouts = 0
    P.lastHit = nil
    P.alive = true
    P.steer = 0
    P.shake = 0
    P.events = {}
    P.visible = true
    P.trailKey = nil

    local water = W.height(0, 0) + 0.06
    P.y = water
    P.surferId = Host.entity.new("surfer", 0, water, 0, 0)
    Host.entity.setLean(P.surferId, 0, 0, P.speed)
    P.shadowId = Host.entity.new("shadow", 0, W.height(0, 0) + 0.09, 0, 0)
    Host.entity.setScale(P.shadowId, 2.1, 1, 3.6)
    Host.entity.setVisible(P.shadowId, true)

    P.cam = {
        x = 0, y = water + Config.camera.height, z = -Config.camera.distance,
        lx = 0, ly = 2, lz = Config.camera.lookAhead,
        fov = Config.camera.fov,
    }
    P.setTrail(true)
    P.updateCamera(1 / 60, true)
end

function P.setTrail(on)
    local color = P.boostTime > 0 and Config.colors.accent or Config.colors.accent2
    Host.entity.setTrail(P.surferId, on, color, 1.7, .9)
    P.trailKey = on and "on" or "off"
end

function P.addScore(component, amount)
    if component == "coin" then
        P.coinScore = P.coinScore + amount
    elseif component == "trick" then
        P.trickScore = P.trickScore + amount
    elseif component == "gate" then
        P.gateScore = P.gateScore + amount
    elseif component == "boost" then
        P.boostScore = P.boostScore + amount
    end
end

function P.totalScore()
    local base = math.floor(P.distance) + P.coinScore + P.trickScore + P.boostScore + P.gateScore
    if P.mode == "collector" then
        base = P.coinScore + math.floor(P.distance * 0.5) + P.boostScore
    end
    return math.max(0, base)
end

function P.speedFactor()
    local p = Config.player
    return U.clamp01((P.speed - p.minSpeed) / (p.boostSpeed - p.minSpeed))
end

function P.launch(power)
    if not P.grounded then return end
    P.grounded = false
    P.vy = power
    P.airTime = 0
    P.spin = 0
    P.spinTotal = 0
    P.air = 0
    Host.audio.play("jump", .9)
    Host.world.splash(P.x, P.z, .7)
    P.shake = math.max(P.shake, .35)
end

function P.hit(source, free)
    if not P.alive or P.invuln > 0 then return false end
    if not free then
        P.lives = P.lives - 1
    end
    P.wipeouts = P.wipeouts + 1
    P.lastHit = source
    P.invuln = Config.player.invulnTime
    P.speed = Config.player.baseSpeed * 0.55
    P.stun = 0.5
    P.boostTime = 0
    P.grounded = true
    P.vy = 0
    P.y = W.height(P.x, P.z) + 0.06
    P.spin = 0
    P.spinTotal = 0
    P.shake = math.max(P.shake, 1.3)
    Host.audio.play("crash")
    Host.world.event("impact", P.x, P.y + .5, P.z, 1.5)
    emit("hit", source == "kraken" and "THE KRAKEN GOT YOU" or "WIPEOUT", Config.colors.red, 1.8)
    if not free and P.lives <= 0 then
        P.lives = 0
        P.alive = false
    end
    return true
end

function P.collectCoin()
    P.tokens = P.tokens + 1
    local points = (P.mode == "collector") and 100 or Config.player.coinPoints
    P.addScore("coin", points)
    Host.audio.play("coin", .75)
    Host.world.event("sparkle", P.x, P.y + 1.0, P.z, .8)
end

function P.collectBolt()
    if P.boostCharges < Config.player.boostMax then
        P.boostCharges = P.boostCharges + 1
        emit("bolt", "BOOST +1  (F)", Config.colors.green, 1.2)
    else
        P.addScore("boost", 50)
        emit("bolt", "BOOST FULL +50", Config.colors.green, 1.2)
    end
    Host.audio.play("bolt", .8)
    Host.world.event("boost", P.x, P.y + 1.0, P.z, .8)
end

function P.collectHeart()
    if P.lives < Config.player.maxLives then
        P.lives = P.lives + 1
        emit("heart", "+1 LIFE", Config.colors.red, 1.2)
    else
        P.addScore("boost", 100)
        emit("heart", "FULL LIVES +100", Config.colors.red, 1.2)
    end
    Host.audio.play("heart", .8)
    Host.world.event("sparkle", P.x, P.y + 1.0, P.z, 1.1)
end

function P.land()
    local p = Config.player
    local rotations = math.floor(P.spinTotal / 360)
    if P.spinTotal > p.trickThreshold and rotations < 1 then rotations = 1 end
    if rotations > 0 then
        local points = p.trickPoints * rotations
        P.addScore("trick", points)
        Host.audio.play("trick", .8)
        emit("trick", (rotations * 360) .. "!  +" .. U.comma(points), Config.colors.gold, 1.4)
    end
    P.grounded = true
    P.vy = 0
    P.spin = 0
    P.spinTotal = 0
    P.airTime = 0
    P.y = W.height(P.x, P.z) + 0.06
    Host.audio.play("land", .6)
    Host.world.splash(P.x, P.z, .8)
    P.shake = math.max(P.shake, .25)
end

function P.update(dt)
    local p = Config.player
    if P.invuln > 0 then P.invuln = math.max(0, P.invuln - dt) end
    if P.stun > 0 then P.stun = math.max(0, P.stun - dt) end

    local h = I.h()
    local v = I.v()
    if P.stun > 0 then
        h = h * 0.3
        v = 0
    end
    P.steer = U.lerp(P.steer, h, U.expSmooth(9, dt))

    local sf = P.speedFactor()
    local turn = p.turnRate * (1 - 0.3 * sf)
    if not P.grounded then turn = turn * p.airTurnFactor end
    P.heading = U.wrapAngle(P.heading + P.steer * turn * dt)

    if I.boost() and P.boostCharges > 0 and P.boostTime <= 0 and P.grounded then
        P.boostCharges = P.boostCharges - 1
        P.boostTime = p.boostDuration
        Host.audio.play("boost")
        Host.world.event("boost", P.x, P.y + .7, P.z, 1.6)
        P.shake = math.max(P.shake, .3)
        emit("boost", "BOOST!", Config.colors.accent2, 1.0)
    end

    local target, accel
    if P.boostTime > 0 then
        target, accel = p.boostSpeed, 26
    elseif P.stun > 0 then
        target, accel = p.minSpeed, 9
    elseif v > .25 then
        target, accel = p.maxSpeed, 7.5
    elseif v < -.25 then
        target, accel = p.minSpeed, 9
    else
        target, accel = p.baseSpeed, 4.5
    end

    local fx, fz = math.sin(P.heading), math.cos(P.heading)
    local ahead = W.height(P.x + fx * 3, P.z + fz * 3)
    local behind = W.height(P.x - fx * 3, P.z - fz * 3)
    local slope = (ahead - behind) / 6
    P.speed = P.speed - slope * 6 * dt
    P.speed = U.approach(P.speed, target, accel * dt)
    P.speed = U.clamp(P.speed, p.minSpeed, p.boostSpeed)

    P.x = P.x + fx * P.speed * dt
    P.z = P.z + fz * P.speed * dt
    P.distance = P.distance + P.speed * dt

    local water = W.height(P.x, P.z) + 0.06
    if P.grounded then
        P.y = water
        P.vy = 0
        P.airTime = 0
        P.spin = 0
        P.spinTotal = 0
        P.air = 0
    else
        P.vy = P.vy - p.gravity * dt
        P.y = P.y + P.vy * dt
        P.airTime = P.airTime + dt
        P.spin = P.spin + P.steer * p.airSpinRate * dt
        P.spinTotal = P.spinTotal + math.abs(P.steer * p.airSpinRate * dt)
        P.air = U.clamp01((P.y - water) / 6 + P.airTime * .08)
        if P.y <= water and P.vy < 0 then
            P.land()
        end
    end

    if P.boostTime > 0 then
        P.boostTime = math.max(0, P.boostTime - dt)
        if P.boostTime == 0 then
            P.trailKey = nil
        end
    end

    -- visuals ------------------------------------------------------------
    local slopePitch
    if P.grounded then
        local a = W.height(P.x + fx * 2.5, P.z + fz * 2.5)
        local b = W.height(P.x - fx * 2.5, P.z - fz * 2.5)
        slopePitch = -math.deg(math.atan((a - b) / 5)) * .8
    else
        slopePitch = U.clamp(-P.vy * 1.4, -24, 24)
    end
    local yaw = P.heading * U.deg + (P.grounded and 0 or P.spin)
    local roll = -P.steer * 14
    Host.entity.setPos(P.surferId, P.x, P.y, P.z)
    Host.entity.setRot(P.surferId, slopePitch, yaw, roll)
    Host.entity.setLean(P.surferId, P.steer, P.air or 0, P.speed)

    local shadowScale = 1 - U.clamp((P.y - water) * .05, 0, .45)
    Host.entity.setPos(P.shadowId, P.x, W.height(P.x, P.z) + .09, P.z)
    Host.entity.setRot(P.shadowId, 0, 0, 0)
    Host.entity.setScale(P.shadowId, 2.1 * shadowScale, 1, 3.6 * shadowScale)

    local vis = true
    if P.invuln > 0 then
        vis = (math.floor(P.invuln * 12) % 2 == 0)
    end
    if vis ~= P.visible then
        P.visible = vis
        Host.entity.setVisible(P.surferId, vis)
        Host.entity.setVisible(P.shadowId, vis)
    end

    local trailOn = P.grounded and P.speed > 5
    local trailKey = (trailOn and "1" or "0") .. (P.boostTime > 0 and "b" or "n")
    if trailKey ~= P.trailKey then
        P.trailKey = trailKey
        if trailOn then
            P.setTrail(true)
        else
            Host.entity.setTrail(P.surferId, false, Config.colors.accent2, 1.7, .9)
            P.trailKey = trailKey
        end
    end

    P.updateCamera(dt, false)
end

function P.updateCamera(dt, snap)
    if not P.cam then return end
    local c = Config.camera
    local sf = P.speedFactor()
    local water = W.height(P.x, P.z)
    local airHeight = math.max(0, P.y - water)
    local fx, fz = math.sin(P.heading), math.cos(P.heading)

    local dist = c.distance + sf * 2.5
    local height = c.height + sf * 1.8 + math.min(airHeight * .22, 2.4)

    P.shake = math.max(0, P.shake - dt * 2.2)
    local sx, sy, sz = 0, 0, 0
    if P.shake > 0 then
        local amp = P.shake * 1.1
        sx = (math.random() - .5) * amp
        sy = (math.random() - .5) * amp
        sz = (math.random() - .5) * amp
    end

    local bob = math.sin(Host.time() * 1.15) * .07
    local targetX = P.x - fx * dist + sx
    local targetY = P.y + height + bob + sy
    local targetZ = P.z - fz * dist + sz
    local lookX = P.x + fx * c.lookAhead
    local lookY = P.y + 2.1 + airHeight * .2
    local lookZ = P.z + fz * c.lookAhead

    local smooth = snap and 1 or U.expSmooth(c.follow, dt)
    local lookSmooth = snap and 1 or U.expSmooth(c.lookFollow, dt)
    P.cam.x = U.lerp(P.cam.x, targetX, smooth)
    P.cam.y = U.lerp(P.cam.y, targetY, smooth)
    P.cam.z = U.lerp(P.cam.z, targetZ, smooth)
    P.cam.lx = U.lerp(P.cam.lx, lookX, lookSmooth)
    P.cam.ly = U.lerp(P.cam.ly, lookY, lookSmooth)
    P.cam.lz = U.lerp(P.cam.lz, lookZ, lookSmooth)

    local targetFov = c.fov + sf * 6 + (P.boostTime > 0 and 7 or 0)
    P.cam.fov = U.lerp(P.cam.fov, targetFov, snap and 1 or U.expSmooth(3, dt))

    Host.camera.set(P.cam.x, P.cam.y, P.cam.z, P.cam.lx, P.cam.ly, P.cam.lz, P.cam.fov)
end

function P.drainEvents()
    local events = P.events
    P.events = {}
    return events
end

function P.stopVisual()
    if P.surferId then
        Host.entity.setTrail(P.surferId, false, Config.colors.accent2, 1.7, .9)
    end
end

return P
