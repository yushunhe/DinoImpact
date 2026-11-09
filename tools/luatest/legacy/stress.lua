-- Long-running randomized simulation across all modes.
package.path = "tools/luatest/?.lua;Assets/StreamingAssets/Lua/?.lua;" .. package.path
local Mock = require("mock_host")

local host = Mock.new()
_G.Host = host
local I = require("input")
local Game = require("main")
local M = Game.debugGetModes()

local function step(dt, keys)
    I.setOverride(keys or {})
    host._debug.advance(dt)
    Game.update(dt)
    I.setOverride(nil)
end

local function countEntities()
    local n = 0
    for _ in pairs(host._debug.entities()) do n = n + 1 end
    return n
end

Game.init()

local modes = { "classic", "timeTrial", "zigzag", "collector" }
local maxEntities = 0
local runs = 0
local resultsSeen = 0
local krakenSeen = false
local errorCount = 0

math.randomseed(20261104)

for round = 1, 3 do
    for _, mode in ipairs(modes) do
        Game.debugStart(mode)
        runs = runs + 1
        local t = 0
        local frames = 0
        local steer = 0
        while frames < 3600 do -- 3 minutes at dt 0.05
            frames = frames + 1
            t = t + .05
            -- wander, occasionally dash or boost
            if frames % 45 == 0 then steer = (math.random() * 2 - 1) * .9 end
            local keys = { h = steer, v = (frames % 200 < 40) and 1 or 0, boost = (frames % 300 == 0) }
            if frames % 997 == 0 then keys.pause = true end
            if frames % 998 == 0 then keys.pause = true end
            local ok, err = pcall(step, .05, keys)
            if not ok then
                errorCount = errorCount + 1
                io.write("ERROR " .. mode .. " frame " .. frames .. ": " .. tostring(err) .. "\n")
                break
            end
            local n = countEntities()
            if n > maxEntities then maxEntities = n end
            if n > 280 then
                errorCount = errorCount + 1
                io.write("ENTITY LEAK " .. mode .. " n=" .. n .. "\n")
                break
            end
            if M.kraken ~= nil then krakenSeen = true end
            if Game.state == "results" then
                resultsSeen = resultsSeen + 1
                -- click retry through the transition
                for i = 1, 12 do step(.05) end
                if Game.state == "results" then
                    step(.05, { confirm = true })
                end
                for i = 1, 10 do step(.05) end
                if Game.state ~= "playing" then
                    Game.debugStart(mode)
                end
                break
            end
            if Game.state == "paused" then
                step(.05, { pause = true })
            end
        end
        io.write(string.format("%-10s frames=%-5d state=%-9s dist=%-7.1f coins=%-3d score=%-6d ents=%d\n",
            mode, frames, Game.state, Game.debugGetPlayer().distance,
            Game.debugGetPlayer().tokens, Game.debugGetPlayer().totalScore(), countEntities()))
    end
end

io.write(string.format("runs=%d results=%d maxEntities=%d kraken=%s errors=%d\n",
    runs, resultsSeen, maxEntities, tostring(krakenSeen), errorCount))
local ok = errorCount == 0 and maxEntities <= 280 and krakenSeen
os.exit(ok and 0 or 1)
