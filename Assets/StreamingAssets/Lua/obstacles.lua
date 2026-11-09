-- Obstacles, pickups, ramps, gates and sharks. All spawns are relative to the surfer.
local Config = require("config")
local U = require("util")
local I = require("input")
local W = require("world")
local E = require("entities")
local P = require("player")

local O = {
    events = {},
    mode = "classic",
}

local function push(ev)
    O.events[#O.events + 1] = ev
end

function O.drainEvents()
    local events = O.events
    O.events = {}
    return events
end

local function modeCfg(mode)
    return Config.modes[mode] or Config.modes.classic
end

local function ahead(player, minD, maxD, spreadDeg)
    local d = minD + math.random() * (maxD - minD)
    local half = math.rad(spreadDeg or Config.spawn.spreadDeg) * .5
    local ang = player.heading + (math.random() * 2 - 1) * half
    return player.x + math.sin(ang) * d, player.z + math.cos(ang) * d, d
end

local function clearOfSolids(x, z, radius)
    local r2 = radius * radius
    for i = 1, #E.list do
        local o = E.list[i]
        if not o.dead and o.solid then
            if U.dist2(x, z, o.x, o.z) < r2 then return false end
        end
    end
    return true
end

local function clearOfGates(x, z, radius)
    local r2 = radius * radius
    for i = 1, #E.list do
        local o = E.list[i]
        if not o.dead and (o.kind == "gate" or o.kind == "checkpoint") then
            if U.dist2(x, z, o.x, o.z) < r2 then return false end
        end
    end
    return true
end

local function canSpawn()
    return E.count() < E.maxEntities - 8
end

-- spawners ----------------------------------------------------------------

local function spawnObstacle(player)
    if not canSpawn() then return false end
    local sharkCount = E.countKind("shark")
    local kind
    local roll = math.random()
    if sharkCount < 2 and roll < .12 then
        kind = "shark"
    elseif roll < .40 then
        kind = "log"
    elseif roll < .65 then
        kind = "buoy"
    else
        kind = "rock"
    end

    for attempt = 1, 4 do
        local minD = Config.spawn.obstacleMin + P.speedFactor() * 18
        local maxD = Config.spawn.obstacleMax + P.speedFactor() * 22
        local x, z = ahead(player, minD, maxD, Config.spawn.spreadDeg)
        if clearOfGates(x, z, 13) and clearOfSolids(x, z, 7.5) then
            if kind == "shark" then
                local shark = E.new("shark", x, z, {
                    y = W.height(x, z) + .05,
                    r = 1.4,
                    solid = true,
                    tag = "obstacle",
                    data = { t = 0 },
                })
                shark.update = function(dt, o, ply)
                    local d = o.data
                    d.t = d.t + dt
                    local dx, dz = ply.x - o.x, ply.z - o.z
                    local len = math.sqrt(dx * dx + dz * dz)
                    local sp = 4.5 + math.min(d.t, 10) * .4
                    if len > .1 then
                        o.x = o.x + dx / len * sp * dt
                        o.z = o.z + dz / len * sp * dt
                    end
                    o.y = W.height(o.x, o.z) + .05
                    Host.entity.setPos(o.id, o.x, o.y, o.z)
                    Host.entity.setRot(o.id, 0, math.deg(U.atan2(dx, dz)), 0)
                    if d.t > 15 or len > 210 then E.kill(o) end
                end
            elseif kind == "log" then
                E.new("log", x, z, {
                    variant = math.random(0, 2),
                    float = .12, tilt = false,
                    r = 2.4, solid = true, tag = "obstacle",
                    rotY = math.random(0, 359),
                    scale = .9 + math.random() * .35,
                })
            elseif kind == "buoy" then
                E.new("buoy", x, z, {
                    variant = math.random(0, 3),
                    float = .05, tilt = false,
                    r = 1.0, solid = true, tag = "obstacle",
                    scale = 1.5 + math.random() * .8,
                })
            else
                local scale = 1.6 + math.random() * 1.7
                E.new("rock", x, z, {
                    variant = math.random(0, 3),
                    float = -.25, tilt = false,
                    r = 1.05 * scale, solid = true, tag = "obstacle",
                    scale = scale,
                    rotY = math.random(0, 359),
                })
            end
            return true
        end
    end
    return false
end

local function spawnIsland(player)
    if not canSpawn() then return false end
    for attempt = 1, 4 do
        local x, z = ahead(player, Config.spawn.islandMin + 20, Config.spawn.islandMax + 25, 46)
        if clearOfGates(x, z, 20) and clearOfSolids(x, z, 16) then
            local scale = 3.4 + math.random() * 2.4
            E.new("island", x, z, {
                variant = math.random(0, 2),
                float = -.5, tilt = false,
                r = scale * .82, solid = true, tag = "obstacle",
                scale = scale,
            })
            return true
        end
    end
    return false
end

local function spawnCoinAt(player, forwardDist, lateral, lift)
    local ang = player.heading
    local fx, fz = math.sin(ang), math.cos(ang)
    local rx, rz = math.cos(ang), -math.sin(ang)
    local x = player.x + fx * forwardDist + rx * lateral
    local z = player.z + fz * forwardDist + rz * lateral
    if not clearOfSolids(x, z, 4) then return false end
    E.new("coin", x, z, {
        float = 0, tilt = false,
        r = 1.35, pickup = true, tag = "pickup",
    })
    return true
end

local function spawnCoinCluster(player)
    if not canSpawn() then return false end
    local collector = O.mode == "collector"
    local count = collector and math.random(6, 10) or math.random(4, 7)
    local spacing = collector and 3.0 or 4.2
    local base = Config.spawn.pickupMin + 6 + math.random() * (Config.spawn.pickupMax - Config.spawn.pickupMin - 12)
    local lateral0 = (math.random() * 2 - 1) * 9

    if math.random() < .14 then
        -- a ring of coins
        local ringRadius = collector and 8.5 or 7
        local n = collector and 10 or 8
        local centerAng = player.heading
        local cx = player.x + math.sin(centerAng) * base
        local cz = player.z + math.cos(centerAng) * base
        for i = 1, n do
            local a = i / n * U.tau
            local x, z = cx + math.cos(a) * ringRadius, cz + math.sin(a) * ringRadius
            if clearOfSolids(x, z, 3.5) then
                E.new("coin", x, z, { float = 0, tilt = false, r = 1.4, pickup = true, tag = "pickup" })
            end
        end
        return true
    end

    local curve = (math.random() * 2 - 1) * 6
    for i = 1, count do
        local lateral = lateral0 + math.sin((i - 1) * .75) * curve
        spawnCoinAt(player, base + (i - 1) * spacing, lateral)
    end
    return true
end

local function spawnSpecialPickup(player, kind)
    if not canSpawn() then return false end
    for attempt = 1, 4 do
        local x, z = ahead(player, Config.spawn.pickupMin + 15, Config.spawn.pickupMax + 20, 34)
        if clearOfSolids(x, z, 5) and clearOfGates(x, z, 8) then
            E.new(kind, x, z, {
                float = 0, tilt = false,
                r = 1.5, pickup = true, tag = "pickup",
            })
            return true
        end
    end
    return false
end

local function spawnRamp(player)
    if not canSpawn() then return false end
    for attempt = 1, 4 do
        local x, z = ahead(player, Config.spawn.rampMin, Config.spawn.rampMax, 30)
        if clearOfSolids(x, z, 9) and clearOfGates(x, z, 10) then
            local r = E.new("ramp", x, z, {
                float = -.2, tilt = false,
                rotY = math.deg(player.heading),
                tag = "ramp", r = 5.6,
            })
            r.used = false
            return true
        end
    end
    return false
end

local function spawnGate(player, kind)
    if not canSpawn() then return false end
    local cfg = modeCfg(O.mode)
    local checkpoint = kind == "checkpoint"
    local aheadDist = checkpoint and (105 + math.random() * 25) or (82 + math.random() * 18)
    local lateral
    if checkpoint then
        lateral = (math.random() * 2 - 1) * 7
    else
        O.gateSide = -O.gateSide
        lateral = O.gateSide * cfg.gateOffset
    end
    local ang = player.heading
    local fx, fz = math.sin(ang), math.cos(ang)
    local rx, rz = math.cos(ang), -math.sin(ang)
    local x = player.x + fx * aheadDist + rx * lateral
    local z = player.z + fz * aheadDist + rz * lateral

    if not clearOfSolids(x, z, 13) or not clearOfGates(x, z, 30) then
        return false
    end

    local g = E.new(kind, x, z, {
        float = 0, tilt = false,
        rotY = math.deg(ang),
        tag = kind,
        noCull = false,
    })
    g.yaw = ang
    g.used = false
    g.missed = false
    g.side = lateral
    return true
end

-- reset / timers -----------------------------------------------------------

function O.reset(mode)
    O.mode = mode or "classic"
    O.events = {}
    O.gateSide = math.random() < .5 and 1 or -1
    local cfg = modeCfg(O.mode)
    O.t = {
        obstacle = 1.6,
        island = cfg.island * .7,
        coin = .8,
        ramp = 4.5,
        bolt = 14,
        heart = 26,
        gate = 2.2,
        shark = 9,
    }
end

local function tick(timers, key, dt)
    timers[key] = (timers[key] or 0) - dt
    return timers[key] <= 0
end

-- collisions ---------------------------------------------------------------

local function localToGate(g, px, pz)
    local dx, dz = px - g.x, pz - g.z
    local c, s = math.cos(g.yaw), math.sin(g.yaw)
    return dx * c - dz * s, dx * s + dz * c
end

local function collidePickup(player, o)
    local reach = Config.player.radius + o.r
    if U.dist2(player.x, player.z, o.x, o.z) > reach * reach then return false end
    if player.y - o.y > 3.2 then return false end
    o.used = true
    if o.kind == "coin" then
        P.collectCoin()
        push({ kind = "coin" })
    elseif o.kind == "bolt" then
        P.collectBolt()
        push({ kind = "bolt" })
    elseif o.kind == "heart" then
        P.collectHeart()
        push({ kind = "heart" })
    end
    E.kill(o)
    return true
end

local function collideObstacle(player, o)
    if not o.solid or o.dead then return end
    local airLimit = (o.kind == "island") and 4.5 or 1.7
    if player.y - o.y > airLimit then return end
    local reach = Config.player.radius + o.r
    if U.dist2(player.x, player.z, o.x, o.z) > reach * reach then return end
    if P.hit("obstacle", O.mode == "timeTrial") then
        push({ kind = "obstacleHit", x = o.x, z = o.z })
    end
end

local function updateGate(player, o, now)
    if o.used or o.missed then
        if now - (o.resolvedAt or now) > 1.1 then E.kill(o) end
        return
    end
    local lx, lz = localToGate(o, player.x, player.z)
    local isCheckpoint = o.kind == "checkpoint"
    if math.abs(lz) < 3.0 and math.abs(lx) < 7.7 then
        o.used = true
        o.resolvedAt = now
        Host.audio.play("gate", .8)
        Host.world.event("sparkle", o.x, 5.5, o.z, 1.3)
        push({ kind = isCheckpoint and "checkpoint" or "gatePassed", x = o.x, z = o.z, lateral = math.abs(lx) })
    elseif lz > 6.5 or (now - o.bornAt) > 22 then
        o.missed = true
        o.resolvedAt = now
        push({ kind = isCheckpoint and "checkpointMissed" or "gateMissed", x = o.x, z = o.z })
    end
end

function O.update(dt, player, mode)
    if mode then O.mode = mode end
    local cfg = modeCfg(O.mode)
    local t = O.t
    if not t then O.reset(O.mode); t = O.t end

    local difficulty = 1 + math.min(player.distance / 2800, .6)

    if tick(t, "obstacle", dt) then
        spawnObstacle(player)
        t.obstacle = math.max(.55, (cfg.obstacle / difficulty) * (.85 + math.random() * .4))
    end
    if tick(t, "island", dt) then
        spawnIsland(player)
        t.island = math.max(7, cfg.island * (.8 + math.random() * .5))
    end
    if tick(t, "coin", dt) then
        spawnCoinCluster(player)
        t.coin = math.max(.35, cfg.coin * (.85 + math.random() * .4) / (1 + player.distance / 9000))
    end
    if tick(t, "ramp", dt) then
        spawnRamp(player)
        t.ramp = cfg.ramp * (.8 + math.random() * .5)
    end
    if tick(t, "bolt", dt) then
        spawnSpecialPickup(player, "bolt")
        t.bolt = cfg.bolt * (.8 + math.random() * .5)
    end
    if tick(t, "heart", dt) then
        spawnSpecialPickup(player, "heart")
        t.heart = cfg.heart * (.85 + math.random() * .4)
    end

    if O.mode == "zigzag" or O.mode == "timeTrial" then
        if tick(t, "gate", dt) then
            local gateKind = O.mode == "timeTrial" and "checkpoint" or "gate"
            local existing = E.countKind(gateKind)
            if existing == 0 then
                if spawnGate(player, gateKind) then
                    t.gate = 1.2
                else
                    t.gate = .7
                end
            else
                t.gate = .5
            end
        end
    end

    local now = Host.time()
    local list = E.list
    for i = #list, 1, -1 do
        local o = list[i]
        if not o.dead then
            if o.pickup and not o.used then
                collidePickup(player, o)
            elseif o.solid then
                collideObstacle(player, o)
            elseif o.kind == "ramp" and not o.used then
                if player.grounded and U.dist2(player.x, player.z, o.x, o.z) < 5.6 * 5.6 then
                    o.used = true
                    o.usedAt = now
                    local power = Config.player.jumpBase + player.speed * Config.player.jumpSpeedFactor
                    power = power + math.max(0, I.v()) * 2.4
                    P.launch(power)
                    push({ kind = "ramp", x = o.x, z = o.z })
                end
            elseif o.kind == "gate" or o.kind == "checkpoint" then
                updateGate(player, o, now)
            end

            if o.used and (o.kind == "ramp") and now - (o.usedAt or now) > 1.3 then
                E.kill(o)
            end
        end
    end
end

return O
