-- Active scene props. C# owns the GameObjects; Lua owns the game state.
local Config = require("config")
local U = require("util")

local E = {
    list = {},
    byId = {},
    cullDistance = Config.world.cullDistance,
    maxEntities = Config.world.maxEntities,
}

local function waveY(x, z)
    return Host.world.waveHeight(x, z, Host.time())
end

function E.new(kind, x, z, opts)
    opts = opts or {}
    local floatOffset = opts.float
    local y
    if opts.y ~= nil then
        y = opts.y
    elseif floatOffset ~= nil then
        y = waveY(x, z) + floatOffset
    else
        y = waveY(x, z)
    end

    local id = Host.entity.new(kind, x, y, z, opts.variant or math.random(0, 3))
    local obj = {
        id = id,
        kind = kind,
        x = x,
        z = z,
        y = y,
        r = opts.r or 1,
        float = floatOffset,
        solid = opts.solid,
        pickup = opts.pickup,
        noCull = opts.noCull,
        dead = false,
        used = false,
        tag = opts.tag,
        bornAt = Host.time(),
        update = opts.update,
        data = opts.data,
    }

    if opts.scale ~= nil then
        local s = opts.scale
        if type(s) == "table" then
            Host.entity.setScale(id, s[1], s[2], s[3])
        else
            Host.entity.setScale(id, s)
        end
    end
    if opts.color then Host.entity.setColor(id, opts.color) end
    if opts.glow then
        Host.entity.setGlow(id, opts.glowColor or opts.color or "#ffffff", opts.glow)
    end
    if opts.rotY then Host.entity.setRot(id, 0, opts.rotY, 0) end
    if floatOffset ~= nil then
        Host.entity.setFloat(id, floatOffset, opts.tilt ~= false)
    end
    if opts.spin ~= nil then
        Host.entity.setSpin(id, opts.spin, opts.bob or 0)
    end

    E.list[#E.list + 1] = obj
    E.byId[id] = obj
    return obj
end

function E.kill(obj)
    if not obj or obj.dead then return end
    obj.dead = true
    Host.entity.kill(obj.id)
    E.byId[obj.id] = nil
end

function E.clear()
    Host.entity.clear()
    E.list = {}
    E.byId = {}
end

function E.update(dt, player)
    local list = E.list
    for i = #list, 1, -1 do
        local o = list[i]
        if o.dead then
            table.remove(list, i)
        else
            if o.update then o.update(dt, o, player) end
            if not o.dead and not o.noCull and player then
                if U.dist(o.x, o.z, player.x, player.z) > E.cullDistance then
                    E.kill(o)
                end
            end
            if o.dead then table.remove(list, i) end
        end
    end
end

function E.count()
    return #E.list
end

function E.countKind(kind)
    local n = 0
    for i = 1, #E.list do
        if E.list[i].kind == kind and not E.list[i].dead then n = n + 1 end
    end
    return n
end

function E.findNearest(x, z, kinds, radius)
    local best, bestD = nil, radius * radius
    for i = 1, #E.list do
        local o = E.list[i]
        if not o.dead and kinds[o.kind] then
            local d = U.dist2(o.x, o.z, x, z)
            if d < bestD then best, bestD = o, d end
        end
    end
    return best
end

return E
