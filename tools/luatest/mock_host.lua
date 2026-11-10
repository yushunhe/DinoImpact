-- Minimal fake of the Unity host, enough to execute the Lua game headlessly.
local M = {}

function M.new()
    local now = 0
    local nextId = 1
    local ents = {}
    local buttons = {}
    local labels = {}
    local colors = {}
    local texts = {}
    local visible = {}
    local save = {}
    local camera = { x = 0, y = 0, z = 0 }
    local fade = 0
    local vignette = false

    local function noop() end
    local function entity(id)
        return ents[id]
    end

    local host = {}
    host.time = function() return now end
    host.log = function(s) io.write("[lua] " .. tostring(s) .. "\n") end

    host.entity = {
        new = function(kind, x, y, z, variant)
            local id = nextId
            nextId = nextId + 1
            ents[id] = {
                id = id, kind = kind, x = x, y = y, z = z, variant = variant,
                rot = { 0, 0, 0 }, scale = { 1, 1, 1 }, color = "#ffffff",
                visible = true, lean = { 0, 0, 0 }, anim = 0, trail = false,
            }
            return id
        end,
        kill = function(id) ents[id] = nil end,
        clear = function() ents = {} end,
        count = function()
            local n = 0
            for _ in pairs(ents) do n = n + 1 end
            return n
        end,
        exists = function(id) return ents[id] ~= nil end,
        setPos = function(id, x, y, z)
            local e = entity(id)
            if e then e.x, e.y, e.z = x, y, z end
        end,
        getPos = function(id)
            local e = entity(id)
            if not e then return 0, 0, 0 end
            return e.x, e.y, e.z
        end,
        setRot = function(id, x, y, z)
            local e = entity(id)
            if e then e.rot = { x, y, z } end
        end,
        setScale = function(id, x, y, z)
            local e = entity(id)
            if e then e.scale = { x, y or x, z or x } end
        end,
        setColor = function(id, c)
            local e = entity(id)
            if e then e.color = c end
        end,
        setSprite = function(id, name)
            local e = entity(id)
            if e then e.sprite = name end
        end,
        setFlip = function(id, x, y)
            local e = entity(id)
            if e then e.flip = { x, y } end
        end,
        setOrder = function(id, n)
            local e = entity(id)
            if e then e.order = n end
        end,
        setGlow = noop,
        setVisible = function(id, v)
            local e = entity(id)
            if e then e.visible = v end
        end,
        setFloat = noop,
        setSpin = noop,
        setLean = function(id, a, b, c)
            local e = entity(id)
            if e then e.lean = { a, b, c } end
        end,
        setAnim = function(id, v)
            local e = entity(id)
            if e then e.anim = v end
        end,
        setTrail = function(id, on)
            local e = entity(id)
            if e then e.trail = on end
        end,
    }

    host.world = {
        waveHeight = function(x, z, t)
            return math.sin(x * .13 + t * .8) * .4 + math.cos(z * .09 - t * .6) * .35
        end,
        setTimeOfDay = noop,
        setWeather = noop,
        event = noop,
        splash = noop,
    }

    host.camera = {
        set = function(x, y, z, lx, ly, lz, fov)
            camera.x, camera.y, camera.z = x, y, z
            camera.look = { lx, ly, lz }
            camera.fov = fov
        end,
        setFov = function(f) camera.fov = f end,
        set2d = function(x, y, size)
            camera.x, camera.y, camera.z = x, y, -10
            camera.size = size
        end,
        setBackground = function(c) camera.background = c end,
        getPos = function() return camera.x, camera.y, camera.z end,
        shake = noop,
    }

    host.ui = {
        label = function(name, text, x, y, size, color)
            labels[name] = { text = text, x = x, y = y, size = size, color = color }
            texts[name] = text
            visible[name] = true
        end,
        panel = function(name) visible[name] = true end,
        button = function(name, text, x, y, w, h, cb)
            buttons[name] = { text = text, callback = cb }
            visible[name] = true
        end,
        bar = function(name) visible[name] = true end,
        setText = function(name, text) texts[name] = text end,
        setColor = function(name, c) colors[name] = c end,
        setSize = noop,
        show = function(name, v) visible[name] = v end,
        setBar = noop,
        setButtonSelected = noop,
        setButtonColors = noop,
        setPos = function(name, x, y)
            local l = labels[name]
            if l then l.x, l.y = x, y end
        end,
        setScale = function(name, s, sy)
            local l = labels[name]
            if l then l.scale = { s, sy or s } end
        end,
        setFade = function(a) fade = a end,
        setVignette = function(v) vignette = v end,
        destroy = function(name) labels[name] = nil; buttons[name] = nil; visible[name] = nil end,
        clear = function() labels = {}; buttons = {}; texts = {}; visible = {} end,
        exists = function(name) return visible[name] ~= nil end,
    }

    host.audio = {
        play = noop, music = noop, ambient = noop,
        mute = function(v) host.muted = v end,
        volume = noop,
    }

    host.fx = { event = noop }

    host.save = {
        getInt = function(k, d) local v = save[k]; if v == nil then return d or 0 end; return v end,
        setInt = function(k, v) save[k] = v end,
        getStr = function(k, d) return save[k] or d or "" end,
        setStr = function(k, v) save[k] = v end,
    }

    host.input = {
        axisH = function() return 0 end,
        axisV = function() return 0 end,
        pause = function() return false end,
        boost = function() return false end,
        restart = function() return false end,
        confirm = function() return false end,
        back = function() return false end,
        mute = function() return false end,
        anyKey = function() return false end,
        left = function() return false end,
        right = function() return false end,
        up = function() return false end,
        down = function() return false end,
        number = function() return false end,
        shoot = function() return false end,
        mount = function() return false end,
        skill = function() return false end,
    }

    host._debug = {
        advance = function(dt) now = now + dt end,
        time = function() return now end,
        entities = function() return ents end,
        buttons = function() return buttons end,
        labels = function() return labels end,
        texts = function() return texts end,
        visible = function() return visible end,
        fade = function() return fade end,
        vignette = function() return vignette end,
        camera = function() return camera end,
        save = function() return save end,
        click = function(name)
            local b = buttons[name]
            if b and b.callback then b.callback() return true end
            return false
        end,
    }

    return host
end

return M
