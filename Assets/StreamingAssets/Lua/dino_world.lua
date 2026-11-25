-- Endless Jurassic scenery.
--
-- The plain is split into square cells. A cell's contents come from a
-- deterministic hash of its coordinates, so every spot on the map has the same
-- scenery no matter how the player got there (no more "empty land" if you
-- strafe left/right for a while). Cells around the player are generated on
-- demand and culled once they are far behind.
local Config = require("dino_config")

local CELL = Config.terrain.cell
local RADIUS = Config.world.decorRadius      -- cells generated around the player
local CULL = RADIUS + 1                      -- hysteresis: keep one extra ring

local W = {
    cells = {},
}
local centerX, centerY

-- Each habitat mixes low plants with different silhouettes in every patch.
local communities = {
    meadow = { "fern_frond", "clubmoss_small", "crown_small", "flower" },
    fern = { "fern", "fern_frond", "crown", "clubmoss_small" },
    swamp = { "horsetail", "horsetail_cone", "fern_frond" },
}

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
    return r
end

local function cellSeed(cx, cy)
    local mix = (cx * 73856093 + cy * 19349663 + 1013904223) % 67108859
    return (mix * mix + 7919) % 2147483647
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

local function fillTerrain(pcx, pcy)
    for cy = pcy - TRAD, pcy + TRAD do
        for cx = pcx - TRAD, pcx + TRAD do
            spawnTerrainCell(cx, cy)
        end
    end
end

local function cullTerrain(pcx, pcy)
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
    local terrain = terrainPlan(cx, cy)
    local habitat = communities[terrain and terrain.kind or "meadow"]
    local items = {}

    local function add(kind, x, y, scale)
        local id = Host.entity.new(kind, x, y, .1)
        Host.entity.setScale(id, scale, scale, 1)
        Host.entity.setFlip(id, rng.chance(.5), false)
        items[#items + 1] = { id = id, x = x, y = y }
    end

    local function plantPatch(x, y, angle, patch)
        local dx, dy = math.cos(angle), math.sin(angle)
        local first = rng.int(1, #habitat)
        local size = rng.range(.85, 1.15)
        for i = 1, patch.count do
            -- Stagger the bases so the leaves overlap without lining up in rows.
            local t = (i - 1) / (patch.count - 1)
            local along = (2 * t - 1 + rng.range(-.10, .10)) * patch.width * size
            local across = ((i % 2 - .5) * .8 + rng.range(-.20, .20)) * patch.depth * size
            local kind = habitat[(first + i - 2) % #habitat + 1]
            add(kind, x + dx * along - dy * across, y + dy * along + dx * across,
                patch.scale * size * rng.range(.82, 1.16))
        end
    end

    if terrain or rng.chance(Config.world.meadowCover) then
        local angle = rng.range(0, 2 * math.pi)
        local dx, dy = math.cos(angle), math.sin(angle)
        local cxWorld, cyWorld = (cx + .5) * CELL, (cy + .5) * CELL
        local reachX, reachY = CELL * .26, CELL * .26
        if terrain then
            local blob = terrain.blobs[1]
            cxWorld, cyWorld = blob.x, blob.y
            reachX, reachY = blob.w * .44, blob.h * .44
        end
        -- Fern beds and horsetails follow opposite banks of their own ground
        -- patch. On open grass the same spacing leaves a meadow between groups.
        local world = Config.world
        local primary = rng.chance(world.largePatchChance) and world.largePatch or world.smallPatch
        plantPatch(cxWorld + dx * reachX, cyWorld + dy * reachY, angle + 1.5, primary)
        if rng.chance(Config.world.companionPatch) then
            plantPatch(cxWorld - dx * reachX, cyWorld - dy * reachY, angle - 1.1, world.smallPatch)
        end
    end

    W.cells[key] = { items = items, cx = cx, cy = cy }
end

local function fillAround(pcx, pcy)
    for cy = pcy - RADIUS, pcy + RADIUS do
        for cx = pcx - RADIUS, pcx + RADIUS do
            spawnInCell(cx, cy)
        end
    end
end

local function cullAround(pcx, pcy)
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
    centerX, centerY = nil, nil
end

function W.reset(P)
    W.clear()
    W.update(0, P)
end

function W.update(dt, P)
    -- Vegetation and terrain share the same grid, and neither changes within a cell.
    local cx, cy = math.floor(P.x / CELL), math.floor(P.y / CELL)
    if cx == centerX and cy == centerY then return end
    fillAround(cx, cy)
    cullAround(cx, cy)
    fillTerrain(cx, cy)
    cullTerrain(cx, cy)
    centerX, centerY = cx, cy
end

-- Debug hooks for the headless tests (pure plan, no host side effects).
function W.debugTerrainPlan(cx, cy)
    return terrainPlan(cx, cy)
end

function W.debugTerrainCells()
    return terrainCells
end

return W
