-- Obstacles and collectible eggs placed in world space ahead of the player.
local Config = require("dino_config")
local U = require("util")
local fx = require("fx")

local T = {
    items = {},
    nextObstacle = 0,
    nextEgg = 0,
}

local OBSTACLES = {
    { kind = "rock", radius = .85 },
    { kind = "rock_small", radius = .62 },
    { kind = "log", radius = .95 },
    { kind = "bush", radius = .72 },
}

local function addItem(kind, x, y, radius, itemType)
    local id = Host.entity.new(kind, x, y, 0)
    local item = {
        id = id,
        kind = kind,
        x = x,
        y = y,
        baseY = y,
        radius = radius,
        type = itemType,
        phase = math.random() * 6.28,
        dead = false,
    }
    T.items[#T.items + 1] = item
    return item
end

function T.addEgg(x, y)
    return addItem(Config.sprites.egg, x, y, .55, "egg")
end

function T.addObstacle(kind, x, y)
    local radius = .75
    for i = 1, #OBSTACLES do
        if OBSTACLES[i].kind == kind then radius = OBSTACLES[i].radius end
    end
    return addItem(kind, x, y, radius, "obstacle")
end

local function eggNear(x, y)
    for i = 1, #T.items do
        local it = T.items[i]
        if it.type == "egg" and not it.dead then
            local dx, dy = it.x - x, it.y - y
            if dx * dx + dy * dy < 7.5 then return true end
        end
    end
    return false
end

-- Spawn around the player so obstacles still sit in the player's lane on an
-- endless plain (otherwise they would be trivially avoidable).
local function spawnObstacleRow(P, y)
    local count = U.chance(.32) and 2 or 1
    for i = 1, count do
        local x = P.x + (math.random() * 2 - 1) * 6.0
        if not eggNear(x, y) then
            local o = U.choice(OBSTACLES)
            T.addObstacle(o.kind, x, y + (i - 1) * .9)
        end
    end
end

local function spawnEggRow(P, y)
    local count = math.random(3, 5)
    local x0 = P.x + (math.random() * 2 - 1) * 5.4
    local step = 1.15
    local start = x0 - (count - 1) * step * .5
    for i = 1, count do
        T.addEgg(start + (i - 1) * step, y)
    end
end

function T.clear()
    for i = 1, #T.items do
        if Host.entity.exists(T.items[i].id) then Host.entity.kill(T.items[i].id) end
    end
    T.items = {}
end

function T.reset(P)
    T.clear()
    T.nextObstacle = P.y + Config.spawn.safeStart
    T.nextEgg = P.y + 4.5
    -- a friendly line of eggs right at the start
    for i = 1, 3 do T.addEgg(P.x - 1.2 + (i - 1) * 1.2, P.y + 5.5) end
end

-- Returns true when the player hit an obstacle.
function T.update(dt, P)
    local ahead = P.y + Config.spawn.ahead
    while T.nextObstacle < ahead do
        spawnObstacleRow(P, T.nextObstacle)
        T.nextObstacle = T.nextObstacle + Config.spawn.obstacleGapMin
            + math.random() * (Config.spawn.obstacleGapMax - Config.spawn.obstacleGapMin)
    end
    while T.nextEgg < ahead do
        spawnEggRow(P, T.nextEgg)
        T.nextEgg = T.nextEgg + Config.spawn.eggGapMin
            + math.random() * (Config.spawn.eggGapMax - Config.spawn.eggGapMin)
    end

    local hit = false
    local now = Host.time()
    local cull = P.y - 20
    local cullX = Config.world.cullX
    local i = 1
    while i <= #T.items do
        local it = T.items[i]
        local remove = it.dead or it.y < cull or math.abs(it.x - P.x) > cullX
            or not Host.entity.exists(it.id)

        if not remove and it.type == "egg" then
            local dy = it.baseY + math.sin(now * 2.6 + it.phase) * .12
            Host.entity.setPos(it.id, it.x, dy, 0)
            local dx = P.x - it.x
            local ddy = P.y - it.baseY
            if dx * dx + ddy * ddy < (P.radius + it.radius) * (P.radius + it.radius) then
                it.dead = true
                remove = true
                P.collectEgg()
                fx.sound(Config.juice.eggSound, .8)
                fx.event("sparkle", it.x, it.baseY, .8)
                fx.shake(Config.juice.eggShake, .15)
            end
        elseif not remove and it.type == "obstacle" then
            local dx = P.x - it.x
            local dy = P.y - it.y
            local rr = P.radius + it.radius
            if dx * dx + dy * dy < rr * rr then
                hit = true
            end
        end

        if remove then
            Host.entity.kill(it.id)
            table.remove(T.items, i)
        else
            i = i + 1
        end
    end
    return hit
end

return T
