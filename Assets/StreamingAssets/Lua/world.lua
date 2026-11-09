-- Ocean world: day/night, weather, clouds and far islands.
local Config = require("config")
local U = require("util")
local E = require("entities")

local W = {
    dayT = Config.world.startTimeOfDay,
    weather = "none",
    weatherTimer = 30,
    clouds = {},
    islands = {},
    _lastSky = -1,
    _now = 0,
}

function W.now()
    return Host.time()
end

function W.height(x, z)
    return Host.world.waveHeight(x, z, Host.time())
end

local function spawnCloud(px, pz, initial)
    local ang = math.random() * U.tau
    local radius = initial and (70 + math.random() * 150) or (150 + math.random() * 150)
    local x = px + math.sin(ang) * radius
    local z = pz + math.cos(ang) * radius
    local y = 38 + math.random() * 42
    local scale = 9 + math.random() * 14
    local obj = E.new("cloud", x, z, {
        y = y,
        scale = scale,
        variant = math.random(0, 2),
        rotY = math.random(0, 359),
        noCull = true,
    })
    obj.isCloud = true
    obj.height = y
    obj.phase = math.random() * U.tau
    local windAng = -0.6 + math.random() * 0.35
    local speed = 1.2 + math.random() * 2.2
    obj.windX = math.sin(windAng) * speed
    obj.windZ = math.cos(windAng) * speed
    W.clouds[#W.clouds + 1] = obj
    return obj
end

local function spawnFarIsland(px, pz, initial)
    local ang = math.random() * U.tau
    local radius = initial and (220 + math.random() * 150) or (280 + math.random() * 160)
    local x = px + math.sin(ang) * radius
    local z = pz + math.cos(ang) * radius
    local scale = 16 + math.random() * 28
    local obj = E.new("island", x, z, {
        y = -2.2,
        scale = scale,
        variant = math.random(0, 2),
        noCull = true,
    })
    obj.isFar = true
    W.islands[#W.islands + 1] = obj
    return obj
end

function W.reset(player)
    player = player or { x = 0, z = 0 }
    W.dayT = Config.world.startTimeOfDay
    W.weather = "none"
    W.weatherTimer = 26
    W._lastSky = -1
    W.clouds = {}
    W.islands = {}
    Host.world.setWeather("none")

    for i = 1, Config.world.cloudCount do spawnCloud(player.x, player.z, true) end
    for i = 1, Config.world.farIslandCount do spawnFarIsland(player.x, player.z, true) end
    W.applySky(true)
end

function W.applySky(force)
    local t = (Config.world.startTimeOfDay + Host.time() / Config.world.dayLength) % 1
    W.dayT = t
    if force or math.abs(t - W._lastSky) > 0.0015 then
        W._lastSky = t
        Host.world.setTimeOfDay(t)
    end
end

function W.setWeather(kind, duration)
    W.weather = kind
    W.weatherTimer = duration or (20 + math.random() * 20)
    Host.world.setWeather(kind)
end

function W.updateWeather(dt)
    W.weatherTimer = W.weatherTimer - dt
    if W.weatherTimer > 0 then return end

    local roll = math.random()
    if W.weather == "none" then
        if roll < 0.55 then
            W.setWeather("rain", 18 + math.random() * 14)
        else
            W.setWeather("snow", 20 + math.random() * 16)
        end
    else
        W.setWeather("none", 30 + math.random() * 28)
    end
end

function W.update(dt, player, playing)
    W.applySky(false)
    if playing then W.updateWeather(dt) end

    local now = Host.time()
    for i = #W.clouds, 1, -1 do
        local c = W.clouds[i]
        if c.dead then
            table.remove(W.clouds, i)
        else
            c.x = c.x + c.windX * dt
            c.z = c.z + c.windZ * dt
            local y = c.height + math.sin(now * 0.18 + c.phase) * 2.2
            Host.entity.setPos(c.id, c.x, y, c.z)
            if player and U.dist(c.x, c.z, player.x, player.z) > 330 then
                E.kill(c)
                table.remove(W.clouds, i)
                spawnCloud(player.x, player.z, false)
            end
        end
    end

    for i = #W.islands, 1, -1 do
        local isl = W.islands[i]
        if isl.dead then
            table.remove(W.islands, i)
        elseif player and U.dist(isl.x, isl.z, player.x, player.z) > 520 then
            E.kill(isl)
            table.remove(W.islands, i)
            spawnFarIsland(player.x, player.z, false)
        end
    end
end

-- Reset scenery only (used when entering the menu from a run).
function W.menuReset(player)
    W.clouds = {}
    W.islands = {}
    player = player or { x = 0, z = 0 }
    for i = 1, Config.world.cloudCount do spawnCloud(player.x, player.z, true) end
    for i = 1, Config.world.farIslandCount do spawnFarIsland(player.x, player.z, true) end
    W.setWeather("none", 999)
    W.applySky(true)
end

return W
