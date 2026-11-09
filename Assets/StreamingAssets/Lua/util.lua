local U = {}

U.pi = math.pi
U.tau = math.pi * 2
U.deg = 180 / math.pi
U.rad = math.pi / 180

function U.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function U.clamp01(v)
    return U.clamp(v, 0, 1)
end

function U.lerp(a, b, t)
    return a + (b - a) * t
end

function U.expSmooth(rate, dt)
    return 1 - math.exp(-rate * dt)
end

function U.approach(v, target, step)
    if v < target then
        return math.min(v + step, target)
    end
    return math.max(v - step, target)
end

function U.sign(v)
    if v > 0 then return 1 elseif v < 0 then return -1 end
    return 0
end

function U.wrapAngle(a)
    a = math.fmod(a + math.pi, math.pi * 2)
    if a < 0 then a = a + math.pi * 2 end
    return a - math.pi
end

function U.lerpAngle(a, b, t)
    return a + U.wrapAngle(b - a) * t
end

function U.atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    return math.atan(y, x)
end

function U.dist(x1, z1, x2, z2)
    local dx, dz = x2 - x1, z2 - z1
    return math.sqrt(dx * dx + dz * dz)
end

function U.dist2(x1, z1, x2, z2)
    local dx, dz = x2 - x1, z2 - z1
    return dx * dx + dz * dz
end

function U.angleTo(x1, z1, x2, z2)
    return U.atan2(x2 - x1, z2 - z1)
end

function U.chance(p)
    return math.random() < p
end

function U.choice(t)
    if #t == 0 then return nil end
    return t[math.random(1, #t)]
end

function U.shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function U.comma(n)
    n = math.floor(n + 0.5)
    local s = string.format("%.0f", n)
    local sign = ""
    if s:sub(1, 1) == "-" then
        sign = "-"
        s = s:sub(2)
    end
    local rev = string.reverse(s)
    rev = rev:gsub("(%d%d%d)", "%1,")
    s = string.reverse(rev)
    if s:sub(1, 1) == "," then s = s:sub(2) end
    return sign .. s
end

function U.formatTime(seconds)
    seconds = math.max(0, seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    local d = math.floor((seconds - math.floor(seconds)) * 10)
    return string.format("%d:%02d.%d", m, s, d)
end

function U.formatDistance(meters)
    return U.comma(meters) .. " m"
end

function U.pick(weighted)
    local total = 0
    for i = 1, #weighted do total = total + weighted[i][2] end
    local r = math.random() * total
    for i = 1, #weighted do
        r = r - weighted[i][2]
        if r <= 0 then return weighted[i][1] end
    end
    return weighted[#weighted][1]
end

function U.merge(dst, src)
    for k, v in pairs(src) do dst[k] = v end
    return dst
end

return U
