-- fx.lua - easing functions + a tiny tween/timer scheduler, ported from SNKRX
-- (engine/math/math.lua and engine/game/trigger.lua). Pure Lua, no love.*.
local fx = {}

local tweens = {}
local timers = {}
local uid = 0

local function lerp(a, b, t) return a + (b - a) * t end

-- ---------------------------------------------------------------- easing
local e = {}
fx.ease = e

e.linear = function(t) return t end

e.sine_in     = function(t) return 1 - math.cos(t * math.pi / 2) end
e.sine_out    = function(t) return math.sin(t * math.pi / 2) end
e.sine_in_out = function(t) return -.5 * (math.cos(math.pi * t) - 1) end

e.quad_in     = function(t) return t * t end
e.quad_out    = function(t) return -t * (t - 2) end
e.quad_in_out = function(t)
    if t < .5 then return 2 * t * t end
    t = t - 1
    return -2 * t * t + 1
end

e.cubic_in = function(t) return t * t * t end
e.cubic_out = function(t)
    t = t - 1
    return t * t * t + 1
end
e.cubic_in_out = function(t)
    if t < .5 then return 4 * t * t * t end
    t = 2 * t - 2
    return .5 * t * t * t + 1
end

e.quart_in  = function(t) return t * t * t * t end
e.quart_out = function(t)
    t = t - 1
    return 1 - t * t * t * t
end

e.quint_in = function(t) return t * t * t * t * t end
e.quint_out = function(t)
    t = t - 1
    return t * t * t * t * t + 1
end

e.expo_out = function(t)
    if t == 1 then return 1 end
    return 1 - 2 ^ (-10 * t)
end

e.circ_out = function(t)
    t = t - 1
    return math.sqrt(1 - t * t)
end

local overshoot = 1.70158
e.back_in = function(t)
    if t == 0 or t == 1 then return t end
    return t * t * ((overshoot + 1) * t - overshoot)
end
e.back_out = function(t)
    if t == 0 or t == 1 then return t end
    t = t - 1
    return t * t * ((overshoot + 1) * t + overshoot) + 1
end
e.back_in_out = function(t)
    if t == 0 or t == 1 then return t end
    t = t * 2
    if t < 1 then
        return .5 * (t * t * (((overshoot * 1.525) + 1) * t - overshoot * 1.525))
    end
    t = t - 2
    return .5 * (t * t * (((overshoot * 1.525) + 1) * t + overshoot * 1.525) + 2)
end

e.elastic_out = function(t)
    if t == 0 or t == 1 then return t end
    return 2 ^ (-10 * t) * math.sin((t * 10 - .75) * (2 * math.pi / 3)) + 1
end

e.bounce_out = function(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 7.5625 * t * t + .75
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 7.5625 * t * t + .9375
    else
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + .984375
    end
end

-- ---------------------------------------------------------------- scheduling

-- Tween numeric fields of `obj` toward `fields` over `duration`.
-- `onUpdate(obj)` runs every frame after values are written (used to push
-- the values into the Unity UI, which Lua otherwise cannot animate).
function fx.to(duration, obj, fields, ease, done, tag, onUpdate)
    ease = ease or e.cubic_out
    uid = uid + 1
    tag = tag or ("t" .. uid)
    for i = #tweens, 1, -1 do
        if tweens[i].tag == tag then table.remove(tweens, i) end
    end
    local from = {}
    for k in pairs(fields) do from[k] = obj[k] end
    tweens[#tweens + 1] = {
        t = 0, dur = math.max(duration, 1e-6),
        obj = obj, from = from, to = fields,
        ease = ease, done = done, tag = tag, onUpdate = onUpdate,
    }
    if onUpdate then onUpdate(obj) end
    return tag
end

function fx.after(delay, fn, tag)
    uid = uid + 1
    tag = tag or ("d" .. uid)
    for i = #timers, 1, -1 do
        if timers[i].tag == tag then table.remove(timers, i) end
    end
    timers[#timers + 1] = { t = 0, delay = math.max(delay, 0), fn = fn, tag = tag }
    return tag
end

function fx.cancel(tag)
    for i = #tweens, 1, -1 do
        if tweens[i].tag == tag then table.remove(tweens, i) end
    end
    for i = #timers, 1, -1 do
        if timers[i].tag == tag then table.remove(timers, i) end
    end
end

function fx.clear()
    tweens = {}
    timers = {}
end

function fx.update(dt)
    local i = 1
    while i <= #timers do
        local tm = timers[i]
        tm.t = tm.t + dt
        if tm.t >= tm.delay then
            table.remove(timers, i)
            if tm.fn then tm.fn() end
        else
            i = i + 1
        end
    end

    i = 1
    while i <= #tweens do
        local tw = tweens[i]
        tw.t = tw.t + dt
        local p = math.min(tw.t / tw.dur, 1)
        local k = tw.ease(p)
        for field, target in pairs(tw.to) do
            tw.obj[field] = lerp(tw.from[field], target, k)
        end
        if tw.onUpdate then tw.onUpdate(tw.obj) end
        if p >= 1 then
            table.remove(tweens, i)
            if tw.done then tw.done() end
        else
            i = i + 1
        end
    end
end

-- ---------------------------------------------------------------- host helpers

function fx.shake(amp, dur)
    if Host.camera and Host.camera.shake then Host.camera.shake(amp, dur) end
end

function fx.event(kind, x, y, scale)
    if Host.fx and Host.fx.event then Host.fx.event(kind, x, y, scale or 1) end
end

function fx.sound(name, vol)
    if Host.audio and Host.audio.play then Host.audio.play(name, vol or 1) end
end

-- Build an #RRGGBBAA string from a base #RRGGBB and 0..1 alpha.
function fx.rgba(hex, a)
    a = math.max(0, math.min(1, a))
    return string.format("%s%02X", hex:sub(1, 7), math.floor(a * 255 + .5))
end

return fx
