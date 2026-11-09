-- Focused gameplay tests: pickups, hits, gates, ramps, kraken.
package.path = "tools/luatest/?.lua;Assets/StreamingAssets/Lua/?.lua;" .. package.path
local Mock = require("mock_host")

local host = Mock.new()
_G.Host = host
local I = require("input")
local Game = require("main")
local E = require("entities")
local O = require("obstacles")
local P = require("player")
local M = require("modes")
local W = require("world")

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

Game.init()

io.write("pickup collection\n")
Game.debugStart("collector")
P.invuln = 0
local tokens0 = P.tokens
E.new("coin", P.x, P.z, { float = 0, tilt = false, r = 1.35, pickup = true, tag = "pickup" })
step(.05)
check(P.tokens == tokens0 + 1, "coin at the surfer is collected")
check(P.coinScore > 0, "coin awards score")

io.write("obstacle hit\n")
Game.debugStart("classic")
P.invuln = 0
local lives0 = P.lives
E.new("rock", P.x, P.z, { float = -.25, tilt = false, r = 2.5, solid = true, tag = "obstacle" })
step(.05)
check(P.lives == lives0 - 1, "rock costs a life")
check(P.invuln > 0, "hit grants invulnerability")
step(.05)
check(P.lives == lives0 - 1, "invulnerability prevents double hits")

io.write("time trial hit is free but costs clock\n")
Game.debugStart("timeTrial")
P.invuln = 0
local tl = M.timeLeft
local tlives = P.lives
E.new("rock", P.x, P.z, { float = -.25, tilt = false, r = 2.5, solid = true, tag = "obstacle" })
step(.05)
check(P.lives == tlives, "time trial obstacle does not cost a life")
check(M.timeLeft < tl - 2.5, "time trial obstacle costs roughly 3s")

io.write("zigzag gate pass\n")
Game.debugStart("zigzag")
P.invuln = 10
local ang = P.heading
for i = 1, 20 do
    -- walk forward along the heading at 7 m/s for the test
    P.z = P.z + math.cos(ang) * .35
    P.x = P.x + math.sin(ang) * .35
    step(.05, { h = 0 })
    if M.streak > 0 then break end
end
-- spawn a gate directly in front and drive through it
if M.streak == 0 then
    local g = E.new("gate", P.x, P.z + 5, { float = 0, tilt = false, rotY = math.deg(ang), tag = "gate" })
    g.yaw = ang
    g.used, g.missed = false, false
    for i = 1, 20 do
        step(.05, { h = 0, v = 1 })
        if M.streak > 0 then break end
    end
end
check(M.streak >= 1, "passing a gate builds a streak")
check(P.gateScore > 0, "gate pass awards points")

io.write("time trial checkpoint\n")
Game.debugStart("timeTrial")
P.invuln = 10
M.timeLeft = 30
local gates0 = M.gates
local cp = E.new("checkpoint", P.x, P.z + 5, { float = 0, tilt = false, rotY = math.deg(P.heading), tag = "checkpoint" })
cp.yaw = P.heading
cp.used, cp.missed = false, false
for i = 1, 20 do
    step(.05, { h = 0 })
    if M.gates > gates0 then break end
end
check(M.gates == gates0 + 1, "checkpoint increments the counter")
check(M.timeLeft > 30, "checkpoint adds time")

io.write("kraken chase and bite\n")
Game.debugStart("classic")
M.krakenTimer = .01
step(.05)
step(.05)
check(M.kraken ~= nil, "kraken spawns in classic")
if M.kraken then
    P.invuln = 0
    local lives1 = P.lives
    M.kraken.x = P.x
    M.kraken.z = P.z - 1
    step(.05)
    check(P.lives == lives1 - 1, "kraken collision costs a life")
    local kdx, kdz = M.kraken.x - P.x, M.kraken.z - P.z
    check(math.sqrt(kdx * kdx + kdz * kdz) > 10, "kraken is pushed back after a bite")
end

io.write("ramp launch\n")
Game.debugStart("collector")
P.invuln = 10
local ramp = E.new("ramp", P.x, P.z + 2, { float = -.2, tilt = false, rotY = math.deg(P.heading), tag = "ramp" })
ramp.used = false
step(.05, { v = 1 })
check(not P.grounded or P.vy > 0, "ramp launches the surfer")
local peak = 0
for i = 1, 80 do
    step(.05, { h = 0 })
    if P.y > peak then peak = P.y end
    if P.grounded and i > 5 then break end
end
check(peak > W.height(P.x, P.z) + .5, "surfer gets airborne")
check(P.grounded, "surfer lands again")

io.write("gate miss resets streak\n")
Game.debugStart("zigzag")
M.streak = 4
M.handleEvent({ kind = "gateMissed" })
check(M.streak == 0, "missed gate clears streak")

io.write("results and best streak\n")
Game.debugStart("zigzag")
M.bestStreak = 7
Game.debugSetPlayer({ distance = 500, coinScore = 100, gateScore = 300 })
local oldBest = host._debug.save().best_zigzag or 0
M.finish("timeout")
Game.finishRun()
check(Game.state == "results", "zigzag run ends")
check(host._debug.save().best_zigzag >= math.max(oldBest, P.totalScore()), "zigzag best score saved")
check(host._debug.save().bestStreak_zigzag == 7, "best streak saved")

io.write("menu reflects bests\n")
Game.enterMenu()
check(host._debug.texts().menu_best_zigzag ~= nil and host._debug.texts().menu_best_zigzag ~= "BEST  -", "menu shows saved best")

io.write("\n" .. (failures == 0 and "ALL GAMEPLAY TESTS PASSED" or (failures .. " TEST(S) FAILED")) .. "\n")
os.exit(failures == 0 and 0 or 1)
