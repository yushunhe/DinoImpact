-- Headless tests for the 2D dinosaur runner.
package.path = "tools/luatest/?.lua;Assets/StreamingAssets/Lua/?.lua;" .. package.path
local Mock = require("mock_host")

local host = Mock.new()
_G.Host = host
local I = require("input")
local Game = require("main")
local P = require("dino_player")

local failures = 0
local function check(cond, msg)
    if cond then io.write("  ok   " .. msg .. "\n")
    else failures = failures + 1; io.write("  FAIL " .. msg .. "\n") end
end

local function step(dt, keys)
    I.setOverride(keys or {})
    host._debug.advance(dt)
    Game.update(dt)
    I.setOverride(nil)
end

local function steps(n, dt, keys)
    for i = 1, n do step(dt, keys) end
end

local function countEntities()
    local n = 0
    for _ in pairs(host._debug.entities()) do n = n + 1 end
    return n
end

io.write("boot / menu\n")
Game.init()
check(Game.state == "menu", "boots into menu")
check(host._debug.visible().menu_bg == true, "menu visible")
check(host._debug.visible().hud_distance ~= true, "HUD hidden in menu")
check(host._debug.buttons().menu_start ~= nil, "start button exists")
check(countEntities() > 5, "scenery spawned")

io.write("start via mouse button\n")
check(host._debug.click("menu_start"), "start button has a callback")
check(Game.state == "playing", "click starts the run")
Game.debugClearTrack()
check(host._debug.visible().menu_bg ~= true, "menu hidden while playing")
check(host._debug.visible().hud_distance == true, "HUD visible while playing")
check(host._debug.texts().hud_distance ~= nil, "distance HUD text exists")

io.write("forward movement\n")
local y0 = P.y
steps(60, .05, { v = 1 })
check(P.y > y0 + 3, string.format("forward input moves up (%.2f)", P.y - y0))
check(P.distance >= P.y - .01, "distance tracks forward travel")
check(host._debug.camera().y > P.y, "camera follows ahead of the player")

io.write("stop without reversing\n")
local yBeforeStop = P.y
steps(120, .05)
check(math.abs(P.vy) < .001, "releasing forward eventually stops the dinosaur")
check(P.y >= yBeforeStop - .001, "dinosaur never slides backwards")
local yStopped = P.y
steps(60, .05, { v = -1 })
check(P.y >= yStopped - .001, "holding down never moves backwards")
check(math.abs(P.vy) < .001, "down key brakes to a stop")

io.write("lateral steering\n")
local x0 = P.x
steps(40, .05, { h = 1 })
check(P.x > x0 + .5, "right input steers right")
local xRight = P.x
steps(80, .05, { h = -1 })
check(P.x < xRight - .5, "left input steers left")

io.write("endless horizontal world\n")
Game.debugSetPlayer({ x = 0, vx = 0, vy = 0 })
steps(120, .05, { h = 1 })
check(P.x > 8, string.format("player runs past the old wall (x=%.1f)", P.x))
local camx = host._debug.camera().x
check(camx > 8 and math.abs(camx - P.x) < 3,
    string.format("camera follows player x (cam=%.1f)", camx))

io.write("scenery everywhere\n")
local W = require("dino_world")
local function decorNear(x, y, radius)
    local n, r2 = 0, radius * radius
    for _, cell in pairs(W.cells) do
        for i = 1, #cell.items do
            local it = cell.items[i]
            local dx, dy = it.x - x, it.y - y
            if dx * dx + dy * dy <= r2 then n = n + 1 end
        end
    end
    return n
end

-- Teleport far away: that spot must already be covered by scenery.
Game.debugSetPlayer({ x = -260, y = 140, vx = 0, vy = 0 })
step(.05)
local left = decorNear(-260, 140, 20)
check(left >= 8, string.format("scenery covers far left (%d items)", left))

Game.debugSetPlayer({ x = 640, y = 160, vx = 0, vy = 0 })
step(.05)
local right = decorNear(640, 160, 20)
check(right >= 8, string.format("scenery covers far right (%d items)", right))
check(math.min(left, right) * 2 >= math.max(left, right),
    string.format("scenery density is similar everywhere (%d vs %d)", left, right))

io.write("egg pickup\n")
if Game.state ~= "playing" then Game.startRun(); Game.debugClearTrack() end
Game.debugSetPlayer({ x = 0, y = 20, vx = 0, vy = 0, distance = 20 })
local eggs0 = P.eggs
Game.debugSpawnEgg(P.x, P.y + .15)
step(.05)
check(P.eggs == eggs0 + 1, "egg at the player is collected")
check(host._debug.texts().hud_eggs == "EGGS  " .. tostring(P.eggs), "egg HUD updates")

io.write("obstacle collision ends the run\n")
Game.debugSetPlayer({ x = 0, y = 30, vx = 0, vy = 0, distance = 30 })
Game.debugSpawnObstacle("rock", P.x, P.y + .1)
step(.05)
check(Game.state == "over", "rock collision ends the run")
steps(6, .05) -- the results panel appears after the hit-stop beat
check(host._debug.visible().results_bg == true, "results overlay appears")
check(host._debug.visible().hud_distance ~= true, "HUD hidden on results")
check(host._debug.texts().results_title == "GAME OVER", "results title")
local savedBest = host._debug.save().best or 0
check(savedBest >= math.floor(P.distance + .5), "best score saved (" .. savedBest .. ")")

io.write("retry\n")
steps(12, .05)
step(.05, { confirm = true })
check(Game.state == "playing", "enter retries from results")
check(P.y == 0 and P.eggs == 0, "retry resets the player")

io.write("pause / resume\n")
step(.05, { pause = true })
check(Game.state == "paused", "escape pauses")
check(host._debug.visible().pause_bg == true, "pause overlay visible")
local yPaused = P.y
steps(40, .05, { v = 1 })
check(P.y == yPaused, "player is frozen while paused")
step(.05, { pause = true })
check(Game.state == "playing", "escape resumes")
check(host._debug.visible().pause_bg ~= true, "pause overlay hidden")

io.write("restart key\n")
steps(20, .05, { v = 1 })
step(.05, { restart = true })
check(Game.state == "playing" and P.y == 0, "R restarts the run")

io.write("menu round trip\n")
Game.enterMenu()
check(Game.state == "menu", "returns to menu")
check(host._debug.visible().menu_bg == true, "menu visible again")
check(host._debug.texts().menu_best ~= nil and host._debug.texts().menu_best ~= "BEST  0", "menu shows saved best")

io.write("long forward simulation\n")
Game.startRun()
Game.debugClearTrack()
math.randomseed(12345)
local maxEnts = 0
for i = 1, 2400 do
    local keys = { v = 1, h = math.sin(i * .035) * .7 }
    step(.05, keys)
    local n = countEntities()
    if n > maxEnts then maxEnts = n end
    if Game.state ~= "playing" then break end
end
check(maxEnts < 220, "entity count stays bounded (" .. maxEnts .. ")")
check(P.distance > 80, "long run covers distance (" .. math.floor(P.distance) .. " m)")

io.write("\n" .. (failures == 0 and "ALL DINO TESTS PASSED" or (failures .. " TEST(S) FAILED")) .. "\n")
os.exit(failures == 0 and 0 or 1)
