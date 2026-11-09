-- Headless smoke test: boots the real Lua game against a mock Host.
package.path = "tools/luatest/?.lua;Assets/StreamingAssets/Lua/?.lua;" .. package.path
local Mock = require("mock_host")

local failures = 0
local function check(cond, msg)
    if cond then
        io.write("  ok   " .. msg .. "\n")
    else
        failures = failures + 1
        io.write("  FAIL " .. msg .. "\n")
    end
end

local function main()
    local host = Mock.new()
    _G.Host = host
    local I = require("input")
    local Game = require("main")
    local M = Game.debugGetModes()
    local P = Game.debugGetPlayer()

    local function step(dt, keys)
        I.setOverride(keys or {})
        host._debug.advance(dt)
        Game.update(dt)
        I.setOverride(nil)
    end

    local function steps(count, dt, keysFn)
        for i = 1, count do
            local keys = keysFn and keysFn(i) or nil
            step(dt, keys)
        end
    end

    io.write("boot\n")
    local ok, err = pcall(Game.init)
    check(ok, "Game.init runs without error" .. (ok and "" or (": " .. tostring(err))))
    if not ok then return end
    check(Game.state == "menu", "boots into menu")
    check(host._debug.visible().menu_bg == true, "menu background visible")
    check(host._debug.visible().hud_score ~= true, "HUD hidden in menu")
    check(next(host._debug.buttons()) ~= nil, "menu buttons built")
    check(host._debug.buttons().menu_classic ~= nil, "classic button exists")

    io.write("menu navigation\n")
    local before = Game.menuIndex
    step(.05, { down = true })
    check(Game.menuIndex == before % 4 + 1, "arrow keys move menu selection")
    step(.05, { up = true })
    check(Game.menuIndex == before, "selection wraps back")
    step(.05, { confirm = true })
    check(Game.state == "transition", "confirm starts a transition")
    steps(8, .05)
    check(Game.state == "countdown", "transition reaches countdown")
    check(host._debug.visible().hud_score == true, "HUD visible at run start")
    check(host._debug.visible().menu_bg ~= true, "menu hidden at run start")

    io.write("countdown\n")
    steps(65, .05)
    check(Game.state == "playing", "countdown hands over to playing")
    steps(20, .05)
    check(host._debug.visible().countdown ~= true, "GO overlay hidden after countdown")

    io.write("surf for 20 seconds\n")
    steps(400, .05, function(i)
        return { h = math.sin(i * .035) * .55, v = .4 }
    end)
    check(Game.state == "playing", "still playing after 20s")
    check(P.distance > 100, "surfer travelled distance (" .. string.format("%.1f", P.distance) .. " m)")
    check(P.totalScore() > 0, "score accumulates")
    check(host._debug.visible().hud_score == true, "HUD still visible")
    local count = 0
    for _ in pairs(host._debug.entities()) do count = count + 1 end
    check(count > 10, "world populated with entities (" .. count .. ")")
    check(count <= 275, "entity count within cap (" .. count .. ")")
    check(host._debug.visible().hud_lives == true, "lives HUD visible")

    io.write("pause / resume\n")
    step(.05, { pause = true })
    check(Game.state == "paused", "space pauses")
    check(host._debug.visible().pause_resume == true, "pause overlay visible")
    step(.5)
    check(Game.state == "paused", "pause freezes the game")
    step(.05, { pause = true })
    check(Game.state == "playing", "space resumes")
    check(host._debug.visible().pause_bg ~= true, "pause overlay hidden")

    io.write("mute\n")
    local muted = Game.muted
    step(.05, { mute = true })
    check(Game.muted ~= muted, "M toggles mute")
    check(host._debug.save().muted ~= nil, "mute preference persisted")

    io.write("each mode can run\n")
    for _, mode in ipairs({ "classic", "timeTrial", "zigzag", "collector" }) do
        Game.debugStart(mode)
        steps(200, .05, function(i) return { h = math.sin(i * .05) * .7, v = .2 } end)
        check(Game.state == "playing", mode .. " runs")
    end

    io.write("mode rules\n")
    Game.debugStart("zigzag")
    local scoreBefore = P.totalScore()
    M.handleEvent({ kind = "gatePassed", lateral = 2 })
    check(M.streak == 1, "zigzag gate increments streak")
    check(P.totalScore() > scoreBefore, "zigzag gate awards points")
    M.handleEvent({ kind = "gateMissed" })
    check(M.streak == 0, "missed gate resets streak")

    Game.debugStart("timeTrial")
    local t0 = M.timeLeft
    M.handleEvent({ kind = "checkpoint" })
    check(M.gates == 1, "time trial checkpoint counted")
    check(M.timeLeft > t0, "time trial checkpoint adds time")
    local t1 = M.timeLeft
    M.handleEvent({ kind = "obstacleHit" })
    check(M.timeLeft < t1, "time trial obstacle costs time")

    io.write("time trial timeout -> results\n")
    M.timeLeft = .02
    step(.1)
    check(Game.state == "results", "timer expiry ends the run")
    check(host._debug.texts().results_title == "TIME'S UP", "timeout result title")
    check(host._debug.visible().results_bg == true, "results overlay visible")
    check(host._debug.visible().hud_score ~= true, "HUD hidden on results")

    io.write("results keyboard retry\n")
    steps(12, .05)
    step(.05, { confirm = true })
    check(Game.state == "transition", "enter retries from results")
    steps(8, .05)
    check(Game.state == "countdown", "retry returns to countdown")
    check(Game.modeKey == "timeTrial", "retry keeps the mode")

    io.write("back to menu\n")
    Game.enterMenu()
    check(Game.state == "menu", "enterMenu returns to menu")
    check(host._debug.visible().menu_bg == true, "menu visible again")
    check(host._debug.visible().hud_score ~= true, "HUD hidden again")
    step(.05)
    check(host._debug.visible().menu_bg == true, "menu survives an update")

    io.write("menu mouse button starts a run\n")
    local clicked = host._debug.click("menu_zigzag")
    check(clicked, "menu button has a callback")
    check(Game.state == "transition", "click starts a transition")
    steps(8, .05)
    check(Game.state == "countdown", "mouse start reaches countdown")
    check(Game.modeKey == "zigzag", "mouse start selects zigzag")

    io.write("best score persistence\n")
    Game.debugStart("collector")
    Game.debugSetPlayer({ distance = 900, coinScore = 2500, trickScore = 0, gateScore = 0, boostScore = 0 })
    M.finish("timeout")
    Game.finishRun()
    check(Game.state == "results", "debug finish shows results")
    local best = host._debug.save().best_collector
    check(best ~= nil and best >= 2900, "new best saved (" .. tostring(best) .. ")")
    check(host._debug.texts().results_best == "NEW BEST!", "new best is called out")

    io.write("cleanup\n")
    Game.enterMenu()
    check(Game.state == "menu", "returns to menu after results")
    check(M.kraken == nil, "kraken cleaned up")

    io.write("\n" .. (failures == 0 and "ALL TESTS PASSED" or (failures .. " TEST(S) FAILED")) .. "\n")
    if failures > 0 then os.exit(1) end
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    io.write("FATAL: " .. tostring(err) .. "\n")
    os.exit(1)
end
