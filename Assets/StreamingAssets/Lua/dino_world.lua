-- Endless Jurassic scenery.
--
-- The plain is split into square cells. A cell's contents come from a
-- deterministic hash of its coordinates, so every spot on the map has the same
-- scenery no matter how the player got there (no more "empty land" if you
-- strafe left/right for a while). Cells around the player are generated on
-- demand and culled once they are far behind.
local Config = require("dino_config")

local CELL = Config.world.decorCell
local RADIUS = Config.world.decorRadius      -- cells generated around the player
local CULL = RADIUS + 1                      -- hysteresis: keep one extra ring

local W = {
    cells = {},
}

-- PlantsPixelIt 素材：树蕨/扇叶树/苏铁当大目标，其余新植被撒作细节
-- （世界高度已在 DinoPixelArt.PlantUnits 里归一，缩放只是微调随机感）
local BIG = { "tree", "tree", "palm", "cycad", "fern", "bush", "rock_small" }
local DETAIL = { "pebble", "flower", "horsetail", "horsetail_cone", "crown",
                 "crown_small", "clubmoss_small", "fern_frond", "fern" }

-- Park-Miller LCG. Pure arithmetic so it behaves identically in Lua 5.2
-- (MoonSharp) and 5.4, and each cell always rolls the same scenery.
local function makeRng(seed)
    local s = seed % 2147483647
    if s <= 0 then s = s + 2147483646 end
    local function next()
        s = (s * 16807) % 2147483647
        return s
    end
    local r = {}
    function r.float() return (next() - 1) / 2147483646 end
    function r.range(a, b) return a + (b - a) * r.float() end
    function r.chance(p) return r.float() < p end
    function r.pick(list) return list[1 + math.floor(r.float() * #list)] end
    return r
end

local function cellSeed(cx, cy)
    return (cx * 73856093 + cy * 19349663 + 1013904223) % 2147483647
end

local function cellKey(cx, cy)
    return cx .. ":" .. cy
end

local function spawnInCell(cx, cy)
    local key = cellKey(cx, cy)
    if W.cells[key] then return end

    local rng = makeRng(cellSeed(cx, cy))
    local x0, y0 = cx * CELL, cy * CELL
    local items = {}

    local function add(kind, x, y, scale)
        local id = Host.entity.new(kind, x, y, .1)
        Host.entity.setScale(id, scale, scale, 1)
        items[#items + 1] = { id = id, x = x, y = y }
    end

    -- Same average density as the old rows, just spread over the whole cell.
    local bigs = 0
    if rng.chance(.42) then bigs = 1 end
    if rng.chance(.08) then bigs = bigs + 1 end
    for _ = 1, bigs do
        add(rng.pick(BIG),
            x0 + rng.range(.12, .88) * CELL,
            y0 + rng.range(.12, .88) * CELL,
            rng.range(.8, 1.5))
    end

    local details = 0
    if rng.chance(.30) then details = 1 end
    if rng.chance(.08) then details = details + 1 end
    for _ = 1, details do
        add(rng.pick(DETAIL),
            x0 + rng.range(.08, .92) * CELL,
            y0 + rng.range(.08, .92) * CELL,
            rng.range(.7, 1.1))
    end

    W.cells[key] = { items = items, cx = cx, cy = cy }
end

local function fillAround(P)
    local pcx = math.floor(P.x / CELL)
    local pcy = math.floor(P.y / CELL)
    for cy = pcy - RADIUS, pcy + RADIUS do
        for cx = pcx - RADIUS, pcx + RADIUS do
            spawnInCell(cx, cy)
        end
    end
end

local function cullAround(P)
    local pcx = math.floor(P.x / CELL)
    local pcy = math.floor(P.y / CELL)
    for key, cell in pairs(W.cells) do
        if math.abs(cell.cx - pcx) > CULL or math.abs(cell.cy - pcy) > CULL then
            for i = 1, #cell.items do
                Host.entity.kill(cell.items[i].id)
            end
            W.cells[key] = nil
        end
    end
end

function W.clear()
    for _, cell in pairs(W.cells) do
        for i = 1, #cell.items do
            Host.entity.kill(cell.items[i].id)
        end
    end
    W.cells = {}
end

function W.reset(P)
    W.clear()
    fillAround(P)
end

function W.update(dt, P)
    fillAround(P)
    cullAround(P)
end

return W
