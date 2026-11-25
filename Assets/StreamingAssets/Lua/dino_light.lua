-- DINO IMPACT - 光照（docs/lighting-plan.md 第 0-2 步）。
-- 全局时段色调 + 局部光源。所有状态与挑选逻辑都在 Lua，便于
-- tools/luatest 无头测试；C# 只负责把结果写进 shader 全局数组。
local Config = require("dino_config")

local L = {}

L.time = 0   -- 光照内部时钟（闪烁用），按 dt 累加

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function ease(t)
    return t * t * (3 - 2 * t)
end

local function lerp3(a, b, k)
    return {
        a[1] + (b[1] - a[1]) * k,
        a[2] + (b[2] - a[2]) * k,
        a[3] + (b[3] - a[3]) * k,
    }
end

-- 两个时段状态之间的插值，k 为 0..1 的线性进度（内部做平滑缓动）。
-- 返回新表 { tint, lift, bg }，不修改入参。
function L.blend(a, b, k)
    local e = ease(clamp01(k))
    return {
        sun = (a.sun or 0) + ((b.sun or 0) - (a.sun or 0)) * e,
        tint = lerp3(a.tint, b.tint, e),
        lift = lerp3(a.lift, b.lift, e),
        bg   = lerp3(a.bg, b.bg, e),
    }
end

local function zoneState(name)
    local z = Config.light.timeZones[name]
    assert(z, "unknown time zone: " .. tostring(name))
    return { sun = z.sun, tint = z.tint, lift = z.lift, bg = z.bg }
end

-- 中性状态：白天参数（与改动前的画面一致）。
local function neutralState()
    return zoneState("day")
end

local zoneName
local fromState, toState, shown
local elapsed, duration = 0, 0

-- 立即切到指定时段（开局或测试用）。
function L.reset(name)
    zoneName = name or Config.light.zone
    toState = zoneState(zoneName)
    fromState = toState
    shown = toState
    duration = Config.light.transition or 0
    elapsed = duration
    L.time = 0
end

-- 切换时段。instant=true 或过渡秒数为 0 时直接跳。
-- 过渡中再次切换会从当前显示的颜色出发，不会跳变。
function L.setZone(name, instant)
    zoneName = name
    if instant or (Config.light.transition or 0) <= 0 then
        toState = zoneState(name)
        fromState = toState
        shown = toState
        duration = Config.light.transition or 0
        elapsed = duration
        return
    end
    fromState = shown
    toState = zoneState(name)
    duration = Config.light.transition
    elapsed = 0
end

function L.zoneName()
    return zoneName
end

-- 推进过渡并返回"逻辑上应显示"的状态（不考虑 enabled 开关）。
function L.update(dt)
    dt = dt or 0
    L.time = L.time + dt
    if elapsed < duration then
        elapsed = math.min(duration, elapsed + dt)
    end
    local k = duration > 0 and elapsed / duration or 1
    shown = L.blend(fromState, toState, k)
    return shown
end

-- 实际下发的色调：enabled=false 时强制中性。
function L.current()
    if Config.light.enabled then return shown end
    return neutralState()
end

-- 闪烁倍率，范围 [1-amp, 1+amp]。seed 让每个光源节奏不同；
-- 只依赖 time 与 seed，同样输入结果一致（可重放、可测试）。
function L.flicker(time, seed, amp)
    if not amp or amp == 0 then return 1 end
    local w = .6 * math.sin(time * 7.3 + seed) + .4 * math.sin(time * 11.1 + seed * 1.7)
    return 1 + amp * w
end

-- 从候选光源中挑出要下发的几盏。
--   sources: { {x, y, kind, seed}, ... }，sources[1] 必须是玩家（kind="player"）
--   玩家光永远第一位；其余按到玩家的距离排序，超过 range 的丢弃，最多 maxN 盏。
-- 返回 { {x, y, r, color, intensity}, ... }，intensity 已乘闪烁倍率。
function L.pickLights(sources, maxN, range)
    if not sources or #sources == 0 then return {} end
    local player = sources[1]
    local px, py = player.x, player.y
    local cands = {}
    for i, s in ipairs(sources) do
        local cfg = Config.light.sources[s.kind]
        if cfg then
            local d = math.sqrt((s.x - px) ^ 2 + (s.y - py) ^ 2)
            if s.kind == "player" or d <= range then
                cands[#cands + 1] = { s = s, cfg = cfg, d = d, order = i }
            end
        end
    end
    table.sort(cands, function(a, b)
        local ap, bp = a.s.kind == "player", b.s.kind == "player"
        if ap ~= bp then return ap end
        if a.d ~= b.d then return a.d < b.d end
        return a.order < b.order
    end)
    local out = {}
    for k = 1, math.min(maxN, #cands) do
        local c = cands[k]
        local f = L.flicker(L.time, c.s.seed or 0, c.cfg.flicker)
        out[#out + 1] = {
            x = c.s.x, y = c.s.y, r = c.cfg.radius, color = c.cfg.color,
            intensity = c.cfg.intensity * f,
        }
    end
    return out
end

-- 接触阴影的偏移（第 3 步）：sunDir 归一化后乘以 shadowOffset。
-- 玩家阴影的位置由 dino_player 加上这个偏移。
function L.shadowOffset()
    local d = Config.light.sunDir
    local len = math.sqrt(d[1] * d[1] + d[2] * d[2])
    if len == 0 then return 0, 0 end
    local k = Config.light.shadowOffset / len
    return d[1] * k, d[2] * k
end

-- 每帧调用：推进过渡 + 挑选光源 + 下发到宿主。
-- sources 为 nil（比如菜单里）时不下发任何光源。宿主缺接口时静默跳过。
function L.tick(dt, sources)
    L.update(dt)
    local s = L.current()
    local world = Host and Host.world
    local vignette = Config.light.enabled and Config.light.vignette or 0
    if world and world.setTint then
        world.setTint(
            s.tint[1], s.tint[2], s.tint[3],
            s.lift[1], s.lift[2], s.lift[3],
            s.bg[1], s.bg[2], s.bg[3],
            vignette, Config.light.sunDir[1], Config.light.sunDir[2],
            Config.light.enabled and s.sun or 0, Config.light.castLength,
            L.time * Config.light.clouds.windX, L.time * Config.light.clouds.windY,
            1 / Config.light.clouds.tileSize, Config.light.clouds.shafts)
    end
    if world and world.setLights then
        local lights = {}
        if Config.light.enabled and sources then
            lights = L.pickLights(sources, Config.light.maxLights, Config.light.pickRange)
        end
        local flat = {}
        for k, l in ipairs(lights) do
            local b = (k - 1) * 7
            flat[b + 1] = l.x
            flat[b + 2] = l.y
            flat[b + 3] = l.r
            flat[b + 4] = l.color[1]
            flat[b + 5] = l.color[2]
            flat[b + 6] = l.color[3]
            flat[b + 7] = l.intensity
        end
        world.setLights(#lights, flat, Config.light.halo.alpha, Config.light.halo.scale)
    end
end

return L
