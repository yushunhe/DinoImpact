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
-- 树已从装饰池移除：它现在是专门的障碍物（dino_data.obstacles.tree），
-- 免得场上同时存在"看起来一样但不扣血"的装饰树。
local BIG = { "palm", "cycad", "fern", "bush", "rock_small" }
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
    function r.int(a, b) return a + math.floor(r.float() * (b - a + 1)) end
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

-- --------------------------------------------------------------- terrain
-- 参考 Assets/Art/地貌.jpg 的三种地貌：草地（底图）、蕨叶地、沼泽地。
-- 底图由 C# 的 DinoHost 无限平铺；蕨叶/沼泽是以世界坐标盖在上面的
-- "地块"(Host.terrain)，用更大的格子判定 + 确定性哈希，同样的坐标永远
-- 掷出同样的地貌。每格至多一种，草地的概率 = 1 - 蕨叶 - 沼泽。
local TC = Config.terrain.cell
local TRAD = Config.terrain.radius
local TCULL = TRAD + 1
local terrainCells = {}

local function terrainSeed(cx, cy)
    return (cx * 92837111 + cy * 689287499 + 283923481) % 2147483647
end

-- 纯计算、不碰 Host：返回 nil（草地）或
-- { kind = "fern"|"swamp", blobs = { {x,y,w,h,variant}, ... } }
local function terrainPlan(cx, cy)
    local T = Config.terrain
    local rng = makeRng(terrainSeed(cx, cy))
    local roll = rng.float()
    local kind, spec
    if roll < T.fern.chance then
        kind, spec = "fern", T.fern
    elseif roll < T.fern.chance + T.swamp.chance then
        kind, spec = "swamp", T.swamp
    else
        return nil
    end

    local x0, y0 = cx * TC, cy * TC
    local w = TC * rng.range(spec.minFrac, spec.maxFrac)
    local h = math.min(w * rng.range(T.aspectMin, T.aspectMax), TC * .94)
    local px = x0 + TC * .5 + rng.range(-T.jitter, T.jitter) * TC
    local py = y0 + TC * .5 + rng.range(-T.jitter, T.jitter) * TC

    local blobs = { { x = px, y = py, w = w, h = h, variant = rng.int(0, 3) } }
    local extras = 0
    if rng.chance(T.satelliteChance) then extras = extras + 1 end
    if rng.chance(T.satelliteChance * .55) then extras = extras + 1 end
    for _ = 1, extras do
        local s = rng.range(T.satelliteSize[1], T.satelliteSize[2])
        blobs[#blobs + 1] = {
            x = px + rng.range(-.42, .42) * w,
            y = py + rng.range(-.42, .42) * h,
            w = math.max(2.4, w * s),
            h = math.max(2.4, h * s),
            variant = rng.int(0, 3),
        }
    end
    return { kind = kind, blobs = blobs }
end

local function spawnTerrainCell(cx, cy)
    local key = cellKey(cx, cy)
    if terrainCells[key] then return end
    local plan = terrainPlan(cx, cy)
    local ids = {}
    if plan then
        for i = 1, #plan.blobs do
            local b = plan.blobs[i]
            ids[#ids + 1] = Host.terrain.add(plan.kind, b.x, b.y, b.w, b.h, b.variant)
        end
    end
    -- remember grass cells too, so they are not re-rolled every frame
    terrainCells[key] = { ids = ids, cx = cx, cy = cy }
end

local function fillTerrain(P)
    local pcx = math.floor(P.x / TC)
    local pcy = math.floor(P.y / TC)
    for cy = pcy - TRAD, pcy + TRAD do
        for cx = pcx - TRAD, pcx + TRAD do
            spawnTerrainCell(cx, cy)
        end
    end
end

local function cullTerrain(P)
    local pcx = math.floor(P.x / TC)
    local pcy = math.floor(P.y / TC)
    for key, cell in pairs(terrainCells) do
        if math.abs(cell.cx - pcx) > TCULL or math.abs(cell.cy - pcy) > TCULL then
            for i = 1, #cell.ids do Host.terrain.kill(cell.ids[i]) end
            terrainCells[key] = nil
        end
    end
end

local function clearTerrain()
    for _, cell in pairs(terrainCells) do
        for i = 1, #cell.ids do Host.terrain.kill(cell.ids[i]) end
    end
    terrainCells = {}
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
    clearTerrain()
end

function W.reset(P)
    W.clear()
    fillAround(P)
    fillTerrain(P)
end

function W.update(dt, P)
    fillAround(P)
    cullAround(P)
    fillTerrain(P)
    cullTerrain(P)
end

-- Debug hooks for the headless tests (pure plan, no host side effects).
function W.debugTerrainPlan(cx, cy)
    return terrainPlan(cx, cy)
end

function W.debugTerrainCells()
    return terrainCells
end

return W
