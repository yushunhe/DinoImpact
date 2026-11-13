-- Thin wrapper over Host.input. Tests can inject a table of virtual inputs.
local I = { override = nil }

local function get(key, fn)
    if I.override and I.override[key] ~= nil then
        return I.override[key]
    end
    return fn()
end

function I.h()
    return get("h", function() return Host.input.axisH() end)
end

function I.v()
    return get("v", function() return Host.input.axisV() end)
end

function I.pause() return get("pause", function() return Host.input.pause() end) end
function I.boost() return get("boost", function() return Host.input.boost() end) end
function I.restart() return get("restart", function() return Host.input.restart() end) end
function I.confirm() return get("confirm", function() return Host.input.confirm() end) end
function I.back() return get("back", function() return Host.input.back() end) end
function I.mute() return get("mute", function() return Host.input.mute() end) end
function I.anyKey() return get("anyKey", function() return Host.input.anyKey() end) end
function I.left() return get("left", function() return Host.input.left() end) end
function I.right() return get("right", function() return Host.input.right() end) end
function I.up() return get("up", function() return Host.input.up() end) end
function I.down() return get("down", function() return Host.input.down() end) end

function I.number(n)
    local key = "num" .. n
    return get(key, function() return Host.input.number(n) end)
end

-- gameplay keys (1113 反馈版：J 射箭、K 换乘、Space 技能、S 按住刹车)
function I.shoot() return get("shoot", function() return Host.input.shoot() end) end
function I.mount() return get("mount", function() return Host.input.mount() end) end
function I.skill() return get("skill", function() return Host.input.skill() end) end
function I.stop() return get("stop", function() return Host.input.stop() end) end

function I.setOverride(t)
    I.override = t
end

return I
